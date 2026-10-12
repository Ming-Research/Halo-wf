# Halo collector check

Checks the mark-and-sweep collector of `lib/halo/heap` (`gc.wf`; design in
[VM.md section 2](../../investigations/halo/VM.md#2-heap)) on a graph whose
every reference kind leads to one object only through it: A's array part
holds B, a node value holds the string s1, a node key is the table F; C is
alone, D and E form a cycle, s2 is alone. With A as the only root, exactly C,
D, E and s2 are freed and interning "s1" again returns the same handle; with
no root, all eight cells are freed.

```sh
whitefootc --cache "${WHITEFOOT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/whitefoot}/halo-gc" \
  --graph research/experiments/halo-gc/modules.wfg --function pkg::test::main -o /tmp/gctest
/tmp/gctest   # exit 0 when every check holds, otherwise the failing check
```

The cache persists outside the repository. For this direct compiler command,
omit `--cache DIR` to disable caching; the comparison runners expose
`--no-cache`. A program-speed measurement must replace `--cache DIR` with
`--full-lto` because cached runtime differences have not been measured.

Exit codes: 1 A freed, 2 B freed, 3 C kept, 4 D kept, 5 s1 not kept,
6 F freed, 20 wrong rooted count, 30 wrong unrooted count.

Result on 2026-10-04 (compiler from main 9a0d0af4f): exit 0. Each of three
mutants of `gc.wf`, dropping the marking of array values, of node keys or
of node values, fails with exit 2, 6 and 5 respectively.

The heap graph remains the independent reference-edge check; the VM stress
experiment below checks root enumeration. Remove the graph program when a
maintained heap test owns these same discriminating observations.

## VM stress experiment (F4)

Criterion recorded before the runs: the unchanged 80-script Redis 7.0.15
corpus must match at budgets 1, 7 and 1000 with full collection forced at
collector safepoints. Count completed collections per script, excluding the
preparation chunk. Run each missing-root mutant separately at stress and
restore it before the next mutant. A mutant that changes no corpus reply is
a coverage gap requiring a local discriminating Lua case. The restored case
must match its independently specified reply. For the 64 MiB logical heap
limit, an unbounded growing table must return an error containing
`not enough memory`, and another script on the same engine and store must
succeed afterward. These observations test VM roots and recovery, not a
complete reachability verifier or an operating-system RSS bound.

The stress instrumentation uses the existing heap trigger and sweep path;
its embedding switch is off in a new engine. The count saturates at u64
maximum and survives engine reset. Python remains fixture transport and
independent RESP2 comparison, never a Lua evaluator.

Initial sample at parent `c0cff8caed353ef0c601d407f14f47a5c888f25e`:
the native build exited 0 in 443.65 s (user 346.87 s, system 50.90 s).
`lua-core/counter-closure` at stress, budget 7, passed with 7 collections;
three direct executions exited 0 in 0.004048, 0.003436 and 0.003349 s.
This justifies the 80-script, three-budget comparison, with builds timed
separately from execution. A bounded 70-iteration growing-string table
probe exited 0 in 0.363477 s, returning 70 with 74,462,693 logical heap
bytes under a 67,108,864-byte limit. This is the negative control for the
missing memory-limit enforcement; it does not run an unbounded allocator
against the defective engine.

`memory-limit.lua` is the unbounded F4 witness; `memory-recovery.lua` runs
next on the same engine/store and independently expects bulk `alive` from
the key written before exhaustion. `run.py --verify-memory` owns their
execution. These local cases live here for F4 and are removed when a
maintained embedding test takes over their observations or Halo is retired.
`--cases PATH` selects a local root with `scripts/GROUP/*.lua` and paired
canonical `expected/GROUP/*.txt` files through the unchanged comparison.

Local root witnesses in `cases/` are consumed by `run.py --cases
research/experiments/halo-gc/cases`. Their expected replies follow directly
from their Lua source: `kept`, `zzz`, and `qqq`. The open-upvalue case leaves an abandoned
open cell ahead of a retained middle local, then captures a lower local;
recycling the abandoned cell can corrupt the sorted open list and prevent
the middle local from closing before its register is reused. They serve F4's
coverage gaps and are removed with this research probe or superseded by
maintained root tests. The suspended-stack case requires
`--collect-suspended` at budget 1: a synthetic back-edge collects before
resume, while the callback's stack extension is still parked. Local-variable
padding places `held` beyond the caller's stack length, making the snapshot
its sole root during that collection. It uses the
existing public VM dispatch and original cached constants; it does not
copy or reimplement root marking. Ordinary corpus execution does not enable
this extra checkpoint.

The frame-closure witness at budget 1 uses `--isolate-frames`: at budget
checkpoints the harness clears a frame's function-slot alias only when it
still equals that frame's closure. The function slot is the destination for
return results; the executing function's upvalue access uses the frame
record. This makes the frame the sole closure owner without changing the
Lua reply. The ordinary stack otherwise keeps that same closure reachable,
so a corpus pass alone cannot establish the separate frame-root path.
This isolation is an experiment condition, never the default harness mode.

## Thread payload controls

Board item `halo-coroutine-study` adds isolated thread observations to the
embedding smoke gate: allocation/free/reuse and capacity accounting, retained
and unreachable cells, intrinsic main identity, classifiers and logical-limit
failure/recovery. `thread-edges-probe.wf` gives each payload reference its own
fresh heap, with only that edge retaining its target string, unrelated garbage
that must be freed, and a second collection without the thread root. It also
checks dynamic top, the maximum frame window and the first dead stack slot.
These probes stay while the coroutine implementation needs their evidence;
remove them when maintained tests supersede the same observations.

The small-limit storage fixture uses `return 1` for its exact-one-collection
baseline: its measured loop has additional backedge safepoints under stress.
It then starts that loop with budget zero and creates the globally rooted
thread after the checkpoint, so reset cannot retire the measured owner.
Growing its reserved stack by 2048 logical bytes must force collection and
produce exactly `not enough memory`; removing the limit must let the same
cached loop return one. Setup failures have separate observation codes:

| Exit | Failed check |
| --- | --- |
| 217 | Measured loop compilation |
| 198 | Idle baseline result or exact-one collection |
| 199 | Zero-budget loop checkpoint |
| 196 | Thread allocation |
| 197 | Global-root injection |

Observations 218–220 retain their storage-growth, limit, error, collection,
live-charge and recovery checks.

`thread-controls.sh`, called by `controls.sh` when `THREAD_ROOT_MUTANTS` is
set, omits one marking or closing operation in a copied tree. It builds the
ordinary `test` entry and runs the unchanged e2e runner with `--filter
coroutines/ --budgets 1,7,1000 --gc-stress --case-timeout 60`; the runner's
default per-case limit stays 900 seconds, and the shorter limit only bounds a
mutant that loops (a timeout is never a detection). Before any omission, that same
comparison must pass with every edge present; newly added scripts therefore
need their Redis 7.0.15 recordings before this experiment can run.

Owner ruling `halo-card-coroutine-gc-validation`, option A, requires every
coroutine-edge mutant to change at least one coroutine oracle reply under
collector stress. An unchanged comparison is reported as `survived` and fails
the control. A differing canonical reply or native signal crash is
`detected`. A `fail-stop`, every case exiting natively with status 4 (a
runtime error in the host's setup chunk) while the baseline passes every
case, also counts as detected; the classifier accepts any exit 4, because the
host does not print the setup error. Compiler refusal, missing recordings, malformed transport or
statistics, zero stress collections, timeouts and harness exceptions are
`inconclusive` or `build-failed`, never detections by themselves. A completed
comparison with at least one qualifying difference still detects the mutant
when other cases have unqualified failures. The classifier's positive
and negative samples run in CI before baseline compilation; they include a changed
reply, a signal crash, transport/setup exits and a semantic failure mixed
with a zero collection count. The established isolated observations still
run, 26 across 25 rows, and must retain their specific native exits. For an
edge whose omission changes no reply, the owner accepted its isolated
observation as the validation, with the reason no script observes the edge
recorded ([collector validation](../../../design/halo/heap/collector-validation.md));
for every other edge it is evidence beside the oracle result.

Every mutation starts from original sources. The copied runner and copied
recordings make each report's source digest describe that mutation; read-only
access to the original git metadata supplies its parent revision. Reports
also hash the executable and compiler. `summary.tsv` records build, oracle
and probe exit codes, classifications and elapsed whole seconds. Per-edge
omission diffs, compiler diagnostics, oracle reports, native outputs and typed
actual replies are retained. The compiler provides no source-mutator command,
so this uses the established copy/delete/build control rather than adding a
production test path.

Run in CI. First select the single `stack` omission and inspect its build and
comparison durations before selecting further names or `all` (25 rows):

```sh
THREAD_ROOT_MUTANTS=stack make roots
# After the sample establishes a practical batch size:
THREAD_ROOT_MUTANTS=all make roots
```

The recorded runs came from a temporary workflow on the coroutine branch,
kept at [`319bf27`](https://github.com/Ming-Research/Halo-wf/blob/319bf27/.github/workflows/coroutine-thread-controls.yml):
it ran the command above on a hosted runner with a selected batch and kept
the diagnostics above as an artifact. A full run of all 25 controls took
about 55 minutes there; a repetition after a change to thread marking runs
the same command.

Names are `thread`, `stack`, `frame`, `open-list`, `library-table`,
`library-comparator`, `library-error`, `library-key`, `sort-a`,
`sort-b`, `sort-pivot`, `pattern-source`, `pattern-pattern`,
`pattern-replacement`, `error`, `stopped`, `main`, `current-thread`, and the
upvalue and switching names below; comma-separated names select a bounded
batch. The isolated probes give each library/sort/pattern field a distinct
sole-root target; oracle scripts may retain aliases. `open-list` uses a closed
capture to isolate the original handle edge, and also keeps the inactive-owner
observation 240 from `upvalue_roots`.

Each execution field has a single mark line. `collect_if_due` parks the
installed execution in its thread cell for the mark phase, as a coroutine
switch saves it, so `mark_thread_contents` in `heap/gc.wf` traces saved and
installed executions alike; `vm/collect.wf` marks only main and current
identities, globals, type metatables and constants. One omission therefore
removes a field's mark for every execution, and the coroutine oracle sees
both the running coroutine and the saved ones. A row may name extra runner
options: `frame` runs with `--isolate-frames`, which removes the installed
frames' function-slot aliases at budget checkpoints, and each distinct option
set gets its own unmutated baseline.

Some omissions may be observationally redundant under the public interface.
The first full run left nine rows unchanged. The branch changed five of them:
`gc-library-table-sole` and `gc-error-over-limit` are scripts whose replies
depend on `library-table` and `error`; `gc-error-over-limit` reaches the
driver's over-limit collection, which runs before a stopped copy is restored.
The mark of a library context's function was deleted with its row, because
every library context saves a native frame without a closure. `gc_sweep` no
longer closes unreachable owners in a pass of its own before `free_thread`
does, and a new thread no longer copies its entry closure into stack slot
zero, so existing scripts observe `explicit-close` and `thread-entry`. That
leaves 25 rows. The full rerun (CI run 38223742481, source `319bf27`)
detected 18 by a changed coroutine reply, stopped 3 in setup (`thread`,
`stack`, `main`, counted as detected) and left 4 unchanged. Read from the
code, the three setup stops have one cause: under stress the engine's start
collects before the setup chunk's first call, the omission leaves stack slot
zero of the installed execution unmarked, so the chunk's main function, held
only there, is freed and the call refuses it ("invalid Lua closure"). The
collector's test of the installed cell's live flag is not what stops them;
for `main` it would fire only at a later collection, which the setup chunk
never reaches. Each of the four unchanged rows is observed by its isolated
probe, and the owner accepted the probes for all four
([collector validation](../../../design/halo/heap/collector-validation.md));
three keep that acceptance:
`pattern-replacement`, because gsub's replacement stays in its caller's
argument registers for the whole call; `transfer-child` and
`transfer-arguments`, because `coroutine_transfer` clears the pending request
before saving the resumer, so those marks see a pending request only in the
driver's over-limit collection between a request and its transfer, where the
requesting call's registers also hold both (a wrapped child through the
wrapper in the call's function register).

The fourth, `stopped`, now has a script. Its mark is not a duplicate holder. When a callback first stops
inside a native level, `park_suspended_stack` copies the whole stack, and the
returning native levels (`callback_values`, `callback` and
`library_dispatch`) truncate the live stack to their entry lengths, so the
callback's slots at or above the outermost entry length are held only by the
copy, while the collector marks the live stack only below that length.
`gc-stopped-over-limit` missed this: at budget 1 its callback's first stop
comes at its first call, before the table exists; afterwards the callback
continues from its saved record without a native level, so the over-limit
collection at its later stop (246 collections at budget 1 against 245 at 7
and 1000) finds the whole stack installed. `gc-stopped-high-register` puts the
table about 80 slots above the coroutine stack's entry length and drops 40 MiB
before the callback's first loop, so at budget 1 the over-limit collection runs
at that first stop while only the copy holds the table. The `stopped` row is
expected to change its reply; the controls have not been rerun since, so this
is a prediction until they are. Rows that still change no reply remain
selected by `all` and are reported as such; no all-edge detection is claimed.

Owner-qualified observations in `upvalue-probe.wf` additionally check reads
and writes against active, inactive and suspended stacks; capture reuse and
closing against the current owner; and escaped captures after owner collection
and handle reuse. The new controls use the isolated `upvalue_roots` entry so
older observations cannot mask their intended failures; `open-list` also
expects 240 there, where an open capture outside the ordinary live stack
extent loses its sole retained value:

| Name | Omission | Expected exit | Failure observed |
| --- | --- | --- | --- |
| `captured-value` | Open capture's selected-value marking | 241 | An escaped closure loses its captured value although the closure survives. |
| `owner-close` | Shared conversion from Open to Closed | 242 | A surviving capture still names an owner whose storage has been freed. |
| `explicit-close` | Closing in `free_thread` | 242 | Explicit owner destruction leaves a capture open; with the sweep's separate close removed, the probe fails at its owner-close check before the explicit-close check (243), so the two checks exercise one path. |

Collection closes an unreachable owner's captures only in `free_thread`,
which sweeps threads after every other slab: each surviving open capture
marked the value it selects, so closing copies only retained values, and a
capture already swept is no longer live and is skipped. `owner-close`
removes the conversion that this close shares with retiring a thread. Escaped
captures retain their selected value without retaining the owner or unrelated
slots. A suspended saved execution uses `stopped_stack`; otherwise it uses
`stack`. `host_stopped` does not select authority because it can remain set
after restoration while the active stack changes. Switching must preserve
this authority invariant when it is introduced. The switching stage adds the resumer and request edges below.


Switching observations in `switch-probe.wf` retain the create/resume/yield
probe aliases for the established controls; those aliases use the same IDs
as the public coroutine table. They exercise counted transfers and nil holes,
cross-owner captures, tail calls, original error values, callback parking,
boundary and depth limits, shared budgets, pending and immediate host results,
host stops and reset. Those execution fixtures run at budgets 1, 7 and 1000, ordinarily and
under collector stress. The budget-identity observation runs at 1 and 7
because a slice of 1000 need not stop in every owner. Separate logical storage
exhaustion/recovery probes run at budget 1 without collector stress, lowering
the heap limit after the initial checkpoint and requiring a due collection.

Public-library observations 47–50 check registration, every status and running
identity, counted and tail wrap transfers, argument rejection and error values.
Direct Lua wrapper calls must prefix even an already located string; numeric
errors become strings, while table identity survives. Native `pcall` callers
add no wrapper location. These expectations follow the recorded coroutine
replies and Redis 7.0.15's bundled PUC `luaB_auxwrap` and `luaL_where`.

Observations 51–55 pause main while a wrapper's child is suspended and force
an ordinary safepoint collection before resuming it within that same start.
Only dead wrappers are carried across starts, where their child identity must
remain alive until the wrapper is dropped and collected. A later wrapper must
reuse the reclaimed slot without inheriting its old captures. These observations
run at budgets 1, 7 and 1000, ordinarily and under collector stress. They exercise
the existing closure-to-closed-capture-to-thread edges; no new collector edge
or separate missing-edge control is introduced by public wrap registration.

Five additional controls use `switch_roots`, with fresh isolated heaps and
an empty frame window where needed. A zero-mutant baseline must pass; each
omission must produce its specific observation:

| Name | Omission | Expected exit |
| --- | --- | --- |
| `thread-entry` | New thread's entry closure | 40 |
| `resumer` | Child's waiting resumer | 41 |
| `transfer-child` | Pending request's child | 42 |
| `transfer-arguments` | Pending request's argument extent | 43 |
| `current-thread` | Installed child identity | 46 |

Observations 44 and 45 put the pending request in the installed execution;
since collection parks it in its cell, they reach the same marking lines as
42 and 43, which fail first under either omission. They remain positive
observations of the parking.

Argument extents extend the ordinary stack-root window so the same slots are
marked and protected from dead-slot clearing. A separate marking call would
retain an object while still allowing its pending argument slot to be cleared.
Installed coroutine capacities use the same logical estimator as saved
payloads; call preparation and the outer driver reconcile growth before heap
limits or embedding suspension accept it. Main's installed storage retains
its existing treatment; when main waits in its cell its saved buffers are
charged, and restoring main releases that saved-storage charge.

Reset/start terminates every non-main execution, closes captures and releases
its buffers. A thread identity still reachable from a global or embedding pin
remains a dead cell until ordinary collection, because recycling such a handle
would make an old thread value alias a new coroutine. Host-stopped snapshots
are restored before closing captures, including captures beyond a native
wrapper's temporarily shortened stack. At budget 1000, deep foreach fixtures
first require an open capture containing 23 only in that snapshot; omitting
restoration would close it incorrectly. At smaller budgets the native frames
have already unwound, so recovery is checked against the current authoritative
storage.

No results are claimed by these authored controls. Their actual failures and
the restored positive observations must be recorded from CI before treating
the new edges as validated. Main's installed VM/embedding buffers retain their
existing accounting treatment at this stage; its empty counterpart cell is
charged 512 logical bytes. Thread-owned payload buffers and pattern output
reserve are charged by capacity, even when their live lengths are zero.

The corrected comparison (source digest recorded by the runner) passed
240/240 replies, with 20,450 collections per budget and no zero-count
script. Memory exhaustion/recovery passed at all three budgets; the sampled
budget-7 run took 0.763994 s, then the three-budget run took 0.358477,
0.356014 and 0.349269 s. These are correctness timings, not a performance
comparison. The cached corrected build took 418.89 s and the root-probe
build 210.21 s, both exit 0. The original embedding smoke exited 0.
Consumed suspended snapshots are released after restoration; a host-stopped
snapshot stays available through nested stop unwinding and is released on
reset. The [final validation](RESULTS.md#final-committed-collector-validation)
includes that retention guard, added after this preliminary comparison.

The cost-repair control adds `--omit-suspended-root` together with
`--collect-suspended --gc-stress`, budget 1. It swaps the parked snapshot into
an untraced harness local only during the synthetic collection, restores it
before resume, and keeps the VM continuation and expected `zzz` reply. The
comparison must fail when that sole root is omitted. This opt-in control
serves the cost repair's root guarantee; remove it when a maintained root test
owns this observation or this research probe is retired.
