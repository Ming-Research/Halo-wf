# Halo-wf — agent instructions

Halo is a Lua 5.1 engine written in Whitefoot with an embedding interface,
with the JSON and MessagePack packages its codec libraries bind. Firn-wf
hosts it to run Redis scripts.

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
  holds its recorded replies; PUC's sources and Lua 5.1's test suite are
  further oracles, as is a format's specification for the JSON and
  MessagePack packages.
- Halo's source never names Redis: the host supplies `redis.call`, `KEYS`,
  `ARGV`, the reply conversions and the script cache.

## Whitefoot

Halo builds with the compiler release `whitefoot.pin` names, through the
`whitefoot-kit` submodule, whose [downstream.md](whitefoot-kit/downstream.md)
holds the pin, reading the language at the pinned commit, trying an unmerged
Whitefoot change and upgrading Whitefoot. A Whitefoot gap goes under
*Whitefoot requirements* in `docs/todo.md`. An upgrade whose compiler changed
code generation compares Halo's benchmarks before and after.

## Research and checks

- Research record: `research/investigations/` and `research/experiments/`;
  `research/investigations/halo/` holds the engine's design (`DESIGN.md`,
  `VM.md`), work order and falsifiers. Maintained TODO: `docs/todo.md`.
- Halo's performance comparisons build both sides with full LTO.
- `make check`, the gate, runs in CI on every push: it downloads the pinned
  compiler and runs the design lint. It needs git, curl, Python 3, both
  submodules (`git clone --recurse-submodules`) and `/usr/bin/clang`, with LLD
  on Linux.
- `make pin-ready` runs with the readiness check and refuses an experiment
  pin.
- The completion review uses [docs/review-checklist.md](docs/review-checklist.md).

## Reports

At completion a report also names any pin or submodule moved, any Whitefoot
gap filed, and the oracle comparison's result on the validated revision.
