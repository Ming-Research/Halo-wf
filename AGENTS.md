# Halo-wf — agent instructions

Halo-wf, Halo for short, is a Lua 5.1 engine written in Whitefoot with an
embedding interface, together with the general JSON and MessagePack packages
its codec libraries bind. Firn (Ming-Research/Firn-wf) hosts it to run Redis
scripts, but Halo's own source never names Redis: the host supplies
`redis.call`, `KEYS`, `ARGV`, the reply conversions and the script cache.
Whitefoot, the language and its compiler, is pinned as a compiler release
named in `whitefoot.pin`, and the `design-tree` skill as the `design/skill/`
submodule.

## Project goal

Halo exists to serve Whitefoot: it is the real interpreter that shows what
Whitefoot gives a dynamic-language runtime, with dynamic values, closures,
a collector and budgeted execution under the language's guarantees, and
exposes what Whitefoot still lacks. Reach, as early as possible, scripts
whose replies are byte-identical to the reference's and measurements against
PUC Lua 5.1, then grow to what real Redis scripts need.

When priorities conflict, use this order:

1. reach the next end-to-end compatibility or performance experiment;
2. keep replies identical to the reference, with every safety check
   Whitefoot requires;
3. keep the implementation understandable and easy to change;
4. add only the evidence needed to trust the current result; and
5. defer robustness, infrastructure and polish that no current experiment
   needs.

## Authority and reading

`design/` holds the decisions Halo is built on, each with its reason and
refused alternatives. Work is not planned in a document up front: a selected
direction gets `research/investigations/<name>/` for its design, measurements
and rejected alternatives, and its surviving decision goes to the design
tree. `research/investigations/halo/` holds the engine's design (`DESIGN.md`,
`VM.md`), its work order and its falsifiers. Read only the material relevant
to the task, and do not turn research into an implied implementation
requirement.

