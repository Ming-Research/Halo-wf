#!/usr/bin/env python3
"""Bundle the are-we-fast-yet Lua benchmarks that plain Lua 5.1 runs.

Each bundle is one self-contained Lua 5.1 script for the fastest-interpreter
baseline (README.md): the benchmark file and the modules it requires, each
unchanged and wrapped as a module loader, then a driver that makes the
harness's measured call once and prints 1 when every inner iteration
verified. Halo's bench host runs one script from stdin and has no `require`,
`io` or `os`, so harness.lua itself cannot run there; Python, not a shell
script, because the bundler follows `require` dependencies and records
per-file digests.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

REPOSITORY = 'https://github.com/smarr/are-we-fast-yet.git'
COMMIT = '74306fec151070fd07157cefeacf19e7e0bcdc89'

# Inner iterations, harness.lua's third argument: estimated from each
# benchmark's operation count for PUC Lua 5.1.5 at 0.3-1 s on the 14900K,
# before any measurement; the sample mode checks them. NBody verifies its
# result only at 250000 (or 1) inner iterations, upstream's own setting.
INCLUDED = {
    'List': 1000,
    'NBody': 250000,
    'Permute': 400,
    'Queens': 800,
    'Sieve': 2000,
    'Towers': 300,
}

# Plain Lua 5.1, which Redis's bundled PUC Lua 5.1.5 is when run standalone,
# has no bit library, and upstream reaches one through `bit32 or
# require'bit'` (LuaBitOp) on Lua 5.1 and 5.2.
EXCLUDED = {
    'Bounce': 'som.lua needs LuaBitOp bit (band, bxor, rshift) on Lua 5.1',
    'CD': 'som.lua needs LuaBitOp bit (band, bxor, rshift) on Lua 5.1',
    'DeltaBlue': 'som.lua needs LuaBitOp bit (band, bxor, rshift) on Lua 5.1',
    'Havlak': 'som.lua needs LuaBitOp bit (band, bxor, rshift) on Lua 5.1',
    'Json': 'som.lua and hashindextable.lua need LuaBitOp bit on Lua 5.1',
    'Mandelbrot': 'mandelbrot-fn.lua needs LuaBitOp bit (bxor, lshift) on Lua 5.1',
    'Richards': 'richards.lua needs LuaBitOp bit (band, bxor) on Lua 5.1',
    'Storage': 'som.lua needs LuaBitOp bit (band, bxor, rshift) on Lua 5.1',
}

REQUIRE = re.compile(r"""\brequire\s*\(?\s*['"]([A-Za-z0-9_.-]+)['"]""")


def checkout(path):
    """Fetch the pinned commit into path, or verify an existing checkout."""
    if not path.exists():
        path.mkdir(parents=True)
        subprocess.run(['git', 'init', '-q', str(path)], check=True)
        subprocess.run(['git', '-C', str(path), 'fetch', '-q', '--depth', '1', REPOSITORY, COMMIT], check=True)
        subprocess.run(['git', '-C', str(path), 'checkout', '-q', 'FETCH_HEAD'], check=True)
    head = subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
    if head != COMMIT:
        raise SystemExit(f'{path}: HEAD {head}, pinned {COMMIT}')
    dirty = subprocess.check_output(['git', '-C', str(path), 'status', '--porcelain'], text=True)
    if dirty:
        raise SystemExit(f'{path}: checkout differs from {COMMIT}:\n{dirty}')
    return path/'benchmarks'/'Lua'


def modules(lua, name):
    """The module and its `require` dependencies, dependencies first."""
    order, seen = [], set()

    def visit(module, chain):
        if module in seen:
            return
        if module in chain:
            raise SystemExit(f'require cycle: {" -> ".join(chain + [module])}')
        path = lua/f'{module}.lua'
        if not path.is_file():
            raise SystemExit(f'{name}: requires {module!r}, which benchmarks/Lua does not provide')
        text = path.read_text(encoding='utf-8')
        for dependency in REQUIRE.findall(text):
            visit(dependency, chain + [module])
        seen.add(module)
        order.append((module, path, text))

    visit(name, [])
    return order


def bundle(lua, name, inner):
    module = name.lower()
    parts = modules(lua, module)
    lines = [
        f'-- {name} from are-we-fast-yet {COMMIT}',
        '-- (https://github.com/smarr/are-we-fast-yet, benchmarks/Lua), bundled by',
        '-- research/experiments/halo-bench/awfy.py. Each module below is the upstream',
        '-- file unchanged, with its license notice, wrapped as a loader for the local',
        '-- require; the driver at the end makes harness.lua\'s measured call,',
        f'-- `{name} 1 {inner}`, once and without timing, and prints 1 when it verifies.',
        'local require',
        'local modules = {}',
    ]
    for module_name, _, text in parts:
        lines.append(f'modules[{json.dumps(module_name)}] = function (...)')
        lines.append(text.rstrip('\n'))
        lines.append('end')
    lines += [
        'do',
        '  local loaded = {}',
        '  require = function (name)',
        '    local module = loaded[name]',
        '    if module == nil then',
        '      local load_module = modules[name]',
        '      if load_module == nil then',
        '        error("module \'" .. name .. "\' is not bundled")',
        '      end',
        '      module = load_module(name)',
        '      if module == nil then',
        '        module = true',
        '      end',
        '      loaded[name] = module',
        '    end',
        '    return module',
        '  end',
        'end',
        f'assert(require({json.dumps(module)}):inner_benchmark_loop({inner}),',
        "       'Benchmark failed with incorrect result')",
        'print(1)',
        '',
    ]
    files = {str(path.relative_to(lua.parents[1])): hashlib.sha256(path.read_bytes()).hexdigest()
             for _, path, _ in parts}
    return '\n'.join(lines), files


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--checkout', type=Path, required=True, help='are-we-fast-yet checkout; fetched at the pinned commit when absent')
    parser.add_argument('--out', type=Path, required=True, help='directory for <Name>.lua bundles and manifest.json')
    args = parser.parse_args()
    lua = checkout(args.checkout.resolve())
    upstream = {path.stem for path in lua.glob('*.lua')}
    for name in list(INCLUDED) + list(EXCLUDED):
        if name.lower() not in upstream:
            raise SystemExit(f'{name}: no {name.lower()}.lua at {COMMIT}')
    args.out.mkdir(parents=True, exist_ok=True)
    # NBody's file names its origin but not its license, which upstream's
    # LICENSE.md gives; the bundles are redistributed as CI artifacts.
    (args.out/'LICENSE.md').write_bytes((lua.parents[1]/'LICENSE.md').read_bytes())
    manifest = dict(repository=REPOSITORY, commit=COMMIT, harness='harness.lua <Name> 1 <inner>',
                    excluded=EXCLUDED, bundles={})
    for name, inner in INCLUDED.items():
        text, files = bundle(lua, name, inner)
        out = args.out/f'{name}.lua'
        out.write_text(text, encoding='utf-8')
        manifest['bundles'][name] = dict(inner_iterations=inner, files=files,
                                         sha256=hashlib.sha256(out.read_bytes()).hexdigest())
        print(f'{out}: {", ".join(files)}, {inner} inner iterations')
    (args.out/'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
