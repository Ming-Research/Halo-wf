#!/usr/bin/env python3
"""Records how redis-server 7.2.16 writes each double of the table, as a double reply and as a redis.call argument.

    python3 -B record.py --server PATH/redis-server --output PATH/redis-7.2.16.tsv

The oracle-reference workflow runs it against Redis 7.2.16 built from source
on the reference platform and uploads the table with the oracle replies; a
person reviews its difference from the committed table and commits it. Each
row is one binary64 bit pattern, sent to the script as its 8 bytes and read
with `struct.unpack`, so every NaN keeps its sign; the call-argument script
packs the number it passed back into 8 bytes, and the recorder requires them
to equal the pattern sent.

The values are the ones Whitefoot's first float-text experiment measured
(research/investigations/float-text/redis_double_oracle.py and reference.py
at Whitefoot commit 3d27ab4b67f0, CI run 38236089638): the same families,
seed and count, each value kept under the first family that produced it,
followed by the family `special` with both NaNs and both infinities.
"""
import argparse
import math
from pathlib import Path
import random
import socket
import struct
import subprocess
import sys
import tempfile
import time

HEADER = ['bits', 'family', 'double_reply', 'call_argument']
SEED = 20261012
COUNT = 5000
LIMIT = 2.0 ** 62
DOUBLE_SCRIPT = "local x = struct.unpack('>d', ARGV[1]) return {double=x}"
ARGUMENT_SCRIPT = ("local x = struct.unpack('>d', ARGV[1]) "
                   "redis.call('SET', KEYS[1], x) "
                   "return {redis.call('GET', KEYS[1]), struct.pack('>d', x)}")
KEY = 'double-text:k'
BATCH = 500

# reference.py's CASES at Whitefoot commit 3d27ab4b67f0.
CASES = [
    0.1, 0.1 + 0.2, 1 / 3, 1e17, 1e16, -0.0, 0.0, 5e-324, 2.225073858507201e-308,
    2.0 ** -1022, 1.7976931348623157e308, 2.0 ** 53 - 1, 2.0 ** 53, 2.0 ** 53 + 2,
    2.0 ** 62, 2.0 ** 63, 1e23, 9.66e21, 1e-5, 1e-7, 123456789012345.0, 99999999999999.5,
]
# Positive and negative quiet NaN (0/0 is the negative one on x86-64), +inf, -inf.
SPECIAL = [0x7ff8000000000000, 0xfff8000000000000, 0x7ff0000000000000, 0xfff0000000000000]


def bits(x):
    return struct.unpack('<Q', struct.pack('<d', x))[0]


def random_double(rng):
    """A uniformly random bit pattern of a finite nonzero double."""
    while True:
        b = rng.getrandbits(64)
        if (b >> 52) & 2047 != 2047 and b & ~(1 << 63):
            return struct.unpack('<d', struct.pack('<Q', b))[0]


def cases():
    named = CASES + [math.nextafter(LIMIT, math.inf), math.nextafter(LIMIT, 0.0),
                     1e22, 1e21, 1e-6, 1.5e300, 123456.789, 0.5, 100.0, 1.0]
    return named + [-v for v in named if v != 0.0]


def integer_edge():
    out = []
    for base in (2.0 ** 53, 2.0 ** 61, LIMIT, 2.0 ** 63):
        for sign in (1.0, -1.0):
            b = sign * base
            out += [b, math.nextafter(b, math.inf), math.nextafter(b, -math.inf)]
    return out + [-0.0, 0.5, -0.5, 1.0, -1.0, 1e18, 4.5e18, 4.7e18, 9.2e18,
                  float(4611686018427387903), float(4611686018427387905)]


def layout_grid():
    out = []
    for m in (1, 5, 15, 123, 1234567, 12345678901234567):
        for e in range(-30, 31):
            out.append(float('%de%d' % (m, e)))
            if m in (15, 1234567):
                out.append(-float('%de%d' % (m, e)))
    return out


def families():
    """(family, bit patterns) in the measuring run's order, then the special values."""
    def rng(name):
        return random.Random('%d-%s' % (SEED, name))

    sets = [('case', cases())]
    r = rng('random-bits')
    sets.append(('random-bits', [random_double(r) for _ in range(COUNT)]))
    r = rng('dec6')
    sets.append(('dec6', [float('%de%d' % (r.randrange(1, 10 ** 6), r.randrange(-16, 5))) for _ in range(COUNT)]))
    r = rng('dec3-big')
    sets.append(('dec3-big', [float('%de%d' % (r.randrange(1, 1000), r.randrange(19, 23))) for _ in range(COUNT)]))
    r = rng('uniform01')
    sets.append(('uniform01', [r.random() for _ in range(COUNT)]))
    sets.append(('layout-grid', layout_grid()))
    sets.append(('integer-edge', integer_edge()))
    out = [(family, [bits(x) for x in xs]) for family, xs in sets]
    return out + [('special', list(SPECIAL))]


def table_values():
    seen, values = set(), []
    for family, patterns in families():
        for pattern in patterns:
            if pattern not in seen:
                seen.add(pattern)
                values.append((pattern, family))
    return values


