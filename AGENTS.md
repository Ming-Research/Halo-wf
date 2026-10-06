# Halo-wf — agent instructions

Halo is a Lua 5.1 engine written in Whitefoot with an embedding interface,
with the JSON and MessagePack packages its codec libraries bind. Firn-wf
hosts it to run Redis scripts.

## Goal and priorities

Halo shows what Whitefoot gives a dynamic-language runtime and exposes what it
lacks: first scripts whose replies are byte-identical to the reference's and
measurements against PUC Lua 5.1, then what real Redis scripts need. When
priorities conflict:

1. reach the next end-to-end compatibility or performance experiment;
2. keep replies identical to the reference, with every safety check
   Whitefoot requires;
3. keep the implementation understandable and easy to change;
4. add only the evidence needed to trust the current result;
5. defer robustness, infrastructure and polish that no current experiment
   needs.

## Reference and correctness

- The reference is Redis 7.0.15 with its bundled Lua 5.1 (PUC Lua 5.1.5 with
  Redis's patches) on x86-64 Linux with glibc. `research/experiments/halo-oracle`
  holds its recorded replies; PUC's sources and Lua 5.1's test suite are
  further oracles, as is a format's specification for the JSON and
  MessagePack packages; Halo's own earlier output never is one.
- Halo's source never names Redis: the host supplies `redis.call`, `KEYS`,
  `ARGV`, the reply conversions and the script cache.
- No script, test or benchmark selects a special path in the engine, and no
  fallback conceals an unsupported feature.
- Ported code keeps its license notice beside it.
- The owner and the primary agent own the design tree, the package and module
  graph, the `.wfm` interfaces and the embedding interface; an implementer
  reports an insufficient interface with a minimal example instead of editing
  it.

## Whitefoot

Halo builds with the compiler release `whitefoot.pin` names, through the
`whitefoot-kit` submodule, whose [downstream.md](whitefoot-kit/downstream.md)
holds the pin, reading the language at the pinned commit, trying an unmerged
Whitefoot change and upgrading Whitefoot. A Whitefoot gap goes under
*Whitefoot requirements* in `docs/todo.md`. An upgrade whose compiler changed
code generation compares Halo's benchmarks before and after.

## Design tree and research

- Live trees: the root node files under `design/` other than `log.md`, each
  with its subdirectory. Change log: `design/log.md`. Research record:
  `research/investigations/` and `research/experiments/`. Maintained TODO:
  `docs/todo.md`. Form and readiness checks: `make design-lint` and
  `make design-ready`, with `lint.py` from the `design/skill` submodule.
- `research/investigations/halo/` holds the engine's design (`DESIGN.md`,
  `VM.md`), work order and falsifiers. Records written while Halo lived in
  the Whitefoot repository name that repository's tooling; their commands are
  history.
- A performance change is attributed with a same-source before-and-after
  comparison of interleaved full-LTO launches and a falsifier stated before
  measuring.

## Checks

- `make check`, the gate, runs in CI on every push: it downloads the pinned
  compiler and runs the design lint. It needs git, curl, Python 3, both
  submodules (`git clone --recurse-submodules`) and `/usr/bin/clang`, with LLD
  on Linux.
- `make design-ready` and `make pin-ready` run before a PR is marked ready,
  and in CI on ready PRs and on main.
- The completion review uses [docs/review-checklist.md](docs/review-checklist.md).

## Merge rules

1. A PR becomes ready only after the owner has approved every decision it
   needs, every design-tree change included; the approval is then recorded
   in `design/log.md`, which `make design-ready` checks.
2. A merge into `main` needs the owner's approval of that exact revision, the
   whole tree with its pins; a revision changed after approval or after its
   passing check needs both again.
3. That revision passes `make check` before the merge.
4. A change that moves `whitefoot.pin` or a submodule names the revisions it
   adopts and why. `main` pins a `wf-` release of a Whitefoot `main` commit,
   never a `wf-exp-` one, and submodule commits on their repositories' `main`.

No other step is an approval or merge precondition.

## Reports

At completion a report also names any pin or submodule moved, any Whitefoot
gap filed, and the oracle comparison's result on the validated revision.
