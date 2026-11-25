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


# Expected outcomes: the rows of witnesses/README.md, with qualified_constant's refusal as measured
# (MOD-5 at the constant's own line, the v0.146 prediction kept in the README as history). FN-9 is
# UndischargedPostcondition.
EXPECTED = {
    'length_transport': dict(exit=1, code='FN-9', line_has='return'),
    'box_exchange': dict(exit=0, code=None),
    'owner_branch': dict(exit=0, code=None),
    'dispatch_exchange': dict(exit=0, code=None),
    'qualified_constant': dict(exit=1, code='MOD-5', line_has='qualified_source::marker'),
}
FORBIDDEN_CALLS = ('alloc', 'release', 'memcpy')
DIAGNOSTIC = re.compile(r'probe\.wf:(\d+):\d+: error\[([A-Z]+-\d+)\]')


def compare_entry(entry, record, directory):
    expected = EXPECTED[entry]
    problems = []
    compile_exit = record.get('compile', {}).get('exit')
    if compile_exit != expected['exit']:
        problems.append(f'compile exit {compile_exit}, expected {expected["exit"]}')
    text = ''
    for name in ('compile.stdout', 'compile.stderr'):
        if (directory / name).exists():
            text += (directory / name).read_text(errors='replace')
    found = DIAGNOSTIC.search(text)
    code = found[2] if found else None
    if code != expected['code']:
        problems.append(f'diagnostic code {code}, expected {expected["code"]}')
    if expected.get('line_has'):
        line = int(found[1]) if found else 0
        source = (Path(__file__).parent / entry / 'probe.wf').read_text().splitlines()
        text_line = source[line - 1] if 0 < line <= len(source) else ''
        if expected['line_has'] not in text_line:
            problems.append(f'refusal at line {line}, which is not a line with {expected["line_has"]}')
    if expected['exit'] == 0:
        for stage in ('ordinary-run', 'emit', 'retained-object', 'disassemble'):
            exit_code = record.get(stage, {}).get('exit')
            if exit_code != 0:
                problems.append(f'{stage} exit {exit_code}')
        if record.get('symbol-check', {}).get('exit') != 0:
            problems.append('symbol-check failed')
        disassembly = directory / 'disassemble.stdout'
        assembly = disassembly.read_text(errors='replace') if disassembly.exists() else ''
        problems += assembly_problems(record.get('symbols', {}), assembly)
    return problems


def assembly_problems(symbols, assembly):
    """The problems of a set of studied functions: none listed, a function with no body, or a forbidden call."""
    problems = []
    if not symbols:
        problems.append('no studied function is listed')
    for name, symbol in symbols.items():
        block = function_block(assembly, symbol)
        if not block:
            problems.append(f'{name} ({symbol}): no function body in the disassembly')
            continue
        for line in block:
            match = CALL.search(line)
            if match and any(word in match[1] for word in FORBIDDEN_CALLS):
                problems.append(f'{name} calls {match[1]}')
    return problems


def compare(out, header):
    for line in header:
        print(line)
    results = out / 'results.json'
    if not results.exists():
        print('inspect wrote no results.json: the inspection did not run; see its output above')
        return 1
    records = json.loads(results.read_text())
    failed = False
    for entry in EXPECTED:
        if entry not in records:
            print(f'{entry}: no record')
            failed = True
            continue
        problems = compare_entry(entry, records[entry], out / entry)
        if problems:
            failed = True
            print(f'{entry}: DIFFERS: ' + '; '.join(problems))
        else:
            print(f'{entry}: as expected')
    for line in header:
        print(line)
    return int(failed)


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ('report', 'compare'):
        raise SystemExit('usage: check.py report|compare <inspect output directory> <objdump>')
    out = Path(sys.argv[2])
    used = sys.argv[3]
    header = objdump_lines(used)
    if sys.argv[1] == 'compare':
        return compare(out, header)
    print('coroutine witnesses, report mode: nothing is compared, this run fails on purpose')
    for line in header:
        print(line)
    results = out / 'results.json'
    if not results.exists():
        print('inspect wrote no results.json: the inspection did not run; see its output above')
        for line in header:
            print(line)
        return 1
    records = json.loads(results.read_text())
    for entry, record in records.items():
        for line in entry_report(entry, record, out / entry):
            print(line)
    # The same lookup again as the last lines, so that a cut at either end keeps it.
    for line in header:
        print(line)
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
