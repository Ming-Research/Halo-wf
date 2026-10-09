# Halo-wf — agent instructions

Halo is a Lua 5.1 engine written in Whitefoot with an embedding interface
(`lib/halo`), with the JSON and MessagePack packages its codec libraries bind
(`lib/json`, `lib/msgpack`). Firn-wf hosts it to run Redis scripts.

## Goal and first priorities

Halo shows what Whitefoot gives a dynamic-language runtime and exposes what it
lacks: first scripts whose replies are byte-identical to the reference's and
measurements against PUC Lua 5.1, then what real Redis scripts need. When
priorities conflict:

1. reach the next end-to-end compatibility or performance experiment;
2. keep replies identical to the reference, with every safety check
   Whitefoot requires.

## Reference

- The reference is Redis 7.0.15 with its bundled Lua 5.1 (PUC Lua 5.1.5 with
  Redis's patches) on x86-64 Linux with glibc. `research/experiments/halo-oracle`
  holds its recorded replies, which `.github/workflows/oracle-reference.yml`
  records on that platform; PUC's sources and Lua 5.1's test suite are
  further oracles, as is a format's specification for the JSON and
  MessagePack packages.
- Halo's source never names Redis: the host supplies `redis.call`, `KEYS`,
  `ARGV`, the reply conversions, the `EVAL` error reply and the script cache.

## Whitefoot

Halo builds with the compiler release `whitefoot.pin` names, through the
`whitefoot-kit` submodule, whose [downstream.md](whitefoot-kit/downstream.md)
holds the pin, reading the language at the pinned commit, trying an unmerged
Whitefoot change and upgrading Whitefoot. A Whitefoot gap goes to the
Whitefoot session that owns it, as an item in its area of the status board.
The upgrade's benchmark is
`research/experiments/halo-bench` (`run.py --before-binary`).

## Research and checks

- Research record: `research/investigations/` and `research/experiments/`;
  `research/investigations/halo/` holds the engine's design (`DESIGN.md`,
  `VM.md`), work order and falsifiers. Maintained TODO: the status board's
  Halo-wf areas (`halo-compat`, `halo-perf`, `halo-tools`); code and
  documents name an item by its key.
- Halo's performance comparisons build both sides with full LTO.
- `make check`, the gate, runs in CI on every push as three parallel groups
  (Makefile): core (the embedding probe, every oracle script at budgets 1, 7
  and 1000, ordinary and under collector stress, and the design lint),
  extended (the collector's root controls, the research hosts, the JSON
  package) and reference (the number library and the MessagePack package
  against Redis 7.0.15's bundled Lua built from source). It needs git, curl,
  Python 3, a C compiler, both submodules (`git clone --recurse-submodules`)
  and, on Linux, `/usr/bin/clang` and LLD of the LLVM major the pinned
  release names (`make toolchain` installs it).
- `make pin-ready` runs with the readiness check and refuses an experiment
  pin.
- The completion review uses [docs/review-checklist.md](docs/review-checklist.md).

## Reports

At completion a report also names any pin or submodule moved, any Whitefoot
gap filed, and the oracle comparison's result on the validated revision.
