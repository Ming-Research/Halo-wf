# Halo number oracle results

Run UTC: 2026-10-04T12:23:10+00:00.

Host: macOS-26.6.2-arm64-arm-64bit-Mach-O; Python 3.14.7.

Base revision at run: `14726fb50afc330b057bc7ad611c2c9f9bba6415`. Number source/test SHA-256: `0b8cebfb59a3e6c19a5ef89c6ae1358b3ea2d7ba6d0b9e032e24e6113da0f251`.

Compiler SHA-256: `58b92b43013a5e6da17cb92fd6bf5124a0b80d7475d3b5dac1683ad8dc8e9a11`.

Lua SHA-256: `dd2f2bb469b8c423292e23a5ab0dea2c4f3ea23658b76d55cd5f296d5d94e91e`.

Reference liblua.a SHA-256: `40c361395e506d975b9c9b4fa17f117db801ee57723379d16605a1d706f715e0`.

Seed: `0x48414c4f0902`; random samples per primary operation: 10000.

Corpus SHA-256 (Lua input): `cb39956a6185b26c26cf26cd3304b7bdda94b8c81d8f4321c7de9a033ccc18e1`.

| Group | Cases | Bit/text mismatches | NaN bit mismatches | Other nonfinite mismatches | Maximum finite ULP |
|---|---:|---:|---:|---:|---:|
| format | 13199 | 0 | 0 | 0 | 0 |
| parse | 165 | 0 | 0 | 0 | 0 |
| parse-decimal | 2000 | 0 | 0 | 0 | 0 |
| parse-hex | 2000 | 0 | 0 | 0 | 0 |
| pow-random | 10000 | 11 | 0 | 0 | 1 |
| pow-special | 841 | 3 | 0 | 0 | 1 |
| fmod | 2255 | 0 | 0 | 0 | 0 |
| floor | 2000 | 0 | 0 | 0 | 0 |
| ceil | 2000 | 0 | 0 | 0 | 0 |

Build: 1.696 s; Lua execution: 0.308 s; Halo execution: 0.361 s. These are sizing observations, not a performance comparison.

The reference executable also ran all 34460 cases in 0.076 s and agreed with the archive host on every finite bit, parse verdict and format byte, and every NaN classification. NaN signs and payloads are extracted only by the archive host.

Every returned line and all process exit codes were checked. Comparator controls detect a changed format byte, parse verdict, power bit and missing record.

Finite mismatch ULP histograms:

```json
{
  "pow-random": {
    "1": 11
  },
  "pow-special": {
    "1": 3
  }
}
```

First mismatches per group (inputs are hexadecimal IEEE bits, except S inputs are hexadecimal bytes):

```json
[
  {
    "group": "pow-random",
    "op": "P",
    "x": "4032c537f4fadac3",
    "y": "c0498dbadc38dcde",
    "oracle": "326bca636c9cfe53",
    "halo": "326bca636c9cfe54",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "4011b16c4601b5b2",
    "y": "c05259e438e3968b",
    "oracle": "36173f853511f981",
    "halo": "36173f853511f982",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "400cea39a800c3fc",
    "y": "404c1fcc5ef782e0",
    "oracle": "46734b788d242dd3",
    "halo": "46734b788d242dd4",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "40168c23afa98690",
    "y": "c0521966f30b26fa",
    "oracle": "34a4c99b2570d477",
    "halo": "34a4c99b2570d478",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "401a67a47f1fbe10",
    "y": "4040000000000000",
    "oracle": "45617a27f929a5e9",
    "halo": "45617a27f929a5ea",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "403377f6b469eb89",
    "y": "c049d6701c270e81",
    "oracle": "3219781f4c28546c",
    "halo": "3219781f4c28546d",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "40143892763a82be",
    "y": "405142b6826b052e",
    "oracle": "4a0533453697f461",
    "halo": "4a0533453697f462",
    "ulp": 1
  },
  {
    "group": "pow-random",
    "op": "P",
    "x": "3ffd27b2983cecda",
    "y": "c048f414864bc1e7",
    "oracle": "3d3bcc1ca02704ee",
    "halo": "3d3bcc1ca02704ef",
    "ulp": 1
  },
  {
    "group": "pow-special",
    "op": "P",
    "x": "0010000000000001",
    "y": "3fe0000000000000",
    "oracle": "2000000000000000",
    "halo": "2000000000000001",
    "ulp": 1
  },
  {
    "group": "pow-special",
    "op": "P",
    "x": "7fefffffffffffff",
    "y": "3fe0000000000000",
    "oracle": "5ff0000000000000",
    "halo": "5fefffffffffffff",
    "ulp": 1
  },
  {
    "group": "pow-special",
    "op": "P",
    "x": "433fffffffffffff",
    "y": "bff0000000000000",
    "oracle": "3ca0000000000000",
    "halo": "3ca0000000000001",
    "ulp": 1
  }
]
```

