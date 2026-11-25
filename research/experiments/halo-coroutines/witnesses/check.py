#!/usr/bin/env python3
"""TEMPORARY one-off reproduction helper for item 274; removed before the work merges.

`report` prints, for each witness entry that inspect.py ran, its stage exit codes,
the compiler's diagnostic for a refused entry, and the calls made by each studied
function. It always exits non-zero, so the reproduction target shows the text as
a failure; nothing is compared here.
"""
import json
import re
import shutil
import sys
from pathlib import Path

LINES_PER_ENTRY = 12
DIAGNOSTIC_LINES = 8
CALL = re.compile(r'\bcall[qlw]?\s.*<([^>]+)>')
CANDIDATES = ('/usr/bin/llvm-objdump-22', '/usr/lib/llvm-22/bin/llvm-objdump')


def function_block(assembly, symbol):
    """The instruction lines of the disassembled function `symbol`, or None."""
    lines = assembly.splitlines()
    start = next((i for i, line in enumerate(lines) if line.endswith(f'<{symbol}>:')), None)
    if start is None:
        return None
    block = []
    for line in lines[start + 1:]:
        if not line.strip():
            break
        block.append(line)
    return block


def entry_report(entry, record, directory):
    lines = [f'== {entry}']
    for stage, value in record.items():
        if isinstance(value, dict) and 'exit' in value:
            lines.append(f'  {stage}: exit={value["exit"]}')
    if record.get('retain', {}).get('exit') == 1:
        lines.append(f'  retain: {record["retain"].get("diagnostic")}')
    compile_exit = record.get('compile', {}).get('exit')
    if compile_exit not in (None, 0):
        text = ''
        for name in ('compile.stdout', 'compile.stderr'):
            path = directory / name
            if path.exists():
                text += path.read_text(errors='replace')
        lines.append('  diagnostic:')
        lines += ['    ' + line for line in text.splitlines()[:DIAGNOSTIC_LINES]]
    if record.get('symbol-check'):
        lines.append(f'  symbol-check: {record["symbol-check"]}')
    symbols = record.get('symbols', {})
    if symbols:
        disassembly = directory / 'disassemble.stdout'
        assembly = disassembly.read_text(errors='replace') if disassembly.exists() else ''
        for name, symbol in symbols.items():
            block = function_block(assembly, symbol)
            if block is None:
                lines.append(f'  {name} ({symbol}): not in the disassembly')
                continue
            targets = {}
            for line in block:
                match = CALL.search(line)
                if match:
                    targets[match[1]] = targets.get(match[1], 0) + 1
            calls = ', '.join(f'{target} x{count}' for target, count in sorted(targets.items()))
            lines.append(f'  {name} ({symbol}): {len(block)} instructions; calls: {calls or "none"}')
    if len(lines) > LINES_PER_ENTRY:
        lines = lines[:LINES_PER_ENTRY] + ['  ... cut']
    return lines


def objdump_lines(used):
    """The objdump lookup: which candidate exists, and which one the assembly checks used."""
    shown = ', '.join(f'{path} {"exists" if Path(path).exists() else "absent"}' for path in CANDIDATES)
    on_path = shutil.which('llvm-objdump-22') or 'none'
    if Path(used).exists():
        verdict = f'objdump used: {used}'
    else:
        verdict = 'objdump used: NONE; assembly checks did not run'
    return [f'objdump lookup: {shown}; llvm-objdump-22 on PATH: {on_path}', verdict]


def main():
    if len(sys.argv) != 4 or sys.argv[1] != 'report':
        raise SystemExit('usage: check.py report <inspect output directory> <objdump>')
    out = Path(sys.argv[2])
    used = sys.argv[3]
    records = json.loads((out / 'results.json').read_text())
    header = objdump_lines(used)
    print('coroutine witnesses, report mode: nothing is compared, this run fails on purpose')
    for line in header:
        print(line)
    for entry, record in records.items():
        for line in entry_report(entry, record, out / entry):
            print(line)
    # The same lookup again as the last lines, so that a cut at either end keeps it.
    for line in header:
        print(line)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
