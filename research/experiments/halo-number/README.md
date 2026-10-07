# Halo number comparison with PUC Lua

Compiler builds and checks have a persistent cache at
`${WHITEFOOT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/whitefoot}/halo-number`.
`--cache DIR` overrides it; `--no-cache` disables caching. Cache paths must be
outside the repository and survive scratch-executable cleanup.
This runner reports program execution times, so native builds default to
`--full-lto`. The compiler rejects combining `--full-lto` with `--cache`;
`--incremental` selects the persistent cache instead. Cached runtime timings
have unvalidated differences from full LTO and are only sizing observations.
Use the default or explicit `--full-lto` for runtime performance measurements.
Reused binaries must have been built with the corresponding mode.

This comparison checks `lib/halo/number` against Redis 7.0.15's bundled
PUC Lua 5.1.5 with Redis's patches, built on x86-64 Linux with glibc in the
C locale. It runs in Halo's gate through `make check-reference`.
`compare.py` builds the standalone Whitefoot adapter in
`lib/halo/number/tests/modules.wfg`, runs the oracles, checks each result and
process exit code, and optionally writes a Markdown report with `--results`.
[RESULTS.md](RESULTS.md) retains dated comparisons.

From the repository root on x86-64 Linux, with both submodules checked out
and git, curl, Python 3 and a C compiler available:

```sh
make toolchain
make number
```

`make toolchain` obtains the pinned Whitefoot compiler and installs its LLVM
toolchain. `make number` uses that compiler with `--incremental` and runs
`make reference-lua`, whose
[fetch-redis.sh](../halo-oracle/fetch-redis.sh) verifies the Redis source
archive and builds Lua with Redis's dependency Makefile. The executable,
headers and `liblua.a` are under `build/redis/redis-7.0.15/deps/lua/src`.
The default `NUMBER_SAMPLES=100` and `NUMBER_EXAMPLES=8` control random
sampling and the maximum mismatch examples printed per group.
`make check-reference` runs this comparison and the MessagePack comparison;
CI runs it alongside `check-core` and `check-extended` as the three groups
of `make check`.

For a direct invocation with an existing compiler and reference build:

```sh
python3 research/experiments/halo-number/compare.py \
  --compiler /path/to/whitefootc --incremental \
  --lua build/redis/redis-7.0.15/deps/lua/src/lua --samples 100
```

The runner itself requires Python 3 and a C11 compiler and rebuilds neither
Whitefoot nor Lua. Its adapter, C oracle host and temporary files stay
beneath this experiment directory and are deleted after each run; the
Makefile's reference build remains under `build/`. The source/test digest
in a generated report covers every number `.wf` and
`.wfm` file and the standalone test graph; executable and archive digests
identify the tested tools. Durations size correctness runs and do not measure
VM performance. Rerun when number code or the corpus changes; retain results
as dated evidence when the implementation is superseded. `--results` replaces
its destination, so use a separate output file when retaining earlier results.
`--musl-source /path/to/musl/src/math` enables the independent port comparison
described below. Other libc or architecture results are platform comparisons,
not qualification against Halo's reference.

## Oracle construction

[oracle.lua](oracle.lua) performs `tostring`, `tonumber`, `x ^ y`, `math.fmod`,
`math.floor` and `math.ceil` directly. Every input double starts as sixteen
hexadecimal IEEE 754 bits; string inputs are hexadecimal bytes, including
embedded NULs and non-ASCII bytes. No expected result comes from Halo's code.

The reference executable disables dynamic loading and binary chunk loading.
It runs the script with a Lua-only transport using `math.ldexp` to reconstruct
finite inputs exactly and `math.frexp` to extract their bits. This transport
preserves finite values, signed zeros and infinities, and supplies NaNs of the
requested sign; it cannot preserve or inspect NaN payloads or signalling bits.

For those bits, [bits.c](bits.c) is linked against the unchanged, adjacent
reference `liblua.a`. It creates a Lua state, installs two C helpers that only
copy doubles to/from `uint64_t` using `memcpy`, and runs the same script. All
number operations still execute inside the reference Lua library. The script
also runs in the supplied reference executable over the entire corpus. The
comparison requires agreement between the archive host and executable on
format bytes, parse verdicts, finite/infinite result bits and NaN
classifications only where the executable can reconstruct the input exactly.
For signaling or nondefault-payload NaN inputs, the executable cross-check
does not establish agreement: its fallback substitutes a default quiet NaN
of the requested sign. The archive host remains the exact-bit oracle for
every case, including those inputs and all NaN results.

The standalone Whitefoot adapter accepts a 17-byte header: one opcode and
two little-endian `u64` words. Opcodes 1, 3, 4, 5 and 6 select format, pow,
fmod, floor and ceil; the words hold argument bits. Opcode 2 uses its first
word as a byte length (at most 2048), followed by that many string bytes.
Opcode 0 terminates normally. Output is one line per input: number text,
sixteen hexadecimal result bits, or `nil` for a refused string. Reads and
writes handle partial transfers; an incomplete record or I/O failure exits
nonzero. The formatter receives its minimum permitted 32-byte buffer.

## Corpus and interpretation

The fixed seed is in `compare.py`. The direct runner defaults to
`--samples 10000`; `make number` uses 100. At the direct runner's default
scale the corpus includes:

- 10,000 random double bit patterns, plus signed zero, signed infinities,
  quiet/signalling NaNs, subnormal boundaries, integers, powers of two and
  ten, neighboring doubles, exact decimal halfway values and notation edges;
- tricky strings including ASCII whitespace, empty inputs, signs, exponents,
  hexadecimal integers/fractions, range errors, NaN payloads, incomplete forms,
  suffix garbage, C-string termination, and long decimal ties with sticky
  digits, plus independently generated decimal and hexadecimal strings;
- 10,000 power pairs divided between arbitrary bit patterns, wide positive
  magnitudes, ordinary finite arguments, bases close to one with large
  exponents, and negative bases with integer exponents, plus a special-value
  cross product;
- supplementary exact-bit comparisons for fmod, floor and ceil.

Every group is mandatory: any mismatch, including powers, fails the
comparison with exit status 1. ULP distance is the difference of monotonically
ordered IEEE encodings for finite results; negative and positive zero are
adjacent under this metric. NaN differences and other nonfinite differences
are counted separately and have no ULP distance. Bit equality is the primary
comparison for every arithmetic operation, including NaN payloads and zero
signs. Comparator controls deliberately change a format byte, parse verdict,
power bit and row count, and verify that each alteration is detected.

## Implementation lineage and platform limits

The decimal conversion and formatter adapt Firn's
`apps/firn/scores/{decimal,read,write}.wf`; formatting always rounds the exact
binary value to 14 significant digits, removing Firn's integer shortcut.
For non-NaN operands, `fmod`, floor and ceil use the specification's `frem`,
`ffloor` and `fceil`; their NaN handling follows the reference as described
below.

The power algorithm and tables port musl's Arm `pow.c`, `pow_data.c` and
`exp_data.c` from the local Emscripten SDK musl tree (SDK 3.1.12). The FMA log
path and compensated exponential path retain the original operation order;
all arithmetic is explicit Whitefoot `.strict`. The original stated
worst-case error is 0.54 ULP, not a promise of bit equality with another C
library. NaN propagation (sign, payload and argument priority) follows the
x86-64 Linux reference explicitly. Floating exception flags and non-nearest
rounding modes are outside Whitefoot's
floating-operation interface. The optional `--musl-source` comparison compiles
the original local C FMA algorithm and tables with contraction disabled. It changes only dependency
includes and the exported function name, and supplies bit helpers and
round-to-nearest exception-result adapters. It uses `WANT_SNAN=0`, as the local
musl header does, and disables rounding-mode branches that have the same
returned bits in round-to-nearest. The [earlier musl comparison](RESULTS.md)
agreed on every sampled non-NaN result. NaN propagation differs deliberately
to match the reference C library.
This separates algorithm differences between musl and the host C library from
translation defects. The sampled comparison is evidence, not a proof for all
binary64 argument pairs.

The library implements these glibc behaviors on x86-64, where the macOS
oracle used for the earlier results differs:

- `pow` quiets NaN operands and selects the base's NaN when both operands
  are NaNs. A quiet NaN is absorbed by `pow(x, 0)` or `pow(1, y)`, producing
  one; a signaling NaN is quieted and returned instead. A negative NaN base
  with a finite odd integer exponent becomes a positive quiet NaN with the
  same payload. An invalid power returns `0xfff8000000000000`.
- `fmod` with two NaN operands quiets both and selects the one with the
  larger fraction, choosing the positive one when the fractions tie. With
  one NaN operand it returns that NaN quieted. This rule is based on the
  fourteen observed pairs recorded in the
  [Linux comparison](RESULTS.md#linux-reference-comparison-2026-10-06).
- `floor` and `ceil` return a NaN unchanged, including its sign, payload and
  signaling bit.
- `strtod` NaN syntax is case-insensitive `nan`, optionally followed by
  parentheses containing an empty sequence or ASCII letters, digits and
  underscores (the n-char sequence). Other parenthesized text is left
  unread by glibc, so Halo's whole-string conversion refuses it. A numeric
  payload uses `strtoull` base 0: decimal, leading-zero octal, or `0x`/`0X`
  hexadecimal, saturating at `2^64 - 1` before masking to the fraction and
  setting the quiet bit. A valid sequence not wholly read as a number
  supplies no payload. The input sign is preserved.
- Hexadecimal subnormal conversion follows glibc's rounding, which drops
  the bit after the first 53 significant bits. The corpus witnesses are
  `0x1.00000000000018p-1023` and `0x1.00000000000008p-1023`.
  Decimal conversion retains its separate rounding path, witnessed by
  `1.1125369292536010620943507396011101645362026413971951890715156691871755365962210e-308`.
- Number formatting prints a positive NaN as `nan` and a negative NaN as
  `-nan`; macOS's `printf` prints both as `nan`.

C99 hexadecimal fractions are read by `strtod` before Lua's `strtoul`
fallback would be reached. The first NUL terminates the input; surrounding
ASCII whitespace and range errors are accepted, while trailing nonspace
bytes are refused. Other locales, floating exception flags and non-nearest
rounding modes are outside this comparison's coverage.

## musl license

Copyright (c) 2018, Arm Limited. SPDX-License-Identifier: MIT.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
