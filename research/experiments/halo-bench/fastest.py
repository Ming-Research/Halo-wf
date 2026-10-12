#!/usr/bin/env python3
"""Time Halo and N other Lua interpreters on the same workloads, round-robin.

The fastest-interpreter baseline (README.md). A sibling of run.py rather
than an extension: run.py pairs Halo with one other binary of the same
semantics and fails on any disagreement, while this runner rotates any
number of interpreters and marks one n/a on a workload whose result differs
from PUC Lua 5.1.5's, so that a semantic difference excludes that cell
instead of the run. It reuses run.py's Halo output and stats check.
"""
import argparse
import hashlib
import json
import math
import os
import platform
import re
import shlex
import shutil
import statistics
import subprocess
import time
from pathlib import Path

import run

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NUMBER = re.compile(rb'-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\n')
HALO = 'halo'


def canonical(stdout):
    """The checksum as Lua 5.1 prints it (%.14g), or None if stdout is not
    exactly one number line. Lua 5.4 prints integers in full and integral
    floats with ".0", Luau the shortest round-trip form; equal values print
    alike after this."""
    if NUMBER.fullmatch(stdout) is None:
        return None
    value = float(stdout)
    if not math.isfinite(value):
        return None
    return ('%.14g' % value).encode() + b'\n'


def check(engine, reference, launch):
    """None when the launch agrees with the reference, else the reason."""
    if launch['timeout']:
        return 'timed out'
    if launch['exit']:
        return f'exit {launch["exit"]}: {launch["stderr"][-300:]!r}'
    stdout = launch['stdout'].encode()
    if engine == HALO:
        try:
            run.validate(reference, stdout, launch['stderr'].encode(), False)
        except ValueError as error:
            return str(error)
        return None
    if canonical(stdout) != reference:
        return f'checksum {launch["stdout"]!r}, PUC 5.1.5 {reference.decode()!r}'
    return None


def self_check():
    assert canonical(b'832040\n') == b'832040\n'
    assert canonical(b'5000000050000000\n') == b'5.00000005e+15\n'
    assert canonical(b'1.0\n') == b'1\n'
    assert canonical(b'1073741823012345\n') == b'1.0737418230123e+15\n'
    for bad in (b'', b'1', b'1\n1\n', b'x\n', b'1 \n', b'inf\n', b'nan\n'):
        assert canonical(bad) is None, bad
    ok = dict(timeout=False, exit=0, stdout='1.0\n', stderr='')
    assert check('puc-5.4.9', b'1\n', ok) is None
    assert check('puc-5.4.9', b'2\n', ok) is not None
    assert check('puc-5.4.9', b'1\n', dict(ok, exit=1)) is not None
    assert check('puc-5.4.9', b'1\n', dict(ok, timeout=True)) is not None
    halo = dict(timeout=False, exit=0, stdout='1\n', stderr='0\n3\n')
    assert check(HALO, b'1\n', halo) is None
    assert check(HALO, b'1\n', dict(halo, stdout='1.0\n')) is not None
    assert check(HALO, b'1\n', dict(halo, stderr='2\n3\n')) is not None