Independent comparison with the original local musl C FMA path (same power inputs). NaN payload priority intentionally follows the macOS oracle; the musl C comparison additionally confirms every non-NaN result bit of the port. The macOS NaN priority is superseded by the [Linux reference comparison](#linux-reference-comparison-2026-10-06); the measurements below describe this earlier run:

```json
{
  "source_sha256": "1b7dc6685992628866c97011310cf4969a9592d431fad55cbd68613e948052f7",
  "seconds": 0.3587712086737156,
  "groups": {
    "pow-random": {
      "count": 10000,
      "mismatches": 0,
      "nan_bit_mismatches": 0,
      "nonfinite_mismatches": 0,
      "max_ulp": 0,
      "ulp_histogram": {}
    },
    "pow-special": {
      "count": 841,
      "mismatches": 22,
      "nan_bit_mismatches": 22,
      "nonfinite_mismatches": 0,
      "max_ulp": 0,
      "ulp_histogram": {}
    }
  },
  "examples": [
    {
      "group": "pow-special",
      "op": "P",
      "x": "7ff8000000000000",
      "y": "fff8000000000000",
      "oracle": "7ff8000000000000",
      "halo": "fff8000000000000",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "7ff8000000000000",
      "y": "7ff8000000004321",
      "oracle": "7ff8000000000000",
      "halo": "7ff8000000004321",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "7ff8000000000000",
      "oracle": "fff8000000000000",
      "halo": "7ff8000000000000",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "7ff8000000004321",
      "oracle": "fff8000000000000",
      "halo": "7ff8000000004321",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "bff0000000000000",
      "oracle": "7ff8000000000000",
      "halo": "fff8000000000000",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "3ff0000000000000",
      "oracle": "7ff8000000000000",
      "halo": "fff8000000000000",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "c090cc0000000000",
      "oracle": "7ff8000000000000",
      "halo": "fff8000000000000",
      "ulp": null
    },
    {
      "group": "pow-special",
      "op": "P",
      "x": "fff8000000000000",
      "y": "433fffffffffffff",
      "oracle": "7ff8000000000000",
      "halo": "fff8000000000000",
      "ulp": null
    }
  ]
}
```

## Later change

After these results, `format_number` was changed to print a negative NaN as `-nan`,
as glibc does on Linux, the platform reference firn and Halo share (VM.md, H4).
The macOS oracle above prints `nan` for that bit pattern, so a rerun on macOS
reports those NaN cases as mismatches. The pending Linux rerun noted here
is superseded by the [Linux reference comparison](#linux-reference-comparison-2026-10-06).

## Linux reference comparison (2026-10-06)

Question: does `lib/halo/number` match Redis 7.0.15's bundled Lua on Halo's
reference platform, including the NaN and parsing behavior that differs
from macOS? A differing format byte, parse verdict or arithmetic result bit
is a mismatch; the observed results below include power differences even
though the runner did not make them fatal in this run.

Platform and versions: x86-64 Linux with glibc, GitHub Actions
`ubuntu-24.04` (Ubuntu 24.04.5), Redis 7.0.15's bundled PUC Lua 5.1.5 with
Redis's patches in the C locale, Whitefoot release `wf-e1708490c384`,
Clang and LLD 22.1.8 installed by `make toolchain`, and Python 3.12.3.
The package log reports `libc-bin 2.39-0ubuntu8.9`. `make reference-lua`
uses [fetch-redis.sh](../halo-oracle/fetch-redis.sh) to verify Redis's source
archive and build Lua through Redis's dependency Makefile. The comparison
uses that executable and its adjacent `liblua.a`, with the C transport
preserving every input and result bit.

[CI run 37549220954](https://github.com/Ming-Research/Halo-wf/actions/runs/37549220954),
job `make check-reference`, checked revision
`acb39ad7fc9dce692137dc9753f30c8008e4a2d3`. Its number report was printed at
2026-10-06T23:56:37Z. The job ran, from the repository root:

```sh
make toolchain
make -k check-reference
```

The `number` target ran `compare.py` with `--incremental`, the built
reference Lua executable, and the defaults `NUMBER_SAMPLES=100` and
`NUMBER_EXAMPLES=8`. The corpus seed was `0x48414c4f0902`. The reference job
passed, and every number group reported zero mismatches:

| Group | Comparisons | Bit/text mismatches |
|---|---:|---:|
| format | 3299 | 0 |
| parse | 168 | 0 |
| parse-decimal | 100 | 0 |
| parse-hex | 100 | 0 |
| pow-random | 100 | 0 |
| pow-special | 841 | 0 |
| fmod | 355 | 0 |
| floor | 1100 | 0 |
| ceil | 1100 | 0 |

NaN bit mismatches, other nonfinite mismatches and maximum finite ULP
distance were also zero in every group. The runner checked record counts
and process exit codes, and its comparator controls detected changed
format bytes, parse verdicts, power bits and missing records.

### Disagreements and their disposition

The earlier CI logs distinguish transport defects from library differences:

| Evidence | Difference | Change and disposition |
|---|---|---|
| [37543253428](https://github.com/Ming-Research/Halo-wf/actions/runs/37543253428) | The reference executable printed `-nan` for a positive NaN input while the archive host printed `nan`. Its pure-Lua transport constructed NaNs from Linux's negative `0/0`. | `675fa00ae7cd7312f22230490a1888f237d29ea7` starts from a positive NaN before applying the requested sign. Fixed in the transport. |
| [37544459568](https://github.com/Ming-Research/Halo-wf/actions/runs/37544459568) | For `pow(0x7ff0000000000001, 0)`, the archive host returned `7ff8000000000001` but the executable returned one: the fallback could not construct the signaling input. | `ff4f9507b2b636183dd7ab4eda289ddb1ae6395f` restricts executable/archive agreement to inputs the fallback can represent. The archive host remains the exact-bit oracle for all cases. |
| [37546537009](https://github.com/Ming-Research/Halo-wf/actions/runs/37546537009) | 129 library mismatches: parse 11, pow-random 7, pow-special 97, fmod 10, floor 2 and ceil 2. Parsing differed on NaN syntax/payloads and hexadecimal subnormal rounding; power differed on invalid-result NaN sign, NaN priority, signaling NaNs and negative NaN bases with odd exponents; floor/ceil quieted signaling NaNs. | `81a327471d8f8571c04ca67ad652db2ced8c3987` adopts the glibc parsing, power and floor/ceil behavior and begins explicit fmod NaN selection. It also adds two hexadecimal and one decimal subnormal inputs. Power's integer-XOR correction and the final fmod rule are recorded below. |
| [37547690986](https://github.com/Ming-Research/Halo-wf/actions/runs/37547690986) | The adapter failed to compile: `bxor(x_quiet, sign_bit)` used boolean XOR on integer bits. This run produced no numerical comparison. | `00e9b6856dcbd86204b4a4ad0e6892d43b735a00` uses `ixor` to flip the NaN sign bit. Fixed. |
| [37547846303](https://github.com/Ming-Research/Halo-wf/actions/runs/37547846303) | All groups matched except ten fmod NaN results under divisor-first selection. | `342b4e36d1638545f9a8b6fa0de00b3c37770d06` tried dividend-first selection. That rule was superseded after the next run exposed different mismatches. |
| [37548655572](https://github.com/Ming-Research/Halo-wf/actions/runs/37548655572) | Dividend-first selection produced ten different fmod NaN mismatches; all other groups matched. | `acb39ad7fc9dce692137dc9753f30c8008e4a2d3` selects the larger fraction after quieting both NaNs, preferring the positive NaN on a tie. With one NaN it returns that NaN quieted. The rule was based on fourteen observed pairs and passed run 37549220954. |

`ecf24bec0c0824d2d6f22922d6f9142cbe5e62b3` added `--examples` and used
`NUMBER_EXAMPLES=200` in CI to expose the mismatches in the diagnostic runs.
This changed reporting, not expected results. The successful run used the
default limit of eight. NaN printing already matched glibc in run
37546537009; the signed spelling described under [Later change](#later-change)
was not a remaining mismatch.

### Limits

This is a correctness sample with 100 random inputs per primary operation,
not a repeat of the earlier 10,000-sample macOS run. The fixed cases and
generated strings do not exhaust binary64 values, power or fmod operand
pairs, NaN payloads or numeric strings. The hexadecimal subnormal examples
and the added decimal witness do not establish every underflow rounding
case. The fourteen fmod pairs support the adopted rule on the observed
reference; they do not establish a rule for every libc or architecture.

The pure-Lua executable cannot independently check signaling or payload NaN
inputs, nor extract exact NaN result bits; those comparisons rely on the
archive host. Other locales, floating exception flags and non-nearest
rounding modes are not covered. In run 37549220954, a successful runner exit
alone was not proof of zero power mismatches, since power differences were
reported but not fatal; this run's printed counts establish the result above.
The runner now fails on power mismatches too, as described in [README.md](README.md).
The optional musl C comparison was not run, and the cached build timings are not a
performance comparison.
