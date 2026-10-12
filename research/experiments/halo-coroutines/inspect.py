#!/usr/bin/env python3
"""CI-only source acceptance and retained-function inspection for mechanism A."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROBES = {
    'length_transport': (),
    'box_exchange': ('box_exchange',),
    'owner_branch': ('read_open', 'write_open'),
    'dispatch_exchange': ('dispatch_exchange',),
    'qualified_constant': (),
}


def retain(module, names):
    """Keep only the studied ABI boundaries; preserve all instruction bodies."""
    found = {}
    lines = module.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if not line.startswith('define '):
            continue
        match = re.search(r'@([^ (]+)\(', line)
        if not match:
            continue
        symbol = match[1]
        for name in names:
            # Graph emission qualifies functions by module. Require the exact
            # final component, not a dispatch arm or an instantiated helper.
            if symbol != f'wf_{name}' and not symbol.endswith(f'.{name}'):
                continue
            if name in found or not line.rstrip().endswith(' {'):
                raise ValueError(f'ambiguous or unsupported definition: {name}')
            if re.search(r'\b(alwaysinline|noinline)\b', line):
                raise ValueError(f'unexpected existing inline attribute: {name}')
            # noinline alone permits specialization of internal functions.
            header = re.sub(r'^define (?:internal |private )?', 'define ', line.rstrip()[:-2])
            lines[index] = header + ' noinline {\n'
            found[name] = symbol
    if set(found) != set(names):
        raise ValueError(f'missing studied functions: {sorted(set(names) - set(found))}')
    return ''.join(lines), found


def check_retention():
    # CI controls: missing/ambiguous symbols must not yield a green inspection.
    source = 'define internal i64 @wf_pkg.probe.read_open(ptr %p) #0 {\n  ret i64 0\n}\n'
    retained, symbols = retain(source, ('read_open',))
    assert retained == source.replace('define internal ', 'define ').replace(' #0 {', ' #0 noinline {')
    assert symbols == {'read_open': 'wf_pkg.probe.read_open'}
    for bad in ('', source.replace('read_open', 'unrelated'), source + source):
        try:
            retain(bad, ('read_open',))
        except ValueError:
            pass
        else:
            raise AssertionError('missing/ambiguous function admitted')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--objdump', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    compiler, objdump, out = args.compiler.resolve(), args.objdump.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    records = {}

    def save():
        (out / 'results.json').write_text(json.dumps(records, indent=2) + '\n')

    def run(record, stage, command, directory):
        start = time.monotonic()
        try:
            result = subprocess.run([str(x) for x in command], capture_output=True, timeout=180)
            code, stdout, stderr = result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired as error:
            code, stdout, stderr = 124, error.stdout or b'', error.stderr or b''
            stderr += b'\ninspection command timed out after 180 seconds\n'
        except OSError as error:
            code, stdout, stderr = 127, b'', str(error).encode()
        (directory / f'{stage}.stdout').write_bytes(stdout)
        (directory / f'{stage}.stderr').write_bytes(stderr)
        record[stage] = dict(command=[str(x) for x in command], exit=code,
                             seconds=time.monotonic() - start)
        print(f'{directory.name}/{stage}: exit={code}', flush=True)
        # Print compiler/refusal diagnostics, including stdout diagnostics.
        # Disassembly is large and stays in its artifact.
        if stage != 'disassemble':
            print((stdout + stderr).decode('utf8', 'replace'), end='', flush=True)
        elif stderr:
            print(stderr.decode('utf8', 'replace'), end='', flush=True)
        save()
        return code == 0

    check_retention()
    failed = False
    for entry, names in PROBES.items():
        directory = out / entry
        directory.mkdir(exist_ok=True)
        record = records[entry] = {}
        base = [compiler, '--graph', HERE / 'witnesses/modules.wfg', '--entry', entry]
        # All entries take the ordinary compiler-to-binary path first. A proof
        # refusal remains a failure; it never prevents the other probes running.
        accepted = run(record, 'compile', base + ['--full-lto', '-o', directory / 'ordinary'], directory)
        failed |= not accepted
        if not accepted:
            continue
        failed |= not run(record, 'ordinary-run', [directory / 'ordinary'], directory)
        if not names:
            continue
        if not run(record, 'emit', base + ['--emit-llvm', '-o', directory / 'raw.ll'], directory):
            failed = True
            continue
        try:
            retained, symbols = retain((directory / 'raw.ll').read_text(), names)
            (directory / 'retained.ll').write_text(retained)
            record['symbols'] = symbols
            record['retain'] = dict(exit=0)
        except (ValueError, OSError) as error:
            record['retain'] = dict(exit=1, diagnostic=str(error))
            print(f'{entry}/retain: {error}', flush=True)
            save()
            failed = True
            continue
        # Emitted IR needs the Whitefoot runtime to link. Inspect an object;
        # the ordinary binary above runs the semantic checks with that runtime.
        if not run(record, 'retained-object', ['/usr/bin/clang', '-O2', '-c', '-Wno-override-module',
                   '-x', 'ir', directory / 'retained.ll',
                   '-o', directory / 'retained.o'], directory):
            failed = True
            continue
        # Include split dispatch arms and ABI body helpers in the artifact.
        disassembled = run(record, 'disassemble', [objdump, '-d', directory / 'retained.o'], directory)
        failed |= not disassembled
        if disassembled:
            assembly = (directory / 'disassemble.stdout').read_text()
            missing = [symbol for symbol in symbols.values() if f'<{symbol}>:' not in assembly]
            record['symbol-check'] = dict(exit=int(bool(missing)), missing=missing)
            if missing:
                print(f'{entry}: missing disassembled symbols: {missing}', flush=True)
                failed = True
        save()
    save()
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