def cpu_state(cpus):
    """Governor and current frequency of each CPU this process may run on."""
    state = {}
    for cpu in cpus:
        base = Path(f'/sys/devices/system/cpu/cpu{cpu}/cpufreq')
        item = {}
        for name in ('scaling_governor', 'scaling_cur_freq'):
            try:
                item[name] = (base/name).read_text().strip()
            except OSError:
                item[name] = None
        state[cpu] = item
    return state


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def launch(engine, command, source, path, timeout):
    stdin = source if engine == HALO else b''
    start = time.perf_counter()
    process = subprocess.Popen(command if engine == HALO else command + [str(path)],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    timed_out = False
    try:
        stdout, stderr = process.communicate(stdin, timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        stdout, stderr = process.communicate()
        timed_out = True
    elapsed = time.perf_counter() - start
    return dict(engine=engine, seconds=elapsed, exit=process.returncode, timeout=timed_out,
                stdout=stdout.decode('ascii', 'replace'), stderr=stderr.decode('utf8', 'replace'))


def workloads(args):
    """(name, path, source bytes) of each selected workload, kernels first."""
    selected = []
    names = run.NAMES if args.kernels == 'all' else tuple(x for x in args.kernels.split(',') if x)
    if any(name not in run.NAMES for name in names):
        raise SystemExit(f'unknown kernel in {args.kernels!r}')
    if not set(args.scales) <= set(names) or any(n < 1 for n in args.scales.values()):
        raise SystemExit('--scale must name a selected kernel and a positive count')
    for name in names:
        path = HERE/'kernels'/f'{name}.lua'
        source = path.read_bytes()
        if name in args.scales:
            source, replacements = re.subn(rb'\Alocal N = [0-9]+', f'local N = {args.scales[name]}'.encode(), source)
            assert replacements == 1
        selected.append((name, path, source))
    if args.awfy:
        bundles = sorted(args.awfy.glob('*.lua'))
        if not bundles:
            raise SystemExit(f'{args.awfy}: no bundles')
        for path in bundles:
            selected.append((path.stem, path, path.read_bytes()))
    if args.only:
        only = args.only.split(',')
        missing = set(only) - {name for name, _, _ in selected}
        if missing:
            raise SystemExit(f'--only names unknown workloads: {sorted(missing)}')
        selected = [item for item in selected if item[0] in only]
    if len({name for name, _, _ in selected}) != len(selected):
        raise SystemExit('duplicate workload name')
    return selected


def materialize(out, name, path, source):
    """The file other engines read: the kernel itself or its scaled copy."""
    if path.read_bytes() == source:
        return path
    scaled = out.parent/f'{out.stem}-sources'/f'{name}.lua'
    scaled.parent.mkdir(parents=True, exist_ok=True)
    scaled.write_bytes(source)
    return scaled


def geomean(values):
    return math.exp(sum(math.log(x) for x in values) / len(values)) if values else None


def markdown(data, engines):
    others = [e for e in engines if e != HALO]
    head = '| Workload | Halo | ' + ' | '.join(others) + ' |'
    rule = '|---|' + '---:|' * (len(others) + 1)
    lines = ['Median seconds per launch; in parentheses Halo / interpreter, above 1 when Halo is slower.',
             '', head, rule]
    ranges = ['Relative range (max-min)/median of each median above.', '', head, rule]
    for name, record in data['workloads'].items():
        cells, spread = [], []
        for engine in engines:
            result = record['engines'].get(engine)
            if result is None or result['status'] != 'ok':
                cells.append('n/a')
                spread.append('n/a')
                continue
            cell = f'{result["median"]:.4f}'
            if engine != HALO:
                ratio = result.get('halo_over')
                cell += f' ({ratio:.2f})' if ratio is not None else ' (n/a)'
            cells.append(cell)
            spread.append(f'{100 * result["relative_range"]:.2f}%')
        lines.append(f'| {name} | ' + ' | '.join(cells) + ' |')
        ranges.append(f'| {name} | ' + ' | '.join(spread) + ' |')
    means = []
    for engine in others:
        item = data['geomean_halo_over'].get(engine)
        means.append('n/a' if item is None or item['value'] is None else f'{item["value"]:.2f} over {item["workloads"]}')
    lines.append('| geometric mean of Halo / interpreter | | ' + ' | '.join(means) + ' |')
    reasons = [f'- {name}, {engine}: {result["reason"]}'
               for name, record in data['workloads'].items()
               for engine, result in record['engines'].items() if result['status'] != 'ok']
    if reasons:
        lines += ['', 'n/a:'] + reasons
    return '\n'.join(lines + [''] + ranges) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--halo', type=Path, required=True, help='the bench host built from host/ (reads the script on stdin)')
    parser.add_argument('--engine', action='append', default=[], metavar='ID=COMMAND',
                        help='an interpreter; the workload file path is appended to COMMAND')
    parser.add_argument('--reference', required=True, help='the engine ID of PUC Lua 5.1.5, whose checksum every engine must match')
    parser.add_argument('--kernels', default='all', help="comma-separated kernels/ names, 'all' or ''")
    parser.add_argument('--scale', action='append', default=[], help='kernel=N, as run.py')
    parser.add_argument('--awfy', type=Path, help='directory of awfy.py bundles')
    parser.add_argument('--only', help='comma-separated workload names to keep')
    rounds = parser.add_mutually_exclusive_group(required=True)
    rounds.add_argument('--rounds', type=int, help='round-robin rounds per workload')
    rounds.add_argument('--sample', action='store_true', help='one round, to time the run before choosing --rounds')
    parser.add_argument('--timeout', type=float, default=180.0, help='seconds per launch')
    parser.add_argument('--manifest', type=Path, action='append', default=[], help='text file recorded verbatim (versions, flags)')
    parser.add_argument('--compiler', type=Path, help='the whitefootc that built --halo, recorded by its digest')
    parser.add_argument('--out', type=Path, required=True, help='JSON result; the markdown table goes beside it')
    args = parser.parse_args()
    self_check()
    count = 1 if args.sample else args.rounds
    if count < 1:
        parser.error('rounds must be positive')
    commands = {HALO: [str(args.halo.resolve())]}
    for item in args.engine:
        engine, _, command = item.partition('=')
        if not engine or not command or engine in commands:
            parser.error(f'bad or duplicate --engine {item!r}')
        words = shlex.split(command)
        executable = shutil.which(words[0])
        if executable is None:
            parser.error(f'{engine}: {words[0]} is not executable')
        commands[engine] = [str(Path(executable).resolve())] + words[1:]
    if args.reference not in commands or args.reference == HALO:
        parser.error('--reference must name an --engine')
    args.scales = {}
    for value in args.scale:
        name, scale = value.split('=')
        args.scales[name] = int(scale)
    selected = workloads(args)
    engines = list(commands)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    cpus = sorted(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else None
    data = dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                host=platform.platform(), started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                sample=args.sample, rounds=count, reference=args.reference, affinity=cpus,
                cpu_before=cpu_state(cpus) if cpus and len(cpus) <= 4 else None,
                engines={e: dict(command=c, sha256=digest(c[0])) for e, c in commands.items()},
                compiler_sha256=digest(args.compiler) if args.compiler else None,
                host_sources_sha256={str(p.relative_to(HERE)): digest(p) for p in
                                     (HERE/'modules.wfg', HERE/'host/module.wfm', HERE/'host/driver.wf')},
                scales=args.scales, manifests={str(p): p.read_text() for p in args.manifest},
                awfy_manifest=json.loads((args.awfy/'manifest.json').read_text()) if args.awfy else None,
                workloads={}, launches=[])
    failure = None
    try:
        for name, path, source in selected:
            file = materialize(args.out, name, path, source)
            record = dict(path=str(file), sha256=hashlib.sha256(source).hexdigest(), reference=None, engines={})
            data['workloads'][name] = record
            times = {engine: [] for engine in engines}
            failed = {}
            for index in range(count):
                active = [e for e in engines if e not in failed]
                shift = index % len(active)
                order = active[shift:] + active[:shift]
                results = {}
                for engine in order:
                    item = launch(engine, commands[engine], source, file, args.timeout)
                    item.update(workload=name, round=index + 1)
                    data['launches'].append(item)
                    results[engine] = item
                    print(f'{name} {index + 1}/{count} {engine}: {item["seconds"]:.6f}s exit={item["exit"]} '
                          f'stdout={item["stdout"].strip()!r}', flush=True)
                puc = results[args.reference]
                expected = canonical(puc['stdout'].encode())
                if puc['exit'] or puc['timeout'] or expected != puc['stdout'].encode():
                    raise RuntimeError(f'{name}: PUC 5.1.5 gave no checksum: exit={puc["exit"]}, '
                                       f'stdout={puc["stdout"]!r}, stderr={puc["stderr"][-300:]!r}')
                if record['reference'] not in (None, puc['stdout']):
                    raise RuntimeError(f'{name}: PUC 5.1.5 checksum changed between rounds')
                record['reference'] = puc['stdout']
                for engine, item in results.items():
                    reason = check(engine, expected, item)
                    if reason is None:
                        times[engine].append(item['seconds'])
                    else:
                        failed[engine] = f'round {index + 1}: {reason}'
            for engine in engines:
                if engine in failed:
                    record['engines'][engine] = dict(status='n/a', reason=failed[engine])
                else:
                    record['engines'][engine] = dict(status='ok', **run.summary(times[engine]))
            halo = record['engines'][HALO]
            for engine in engines:
                result = record['engines'][engine]
                if engine != HALO and result['status'] == 'ok' and halo['status'] == 'ok':
                    result['halo_over'] = halo['median'] / result['median']
            print(f'{name}: ' + ', '.join(
                f'{e}={r["median"]:.4f}' if r['status'] == 'ok' else f'{e}=n/a'
                for e, r in record['engines'].items()), flush=True)
    except Exception as error:
        failure = str(error)
        data['failure'] = failure
    data['cpu_after'] = cpu_state(cpus) if cpus and len(cpus) <= 4 else None
    data['geomean_halo_over'] = {}
    for engine in engines:
        if engine == HALO:
            continue
        ratios = [record['engines'][engine]['halo_over'] for record in data['workloads'].values()
                  if 'halo_over' in record['engines'].get(engine, {})]
        data['geomean_halo_over'][engine] = dict(value=geomean(ratios), workloads=len(ratios))
    args.out.write_text(json.dumps(data, indent=2) + '\n')
    table = markdown(data, engines)
    args.out.with_suffix('.md').write_text(table)
    print(table, flush=True)
    if failure:
        raise RuntimeError(failure)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