class Connection:
    def __init__(self, port):
        self.sock = socket.create_connection(('127.0.0.1', port), timeout=120)
        self.file = self.sock.makefile('rb')

    def close(self):
        self.file.close()
        self.sock.close()

    def pipeline(self, commands):
        wire = []
        for parts in commands:
            parts = [p if isinstance(p, bytes) else str(p).encode('ascii') for p in parts]
            wire.append(b'*%d\r\n' % len(parts))
            wire += [b'$%d\r\n%s\r\n' % (len(p), p) for p in parts]
        self.sock.sendall(b''.join(wire))
        return [self.reply() for _ in commands]

    def line(self):
        line = self.file.readline()
        if not line.endswith(b'\r\n'):
            raise ValueError('truncated RESP line')
        return line[:-2]

    def reply(self):
        prefix = self.file.read(1)
        if prefix == b'+':
            return ('status', self.line())
        if prefix == b'-':
            return ('error', self.line())
        if prefix == b':':
            return ('integer', int(self.line()))
        if prefix == b'$':
            n = int(self.line())
            if n < 0:
                return ('nil', None)
            data = self.file.read(n)
            if len(data) != n or self.file.read(2) != b'\r\n':
                raise ValueError('truncated RESP bulk')
            return ('bulk', data)
        if prefix == b'*':
            n = int(self.line())
            return ('array', [self.reply() for _ in range(n)])
        raise ValueError(f'unknown RESP prefix {prefix!r}')


def start_server(server, scratch, log):
    version = subprocess.check_output([server, '--version'], text=True)
    if not version.startswith('Redis server v=7.2.16 '):
        raise SystemExit(f'requires Redis 7.2.16, got {version.strip()}')
    with socket.socket() as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]
    process = subprocess.Popen([server, '--bind', '127.0.0.1', '--port', str(port), '--save', '',
                                '--appendonly', 'no', '--daemonize', 'no', '--dir', scratch],
                               cwd=scratch, stdout=log, stderr=subprocess.STDOUT)
    deadline = time.monotonic() + 10
    while process.poll() is None and time.monotonic() < deadline:
        try:
            return process, Connection(port)
        except OSError:
            time.sleep(0.1)
    process.kill()
    raise SystemExit(f'redis-server did not accept connections on port {port}')


def text(reply, what, pattern):
    kind, data = reply
    if kind != 'bulk':
        raise SystemExit(f'{pattern:016x}: {what} is {kind} {data!r}, not a bulk string')
    value = data.decode('ascii')
    if not value or any(c in value for c in '\t\r\n'):
        raise SystemExit(f'{pattern:016x}: {what} {value!r} cannot be a table field')
    return value


def record(connection, values):
    info = connection.pipeline([['INFO', 'server']])[0][1].decode('ascii')
    fields = dict(line.split(':', 1) for line in info.splitlines() if ':' in line and not line.startswith('#'))
    print('server: ' + ', '.join(f'{name} {fields.get(name)}' for name in
                                 ('redis_version', 'os', 'arch_bits', 'gcc_version')), flush=True)
    if fields.get('redis_version') != '7.2.16':
        raise SystemExit('the server is not Redis 7.2.16')
    rows = []
    for start in range(0, len(values), BATCH):
        chunk = values[start:start + BATCH]
        commands = []
        for pattern, _ in chunk:
            packed = struct.pack('>Q', pattern)
            commands.append(['EVAL', DOUBLE_SCRIPT, 0, packed])
            commands.append(['EVAL', ARGUMENT_SCRIPT, 1, KEY, packed])
        replies = connection.pipeline(commands)
        for index, (pattern, family) in enumerate(chunk):
            double_reply = text(replies[2 * index], 'the double reply', pattern)
            kind, items = replies[2 * index + 1]
            if kind != 'array' or len(items) != 2:
                raise SystemExit(f'{pattern:016x}: the call-argument script replied {kind} {items!r}')
            argument = text(items[0], 'the stored argument', pattern)
            if items[1] != ('bulk', struct.pack('>Q', pattern)):
                raise SystemExit(f'{pattern:016x}: the script passed another number, {items[1]!r}')
            rows.append([f'{pattern:016x}', family, double_reply, argument])
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--server', required=True, help='a redis-server 7.2.16 executable')
    parser.add_argument('--output', type=Path, required=True, help='the table to write')
    args = parser.parse_args()
    values = table_values()
    counts = {}
    for _, family in values:
        counts[family] = counts.get(family, 0) + 1
    print(f'{len(values)} distinct bit patterns: ' + ', '.join(f'{f} {n}' for f, n in counts.items()), flush=True)
    with tempfile.TemporaryDirectory(prefix='redis-double-text-') as scratch, \
            open(Path(scratch) / 'server.log', 'wb') as log:
        process, connection = start_server(args.server, scratch, log)
        try:
            rows = record(connection, values)
        finally:
            connection.close()
            process.terminate()
            process.wait(timeout=10)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, 'w', encoding='ascii', newline='') as table:
        table.write('\t'.join(HEADER) + '\n')
        for row in rows:
            table.write('\t'.join(row) + '\n')
    print(f'wrote {len(rows)} rows to {args.output}', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