**The reference.** Halo's behavior is judged against Redis 7.0.15 and its
bundled Lua 5.1 (PUC Lua 5.1.5 with Redis's patches) on x86-64 Linux with
glibc. The oracle corpus in `research/experiments/halo-oracle/` records that
reference's replies; PUC's own sources and Lua 5.1's test suite are further
oracles.

**The language.** The pinned Whitefoot commit defines the language. Releases
carry only the compiler, so read the language in the Whitefoot repository at
that commit: the specification `spec/kernel-spec.md`, which is normative, the
maintained programs under `tests/programs/`, `docs/patterns.md` and the
standard library's interfaces `lib/std/**/module.wfm`. The commit is the
`commit` field of the release manifest that `make compiler` keeps as
`build/whitefoot/<release>/whitefoot-release.json`. Read a file with, for
example,

```sh
gh api 'repos/Ming-Research/Whitefoot/contents/spec/kernel-spec.md?ref=<commit>' \
  -H 'Accept: application/vnd.github.raw'
```

or `git show <commit>:<path>` in a local Whitefoot clone. The compiler's
diagnostics and repairs are the other source. Halo never vendors Whitefoot
source; see [The Whitefoot boundary](#the-whitefoot-boundary).

A finished task is not evidence: a claim cites a design-tree decision, an
investigation, a measurement with its workload, environment and comparison,
or an oracle independent of Halo. Research records written while Halo lived
in the Whitefoot repository cite Whitefoot paths and tooling of their time
(for example `.github/run-check.pl`); they stay as historical evidence, and
their commands are not current instructions.

## How work proceeds

A *material choice* changes accepted scripts or replies, a safety or trust
condition, a shared interface or representation, a significant performance
commitment or a standing project rule; only a material choice between viable
alternatives is a design decision. Restoring decided behavior or editing
prose without changing its meaning is routine.

1. **Before starting,** read the affected design-tree nodes and their
   ancestors, verify the worktree and PR state on resumption, and settle the
   direction with the owner as the `design-tree` skill describes.
2. **While working,** state why each material choice fits its evidence and
   record an experiment's criterion before using it to choose. Change the
   code and the design tree together on a Draft PR, and update what a changed
   conclusion affects in the same work.
3. **At completion,** run the [checks](#checks) and the [review](#review),
   then hand the work back as the skill describes, adding the validation run
   and its revision, what remains unverified, any pin moved or Whitefoot gap
   filed, and what the work found along the way.
4. **After the owner approves** every decision, write the log entry and mark
   the PR ready (rule 1 below).

**Judge a design by its merits, not by the work it takes.** No design
judgment weighs the existing code, tests or documents a choice would change,
nor the effort of changing them.

**Fix or record what you notice.** When work exposes a defect elsewhere, such
as a bug, an awkward interface, duplicated logic or a stale document, fix it
in the same change if it is small and within the files you are changing;
otherwise add an item to `docs/todo.md` with its impact, the change you would
make and when to reopen it. List each in the PR's *Found along the way*
section with its disposition.

**Verify with observations that could have come out otherwise.** A passing
result is evidence only if a wrong result would have failed it. Make each new
check fail once for each way it can fail, and never check a transform against
its own output. Resolve every commit id, path, count and measurement with a
tool when you write it. Another agent's or a reviewer's report is a lead to
verify, not evidence. A green result reached by weakening a requirement does
not answer the original question.

**Size a run before starting it.** Before any build, test batch, measurement
or experiment, run the smallest useful sample, time it and look at its
spread, then choose the scale; repeat or lengthen only where the spread is
too large to decide. Never open with a run of hours.

Use a PR as the owner's review surface from the start, as a Draft until rule 1
below lets it become ready. Push coherent progress to the same branch and keep
its description and actual validation results current. A series of dependent
PRs is stacked, each on the branch of the one before it. Updating a
work-branch PR never authorizes a merge into `main`.

**The design tree.** The `design-tree` skill (`design/skill/`, a submodule of
[Design-skill](https://github.com/Ming-Research/Design-skill) that Halo never
edits, linked from `.claude/skills/` and `.agents/skills/`) is the one
recurring procedure; a change to it is made in Design-skill. Its live trees
are the root node files under `design/` other than `log.md`, each with its
subdirectory, which the Makefile finds and lints; its log is `design/log.md`,
its research record `research/investigations/` and `research/experiments/`,
its TODO `docs/todo.md`, and its checks `make design-lint` and
`make design-ready`.

**Investigations and performance.** An investigation decides something.
Before measuring, write the question, the comparison that could answer it
either way and the result that would reject the proposal; the surviving
decision goes to the tree. Attribute a performance change with a same-source
before-and-after comparison of interleaved launches with full LTO, and a
falsifier.

## Agents

- The owner and the primary agent own the architecture: the design tree, the
  package and module graph, the Whitefoot module interfaces (`.wfm`) with
  their contracts and effect rows, and the embedding interface.
- Subagents are Codex models chosen by difficulty: GPT-6.1 Sol at high
  reasoning effort for simple tasks, GPT-6 Astra at high or max for complex
  ones. Fable is the last resort, used sparingly, only when the primary agent
  and both Codex models have failed at the task.
- An implementer that finds an interface insufficient reports the gap to the
  primary agent with a minimal example instead of editing it.

## Branch and main boundary

These are the complete approval and merge rules:

1. Work-branch changes need no approval, including the design tree, code,
   tests, gate wiring, the pins and documentation, except that new
   repository-root entries require owner approval. A PR becomes ready only
   after the owner has approved every decision it needs, including every
   design-tree change; the approval is recorded in `design/log.md` only then,
   and `make design-ready` checks the record.
2. Every change merged into `main` requires owner approval of the exact
   revision to be merged.
3. The exact revision merged into `main` must pass `make check` before the
   merge.
4. A change that moves `whitefoot.pin` or the `design/skill/` submodule names
   the revisions it adopts and why. A revision merged into `main` pins a
   `wf-` Whitefoot release, built from a commit on Whitefoot's `main`, never
   a `wf-exp-` experiment release, and a Design-skill commit on its `main`.

**Exact revision** is the complete tree that will enter `main`, the pins
included; if it changes after approval or after its successful check, rules
2 and 3 apply to the new revision. No other workflow step is an approval or
merge precondition.

## Checks

- `make check`, the gate, in CI on every push and on the revision to merge.
  It downloads the pinned compiler (`make compiler`) and runs every Halo
  check and the design lint. It needs git, curl, Python 3, the
  `design/skill` submodule (`git clone --recurse-submodules` or
  `git submodule update --init`) and the toolchain the compiler links with:
  `/usr/bin/clang`, and on Linux LLD, which CI installs.
- `make design-ready`, before marking ready and in CI on ready PRs and main:
  every design-tree change is approved in the log.
- Build and test through CI, not on a developer's machine; run a build or
  test locally only when CI cannot do it or the owner asks, and say so.
- Precise timing and performance run on the owner's i9-14900K self-hosted
  machine (runner labels `self-hosted`, `14900k`), never on a hosted runner
  or a laptop. Other projects share it: announce a long run before starting
  it.

## Review

One review per task, when the work is complete and before the handoff, and
whenever the owner asks for one. Start a separate, read-only agent that did
not implement the change, with the prompt in
[the review checklist](docs/review-checklist.md#how-to-review): GPT-6 Astra
at high effort and every applicable group for a change to code, tests, gate
wiring, a pin, the design tree or guidance; GPT-6.1 Sol at high effort and
groups A, D, M and V, plus R for a material choice, when only research
records or other prose changed. Fix every finding and review again as the
`design-tree` skill's workflow describes, push, verify that the remote head
is the reviewed revision, and fill the PR's review section.

## Upgrading Whitefoot

The owner periodically has an agent move every downstream project to the
latest Whitefoot. For Halo:

1. Take the Whitefoot `main` commit to adopt; its gate must have passed.
   If Whitefoot has no release `wf-<12-character hash>` for it, or the
   release was deleted (releases older than 30 days are deleted, except the
   newest), dispatch Whitefoot's compiler release workflow for that commit.
2. On a work branch, set `whitefoot.pin` to `release = wf-<hash>`.
3. Read what changed between the old and new pinned commits that can affect
   Halo: `spec/log.md` and the specification, the standard library's
   interfaces, and the compiler's diagnostics.
4. Adapt Halo to the new language and compiler, without weakening any check.
5. Run CI (`make check`); when the compiler's code generation changed,
   compare Halo's benchmarks before and after on the 14900K.
6. Open the PR naming both commits, both specification versions and every
   change Halo needed; it merges under rules 2 to 4.

A pin whose release is gone gets the same commit dispatched again.

## The Whitefoot boundary

- Halo builds with exactly the pinned release, and moving the pin is a
  deliberate change under rule 4. Halo never vendors Whitefoot source or
  pins Whitefoot as a submodule.
- A change Halo needs in Whitefoot is made in Whitefoot, under Whitefoot's
  own AGENTS.md, as a branch and PR in its repository. While that PR is
  open, an experiment branch here may pin its experiment release,
  `release = wf-exp-<12-character hash>`, which Whitefoot's release workflow
  makes for an unmerged commit whose gate passed; Halo's `main` adopts the
  change only through a `wf-` release after it merges there (rule 4).
- When a missing Whitefoot feature would bend Halo's implementation or
  architecture, add the feature to Whitefoot instead of working around it.
  State the gap as its minimal semantic example, apart from the engine code
  that exposed it, and record it under *Whitefoot requirements* in
  `docs/todo.md` until Whitefoot resolves it. A problem that belongs to the
  engine alone is fixed in Halo, not by generalizing the language.

## Code and tests

- Halo's implementation rules are its design decisions in `design/`; read the
  nodes a change touches and their ancestors before changing code.
- Correctness is judged by an oracle independent of Halo: the reference's
  recorded replies, PUC Lua 5.1's output or test suite, or a format's
  specification, never Halo's own earlier output.
- Halo's source never names Redis; Redis's commands, conversions and cache
  belong to the host.
- No script, test or benchmark selects a special path in the engine.
- Ported third-party code keeps its license notice beside it
  (`lib/halo/compile/LICENSE.md`, `lib/halo/vm/LICENSE.md`, and the `pow`
  notice in `lib/halo/number`).
- Never delete, disable, narrow or unwire a test or check merely to make
  `make check` green. A deliberately retired test leaves an honest technical
  explanation in the same change.

## Repository structure and hygiene

The repository root and every established directory are a curated, closed
set. Follow this by judgment and keep moving.

- Do not add a repository-root entry without owner approval. Put new material
  in the existing directory that owns its kind; if none fits, ask.
- Every new file, directory, script or document earns its place before it is
  created: name what it serves, its home and the condition under which it is
  removed.
- No bulk dumps. A script ships wired to a caller; a document ships into an
  existing home and is kept current or deleted.
- Prefer native tooling; a new script must justify why the native path cannot
  do the job.
- Supersede in place: when new material replaces old, update, merge or delete
  the old in the same change.
- Repository artifacts, identifiers, comments, diagnostics, fixtures, test
  names and file names use English.
- Each document keeps its role: `README.md` introduces and navigates, this
  file holds the goal, authority, process and rules, `design/` the decisions
  and their log, `docs/review-checklist.md` the review items, `docs/todo.md`
  open defects and Whitefoot requirements until resolved, `research/`
  questions, experiments and results, and the PR description the current
  change. None narrates editing history.

## Communication

Describe engine and language work with precise, neutral technical wording:
name the concrete rule, failure and expected behavior, and report material
risks accurately.

## Data safety

Preserve unrelated user changes in a dirty worktree. Never discard, overwrite
or rewrite work outside the requested change boundary.
