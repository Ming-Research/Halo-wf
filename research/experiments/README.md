# Experiments

Each experiment keeps its sources, its commands and a RESULTS.md (the
oracle, a README) with measured numbers and their caveats. Binaries,
corpora downloaded for a run and scratch output are regenerated, not kept.
Experiments recorded while Halo lived in the Whitefoot repository name its
tooling and paths of that time; their results stand, and their commands are
history, not current instructions ([AGENTS.md](../../AGENTS.md#authority-and-reading)).

## Engine

- [halo-heap/](halo-heap/RESULTS.md) — E1: the generational handle heap
  against C and Redis's Lua on binary-trees.
- [halo-heap-core/](halo-heap-core/RESULTS.md) — slabs, strings, tables
  ported from `ltable.c`, closures and upvalues against independent value
  models and Redis's Lua traces.
- [halo-number/](halo-number/RESULTS.md) — `%.14g`, `str2number` and `pow`
  against Redis's bundled Lua.
- [halo-lex/](halo-lex/RESULTS.md) — token dumps and error texts against
  PUC's lexer.
- [halo-compile/](halo-compile/RESULTS.md) — the compiler against PUC's
  `luac` built from Redis's Lua sources.
- [halo-vm/](halo-vm/RESULTS.md) — the dispatch core's cell fixtures
  against the same programs run by PUC Lua 5.1.5.
- [halo-lib/](halo-lib/RESULTS.md) — the slice-1 standard library against
  Redis 7.0.15's Lua.
- [halo-patterns/](halo-patterns/RESULTS.md) — Lua 5.1 patterns against an
  authored differential corpus.
- [halo-luacodecs/](halo-luacodecs/RESULTS.md) — Redis's `cjson`,
  `cmsgpack`, `bit` and `struct` against a codec corpus.
- [halo-gc/](halo-gc/RESULTS.md) — F4: collector stress, removed-root
  controls and memory recovery.
- [halo-bench/](halo-bench/RESULTS.md) — P1 against PUC Lua 5.1.5 and the
  bounded performance experiments that followed it.

## End to end

- [halo-oracle/](halo-oracle/README.md) — the reference's exact replies to
  its scripts, recorded from Redis 7.0.15 on x86-64 Linux.
- [halo-e2e/](halo-e2e/RESULTS.md) — those scripts run through `pkg::embed`
  and an in-memory host; `make check` runs this comparison.

## Codec packages

- [json/](json/RESULTS.md) — the `lib/json` package against an independent
  oracle.
- [msgpack/](msgpack/RESULTS.md) — the `lib/msgpack` package against Redis's
  `cmsgpack` and every wire tag.

## Shared runner helper

The Python runners share [compiler_cache.py](compiler_cache.py) for
persistent cache paths and cache/full-LTO mode flags; the gate's runner,
`halo-e2e/run.py`, imports it too. The helper is removed when its last
runner no longer needs it. The [VM](halo-vm/README.md),
[pattern](halo-patterns/README.md) and [MessagePack](msgpack/README.md)
guides document their build and sample commands.
