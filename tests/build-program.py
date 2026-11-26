#!/usr/bin/env python3
"""Builds one Whitefoot program of a graph, and only when what it is built from has changed.

    build-program.py --compiler WHITEFOOTC --graph DIR/modules.wfg --entry ENTRY -o OUTPUT [--cache DIR]

What a program is built from is the compiler (its bytes and, where WHITEFOOT_LANGUAGE names one, its language
package), the graph's directory and every package directory the graph names, followed through their own
modules.wfg. The script hashes the bytes and relative paths of all of them, and the entry. Where OUTPUT is there
and OUTPUT.inputs holds the same digest, the program is up to date and nothing is compiled. Otherwise it runs the
compiler from the graph's directory, as the Makefile always has, with `--cache DIR` when a cache is given, and
writes the digest once the build has passed.

The digest is of content, not of file times: a fast run's build directory is kept per work and reached from any
runner's checkout, whose file times say nothing about what the program was built from.
"""

import argparse
import hashlib
import os
import re
import subprocess
import sys
from pathlib import Path

PACKAGE = re.compile(r'^\s*package\s+\w+\s*=\s*"([^"]+)"\s*;', re.MULTILINE)


def package_dirs(graph):
    """The graph's directory and every package directory it reaches, each once."""
    seen = []
    pending = [graph.parent.resolve()]
    while pending:
        folder = pending.pop()
        if folder in seen:
            continue
        seen.append(folder)
        modules = folder / 'modules.wfg'
        if modules.is_file():
            for path in PACKAGE.findall(modules.read_text(encoding='utf-8')):
                pending.append((folder / path).resolve())
    return sorted(seen)


def hash_tree(digest, label, folder):
    for path in sorted(p for p in folder.rglob('*') if p.is_file()):
        digest.update(f'{label}/{path.relative_to(folder).as_posix()}'.encode() + b'\0')
        digest.update(path.read_bytes() + b'\0')


def inputs_digest(compiler, graph, entry):
    digest = hashlib.sha256()
    digest.update(b'entry\0' + entry.encode() + b'\0')
    digest.update(b'compiler\0' + compiler.read_bytes() + b'\0')
    language = os.environ.get('WHITEFOOT_LANGUAGE')
    if language and Path(language).is_dir():
        hash_tree(digest, 'language', Path(language))
    base = graph.parent.resolve()
    for folder in package_dirs(graph):
        hash_tree(digest, os.path.relpath(folder, base), folder)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description='Build a Whitefoot program when its inputs changed.')
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--graph', type=Path, required=True, help="the graph's modules.wfg")
    parser.add_argument('--entry', required=True)
    parser.add_argument('-o', dest='output', type=Path, required=True)
    parser.add_argument('--cache', type=Path, help='the compiler cache; none builds without one')
    args = parser.parse_args()

    graph = args.graph.resolve()
    output = args.output.resolve()
    stamp = output.with_name(output.name + '.inputs')
    digest = inputs_digest(args.compiler.resolve(), graph, args.entry)
    if output.is_file() and stamp.is_file() and stamp.read_text(encoding='ascii').strip() == digest:
        print(f'{output.name}: up to date, its inputs are unchanged', flush=True)
        return 0

    stamp.unlink(missing_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [str(args.compiler.resolve()), '--graph', graph.name, '--entry', args.entry, '-o', str(output)]
    if args.cache:
        args.cache.mkdir(parents=True, exist_ok=True)
        command += ['--cache', str(args.cache.resolve())]
    built = subprocess.run(command, cwd=graph.parent)
    if built.returncode != 0:
        return built.returncode
    stamp.write_text(digest + '\n', encoding='ascii')
    return 0


if __name__ == '__main__':
    sys.exit(main())
