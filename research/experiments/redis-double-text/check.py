#!/usr/bin/env python3
"""Compare the test host's double texts with the ones redis-server 7.2.16 wrote; builds nothing."""
import argparse
import math
from pathlib import Path
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
TABLE = HERE / 'redis-7.2.16.tsv'
HEADER = ['bits', 'family', 'double_reply', 'call_argument']
COLUMNS = ('double_reply', 'call_argument')
# 1e23: Redis writes 99999999999999990000000, the exact shortest digits are 1e+23.
GRISU_WITNESS = '44b52d02c7e14af6'
# Read from Redis 7.2.16's d2string and fpconv_dtoa (source-excerpts of the
# measuring run), not measured: the table holds no NaN or infinity.
SOURCE_PROBES = [
    ('7ff8000000000000', 'nan', 'nan'),
    ('fff8000000000000', 'nan', '-nan'),
    ('7ff0000000000000', 'inf', 'inf'),
    ('fff0000000000000', '-inf', '-inf'),
]


def load(path):
    rows = []
    with open(path, encoding='ascii', newline='') as table:
        if table.readline().rstrip('\n').split('\t') != HEADER:
            raise ValueError(f'{path}: header is not {HEADER}')
        for number, line in enumerate(table, 2):
            fields = line.rstrip('\n').split('\t')
            if len(fields) != 4 or len(fields[0]) != 16 or fields[0] != fields[0].lower():
                raise ValueError(f'{path}:{number}: malformed row {line!r}')
            int(fields[0], 16)
            rows.append(dict(zip(HEADER, fields)))
    if len({row['bits'] for row in rows}) != len(rows):
        raise ValueError(f'{path}: repeated bit pattern')
    return rows


def compare(rows, actual):
    """Every (row, column, expected, actual) whose bytes differ."""
    return [(row, column, row[column], got[index])
            for row, got in zip(rows, actual)
            for index, column in enumerate(COLUMNS)
            if row[column] != got[index]]


def digits(text):
    """Significant digits of a decimal text, without sign, point, exponent or outer zeros."""
    mantissa = text.lstrip('-').split('e')[0].replace('.', '')
    return mantissa.strip('0')


def number(bits):
    return struct.unpack('<d', struct.pack('<Q', int(bits, 16)))[0]


def shortest_differs(rows):
    """Rows whose double reply has other digits than the exact shortest that read back."""
    found = []
    for row in rows:
        value = number(row['bits'])
        if value == 0 or not math.isfinite(value):
            continue
        if value == math.trunc(value) and abs(value) <= 2.0 ** 62:
            continue
        if digits(row['double_reply']) != digits(repr(abs(value))):
            found.append(row)
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', type=Path, required=True, help='the built halo-e2e test program')
    parser.add_argument('--table', type=Path, default=TABLE)
    parser.add_argument('--show', type=int, default=10, help='mismatches to print')
    args = parser.parse_args()
    rows = load(args.table)
    probes = [{'bits': bits, 'family': 'source', 'double_reply': reply, 'call_argument': argument}
              for bits, reply, argument in SOURCE_PROBES]

    # The table rejects an exact-shortest formatter, and the comparison sees
    # a one-row change: otherwise a pass below would not show Grisu2's digits.
    differs = shortest_differs(rows)
    if not any(row['bits'] == GRISU_WITNESS for row in differs):
        raise SystemExit(f'control: the row of {GRISU_WITNESS} (1e23) is missing or has the shortest digits')
    injected = [(row['double_reply'], row['call_argument']) for row in rows]
    witness = next(index for index, row in enumerate(rows) if row['bits'] == GRISU_WITNESS)
    injected[witness] = ('1e+23', injected[witness][1])
    if len(compare(rows, injected)) != 1:
        raise SystemExit('control: the comparison missed an injected exact-shortest text')
    print(f'control: an exact-shortest formatter differs on {len(differs)} of {len(rows)} rows, '
          f'including 1e23; the comparison detects one changed text', flush=True)

    checked = rows + probes
    source = b''.join(struct.pack('<Q', int(row['bits'], 16)) for row in checked)
    try:
        result = subprocess.run([str(args.binary), '--double-text'], input=source, capture_output=True, timeout=600)
    except subprocess.TimeoutExpired:
        print('double text: the test program timed out')
        return 2
    if result.returncode:
        print(f'double text: the test program exited {result.returncode}')
        print(result.stderr.decode('utf8', 'replace'))
        return 2
    lines = result.stdout.split(b'\n')
    if lines[-1] != b'' or len(lines) - 1 != len(checked):
        print(f'double text: {len(lines) - 1} lines for {len(checked)} bit patterns')
        return 2
    actual = []
    for line in lines[:-1]:
        fields = line.decode('ascii', 'replace').split('\t')
        if len(fields) != 2:
            print(f'double text: malformed line {line!r}')
            return 2
        actual.append(fields)
    mismatches = compare(checked, actual)
    for row, column, expected, got in mismatches[:args.show]:
        print(f'MISMATCH {row["bits"]} {row["family"]} {column}: expected {expected!r}, got {got!r}')
    print(f'double text: {len(rows)} measured rows and {len(probes)} source-derived probes, '
          f'{len(checked) * 2 - len(mismatches)}/{len(checked) * 2} texts byte-identical', flush=True)
    return 1 if mismatches else 0


if __name__ == '__main__':
    sys.exit(main())
