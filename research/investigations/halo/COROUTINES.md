# Coroutines in Halo

Status: implemented on the work branch; comparisons 1 and 2 passed and
comparison 3 is exploratory (Results below); the design-tree change is
proposed and awaits the owner. The owner has ruled on the nine collector
edges whose omission changed no reply (Results below). Two coroutine oracle
scripts added after the validated revision await their recording, a gate run
and a rerun of the collector controls. Board items
`halo-coroutine-study` (this study) and `halo-coroutines` (the implementation).

## Question

Can Halo provide Lua 5.1's `coroutine` library (`create`, `resume`,
`yield`, `status`, `wrap`, `running`) with replies and error texts
identical to Redis 7.0.15's, without slowing scripts that use no
coroutine, and what does Whitefoot refuse or compile poorly on the way?

## The prior objection, and what changed

[design/halo.md](../../../design/halo.md) excludes coroutines because none
of the 2,700 files in 2,168 repositories that call `redis.call` uses them
([survey](SCRIPTS.md#result)), and reconsiders an excluded function "when a
host reports a script that calls it". No host has reported one, so the
evidence of demand is unchanged.

What changed is the reason for asking. The owner's route for Halo puts a
coroutine study after the gate and performance work. The owner-wide goals
give the ground: a project written in Whitefoot exists to find what the
language lacks and to show that its safety holds in real programs. A
coroutine needs a second, suspended execution stack that the collector
traces, which upvalues reach across and which is swapped in and out of the
running interpreter. No part of Halo exercises that today. The study asks
whether Whitefoot expresses it soundly and fast, and it removes one of the
sandbox features [design/halo.md](../../../design/halo.md) excludes. Reopening the exclusion on this ground, rather than
on demand, is the owner's ruling (below).

Since then a host has asked for it: Firn's item for running scripts that use
the coroutine library depends on Halo providing it (status-board item
halo-firn-coroutine-needs).

## What Halo builds on

Read from the source at `15709ec`:

- Lua-to-Lua calls, `__call`, `pcall` (not `xpcall`), `error` and host calls are
  stackless: they push frame records on the VM's own frame stack and keep
  dispatching ([design/halo/calls.md](../../../design/halo/calls.md)).
- Library callbacks (metamethods through the slow executor, `__tostring`,
  the sort comparator, `table.foreach`, `gsub` with a function, `xpcall`,
  the generic-`for` iterator) re-enter `run` natively through
  `callback_values` (`lib/halo/vm/slow.wf`), at most 200 deep, refused with
  "C stack overflow" as PUC refuses.
- A budget stop or a pending host call inside such a callback already
  turns the native nesting into heap records. `park_suspended_stack`
  (`lib/halo/vm/continuations.wf`) copies every stack slot into a new box
  held in `vm.stopped_stack` (resumption copies them back), each native
  level returns, and `resume` continues
  from `CallbackFrame`, `LibraryContext`, `SortFrame` and
  `PatternSubFrame` records
  ([design/halo/embedding.md](../../../design/halo/embedding.md)).
- The value stack is an owned `Box<Slots<Value>>` that the `Engine` holds
  apart from the `Vm` (`lib/halo/embed/module.wfm`). `run` takes it as a
  parameter, so a different stack can be passed in without changing `run`.
- Everything else that describes one execution is a single field of `Vm`
  (`lib/halo/vm/module.wfm`): the frame stack, the open-upvalue list, the
  callback and library records, the saved checkpoint and the pending call.
- An open upvalue is `Upval::Open(slot: u64)` (`lib/halo/heap/module.wfm`),
  an index into whichever stack is running. With two stacks, a closure
  created in one coroutine and called from another would read the wrong
  stack. The collector does not mark an open upvalue's value; it relies on
  marking the stack (`lib/halo/heap/gc.wf`).
- `Value` has no thread variant, and the heap has four slab kinds:
  strings, tables, closures and upvalues.
- `run` carries eight values from arm to arm, and a ninth measured 8%
  slower on the dispatch ([design/halo/embedding.md](../../../design/halo/embedding.md)),
  so a coroutine must not add a parameter to `run`.

## Candidate mechanisms

A. **Swapped execution state, stackless switch.** A coroutine is a new
heap object holding its own stack box, frame stack, open-upvalue list and
library records. `resume` saves the running coroutine's state into its
object and swaps the resumed one's into the `Vm` and the stack parameter,
with Whitefoot's `swap` on whole boxes. `yield` and a coroutine's return
swap back and continue the resumer at its saved pc, inside the same `run`
loop, so no native recursion is added. An open upvalue names its
coroutine as well as its slot. Cost: the coroutine switch touches every
per-execution field, and the upvalue read and write paths gain a check of
which stack the upvalue belongs to; that check is on hot paths, and
comparison 2 measures both the read and the write path.

B. **Resume as a nested activation.** `resume` runs the coroutine through
the callback path, re-entering `run` as PUC's `lua_resume` re-enters
`luaV_execute`, and `yield` parks the coroutine through the existing
suspension records. Cost: each resume is a native level under the 200
limit on nested activations, whose agreement with PUC's limit on nested
resumes is unverified (the oracle group's deep chain settles it), and yield
inherits the whole-stack copy suspension does today.

A is proposed first: it keeps coroutine switches off the machine stack,
which is the property Halo's call design chose, and it is the version that
tests what this study is for, several owned stacks swapped through one
interpreter. B is the fallback if A's upvalue check fails the performance
comparison.

Either way, a yield must refuse where PUC 5.1 refuses ("attempt to yield
across metamethod/C-call boundary") and nowhere else. PUC's `lua_resume`
records the native call depth at which it resumes a coroutine
(`baseCcalls` in `ldo.c`) and refuses a yield only when the depth has grown
since, so the boundary is relative to the current coroutine's resume: a
metamethod, library callback or `xpcall` entered inside the coroutine
refuses, and one in the resumer around the `resume` call does not. `__call`
is the exception: PUC enters it as an ordinary call (`tryfuncTM` in
`luaD_precall`), so a yield inside a `__call` handler succeeds. A `pcall` inside the
coroutine also refuses, since it is a native call in PUC; in Halo it is
stackless, so a scan of the coroutine's own frames must enforce it. This
reading of PUC comes from its source, and comparison 1 checks it with
yields that must succeed beside those that must fail.

## Comparison, recorded before measuring

1. **Replies.** A new oracle group of coroutine scripts, recorded on Redis
   7.0.15 by the existing workflow: generators and `wrap`; every `status`;
   resuming a dead or running coroutine; yield outside a coroutine; yield
   across a metamethod, a `pcall`, an `xpcall`, the sort comparator and an
   iterator inside the coroutine, and yields that succeed when the resumer
   called `resume` from inside a `pcall`, a comparator or a metamethod, and
   inside a `__call` handler;
   errors inside a coroutine, as strings and as the error tables
   `redis.call` raises; `redis.call` inside a coroutine; closures sharing
   upvalues across coroutines; deep chains of nested resumes until the
   reference's own limit. Halo passes if every reply is byte-identical at
   budgets 1, 7 and 1000, ordinarily and under collector stress, which also
   covers a budget stop and a pending host call inside a coroutine. The
   coroutine sections of Lua 5.1's test suite, which F1 in
   [VM.md](VM.md#10-falsifiers-stated-before-measuring) removes, are not
   part of this comparison: F1 has no runner in this repository yet
   (status-board item halo-f1-runner), and they join F1 when it gets one.
2. **Cost to scripts without coroutines.** The seven halo-bench kernels,
   plus an eighth added before this comparison that assigns captured
   variables in a loop (none of the seven writes an upvalue), main against
   the same source with coroutines, six interleaved full-LTO pairs and a
   twin of main on the 14900K. Passes if no kernel is slower beyond its
   larger range and the twin's difference.
3. **Cost of a switch.** A producer-consumer kernel against PUC 5.1.5,
   same conditions. Exploratory: reported with a profile, no threshold.
4. **Whitefoot.** Every form the language refuses or compiles poorly on
   the way is recorded with a minimal witness and filed to the Whitefoot
   session, and the work waits on it rather than routing around it.

## Results that reject the proposal

- Comparison 2 fails for A and for B: coroutines stay excluded, with the
  measured cost as the ground added to the design node.
- A reply in comparison 1 can only be matched with a run-time check that
  hides a Whitefoot gap: the gap is filed and the work stops until it
  closes.
- Comparison 1 shows a reference behavior neither mechanism can reproduce:
  it is reported to the owner with the cases it covers.

## Owner's rulings

- The coroutine exclusion is reopened on the ground above, without new
  evidence of demand, as an experiment: the exclusion in
  [design/halo.md](../../../design/halo.md) stands until the comparisons
  pass, and a rejected result is recorded on that node (status-board card
  halo-card-coroutine-reopen, option A).
- Mechanism A is tried first, B is the fallback if A fails comparison 2
  (card halo-card-coroutine-mechanism, option A).

## Results

All on 2026-10-12, Whitefoot `wf-d837678c6905`, full LTO.

### Comparison 1

The gate run 38230219303 at source `29cd574` passed every oracle script,
the 34 coroutine scripts among them: 429 of 429 runs (143 scripts at budgets
1, 7 and 1000), both ordinary and under collector stress. Two coroutine
scripts added after that revision, `refused-resume-state` and
`gc-stopped-high-register` (both below), await their Redis 7.0.15 recording
and a gate run.

A resume refused at the nested-resume limit. In PUC Lua 5.1.5, `lua_resume`
refuses a resume past the C-depth limit through `resume_error`, which sets
the coroutine's top back to its frame base. For a coroutine that never ran,
that overwrites its function, so `costatus` finds an empty stack and reports
it dead, and a later resume says "cannot resume dead coroutine". A yielded
coroutine keeps its yield status and stays suspended. Halo left both
suspended; it now ends a never-started coroutine whose resume is refused at
the limit, and `refused-resume-state` checks both cases.

### Collector validation

Work order step 2. The first run had twenty-six controls; each deletes one
marking line, or one closing call, of what coroutines added, and runs the
coroutine group under collector stress (run 38208572999, `d08f224`):

- 14 change a recorded reply: a suspended frame, the open-upvalue list, a
  captured value, an owner's close, the library contexts' comparator, key
  and error, sort's two operands and pivot, a pattern's source and
  pattern, the current thread and the waiting resumer.
- 3 stop every case in host setup: the running thread's contents, its
  stack and the main thread. All 93 runs exit natively with status 4 (a
  runtime error in the host's setup chunk) while the baseline passes all
  93. `thread-controls.sh` counts this fail-stop as detection.
- 9 leave every reply unchanged: a library context's table and function,
  a pattern's replacement, a dead coroutine's error value, a stopped
  coroutine's value, the explicit close of a dead coroutine's upvalues,
  the entry function, and the child and arguments of a transfer in
  progress. The code-reading review predicted exactly these nine. Each
  one's isolated probe observes the deletion.

Why the three setup stops happen, read from the code rather than observed
(the test host does not print a setup error): with stress on, the engine's
start collects before the setup chunk's first call, and at that point the
chunk's main function is held only in stack slot zero of the installed
execution. Omitting the thread's contents, its stack values or the main
identity leaves that slot unmarked; the sweep frees the function, and the
call then refuses the freed closure ("invalid Lua closure"). The collector's
test of the installed cell's live flag does not stop any of them: for the
main omission it would fire only at the next collection, which the setup
chunk never reaches.

The owner ruled on the nine with option A (status board, coroutine item;
[collector validation](../../../design/halo/heap/collector-validation.md)):
add a script where one can make a reply depend on the edge, delete a mark
that marks nothing, remove a duplicate holder that hides an edge, and accept
the isolated probe for the rest with the reason recorded. The branch then:

- added `gc-library-table-sole` and `gc-error-over-limit`, whose replies
  depend on a library context's table and on a dead coroutine's error value;
  the second reaches the collection Halo runs when a coroutine stops above
  the test host's 64 MiB heap limit, which runs before a stopped copy is
  restored;
- added `gc-stopped-over-limit`, written for the stopped coroutine's value,
  which did not detect it (below);
- deleted the mark of a library context's function, because every library
  context saves a native frame without a closure, which leaves 25 controls;
- removed two duplicate holders so that existing scripts observe the other
  two marks: the collector's separate pass that closed dead coroutines'
  upvalues before sweeping, and the copy of the entry function in a new
  coroutine's stack slot zero.

The full rerun of the 25 controls (run 38223742481, source `319bf27`):

- 18 change a coroutine reply: frame, open-list, library-table,
  library-comparator, library-error, library-key, sort-a, sort-b,
  sort-pivot, pattern-source, pattern-pattern, error, current-thread,
  captured-value, owner-close, explicit-close, thread-entry and resumer.
- 3 fail-stop in setup (thread, stack, main), counted as detection.
- 4 change no reply and are each observed by their isolated probe:
  pattern-replacement, stopped, transfer-child and transfer-arguments. The
  owner accepted the isolated probes for these four. gsub's replacement
  stays in its caller's argument registers for the whole call; a pending
  transfer's child and arguments stay in the requesting call's registers
  until the transfer consumes the request.

The stopped copy is not a duplicate holder, and a script can observe it.
When a callback inside a coroutine first stops inside a native level,
`park_suspended_stack` copies the whole stack, and the native levels then
return through `callback_values`, `callback` and `library_dispatch`, each
truncating the live stack to its entry length. The callback's slots at or
above the outermost entry length are then held only by the copy, while the
collector marks the live stack only below that length. `gc-stopped-over-limit`
missed this: at budget 1 its callback first stops at its first call, before
the table exists, and from then on continues from its saved record without a
native level, so the over-limit collection at its later stop (246 collections
at budget 1 against 245 at 7 and 1000) finds the whole stack installed. The
new `gc-stopped-high-register` puts the table about 80 slots above the
coroutine stack's length at callback entry and drops 40 MiB before the
callback's first loop, so at budget 1 the over-limit collection runs at that
first stop while only the copy holds the table, and decoy tables made after
the stop would reuse the table's slot if it were freed. The prediction is
that the stopped control now changes this script's reply; it holds only once
the controls are rerun with the script recorded. The probes accepted by the
owner then cover three edges.

With the sweep's separate close removed, deleting the close in `free_thread`
(explicit-close) makes the upvalue probe fail at its owner-close check (exit
242) rather than the explicit-close check (exit 243), so the two checks now
exercise one path. The control therefore expects 242, and
`thread-controls.sh` says why.

### Collections at run exits

While a coroutine is installed, the driver collects at each exit from the
dispatch loop when reconciling the coroutine's buffer charges puts the heap
over its limit (`drive` in `lib/halo/vm/calls.wf`). That collection marks the
installed stack up to the largest of the current top, every frame's top and
a pending transfer's extent, and the whole stack when no frame remains.
Reading each exit for a live value outside those bounds found none:

- A finished run or callback (`Done`): `finish` places the results at the
  finished frame's function slot and sets the top just past them, so they
  are below the top; with no frame left the whole stack is marked.
- A pending host call: the call instruction sets the top just past its
  arguments before the call is prepared, and the pending call records that
  top. A host call made as a library callback takes its arguments above the
  top, but its native level parks the whole stack in the copy, which is
  marked. One gap was found: a `__call` handler shifts the arguments one slot
  up, and the top stayed where it was, so the last argument of a host call
  reached through `__call` sat at the top, which can also be the calling
  frame's top, and neither bound marked it. The collection runs at that exit
  only if the host allocates between the call's safepoint and deferring the
  call, because the safepoint has just tested the heap and the shift never
  grows the stack. The test host allocates nothing there, so no oracle script
  can observe it. The `__call` path now raises the top past the shifted
  arguments, as PUC's `tryfuncTM` does.
- A budget stop: every register of a frame lies below that frame's top, and
  a transfer requested but not yet consumed is covered by its extent, in the
  copy when a native level parked it.
- An error: the error value is saved with the execution's scalars and
  marked as the execution's error.

No other value was found that the collection could free while it is still
needed, and no oracle script was added.

### Comparison 2

Comparison 2 passes, so mechanism B, kept as the fallback, is not needed.
The 14900K ran it on CPU 2 with governor `performance` (run 38213220871):
main `3e86f0f` against branch `90d950b`, six interleaved pairs, and a twin
of main. For each kernel, the branch over main against the allowance (larger
relative range plus the twin's difference):

| Kernel | Branch / main | Twin / main | Allowance | Verdict |
|---|---:|---:|---:|---|
| fib | 1.0079 | 1.0002 | 3.57% | pass |
| loop | 0.9994 | 1.0002 | 0.09% | pass |
| integer-table | 0.9977 | 1.0091 | 5.55% | pass |
| string-key | 1.0012 | 0.9986 | 8.35% | pass |
| concat | 1.0006 | 0.9966 | 2.48% | pass |
| sort | 0.9835 | 0.9991 | 6.57% | pass |
| binary-trees | 1.0029 | 0.9938 | 3.18% | pass |
| captured-assignment | 0.9667 | 0.9947 | 3.96% | pass |

Comparison 2 measured branch `90d950b` and was not rerun after these engine
changes:

- the sweep's separate pass over dead threads and the mark of a library
  context's function were removed, which removes work from every collection;
- the entry-function copy in a new coroutine was removed, and a resume
  refused at the depth limit now ends a never-started coroutine, which run
  only when a script creates or resumes a coroutine;
- a call through a `__call` metamethod now raises the top past its shifted
  arguments (collections at run exits, above). This adds one comparison and
  at most one store to every call made through `__call`, coroutines or not;
  none of the eight kernels calls through `__call`.

### Comparison 3

Comparison 3 is exploratory. The producer-consumer kernel takes Halo
3.59 times PUC 5.1.5's time: medians 0.0296 s against 0.0082 s, with
ranges of 0.4% and 2.3%. Its profile has 158 samples, too few for more
than a direction. 19% of them are in marking and 18% in the collection
check, so collection, not the switch itself, takes the largest share.
Coroutine exchange, transfer, storage refresh, deliver and scalar saves
together take 20%.

The run's JSON, manifest and profile are in
[`coroutines-2026-10-12/`](../../experiments/halo-bench/coroutines-2026-10-12/),
kept while the design node cites them.

### Comparison 4

Two Whitefoot gaps were found and filed; each has a witness in
[`halo-coroutines`](../../experiments/halo-coroutines/README.md), a program
that imports no Halo code.

- A swap of two boxed stacks loses the length the checker had proved. The
  `length_transport` witness requires the saved box to hold at least 256
  values, swaps the two boxes and ensures the active box holds at least 256;
  the pinned compiler refuses it with FN-9, an undischarged postcondition at
  the return, which is the refusal predicted for this pin. Halo meets the gap
  where the collector parks and reinstalls the installed execution and where
  a coroutine switch exchanges stacks: a `resize_stack` that only restates a
  length, and index tests after the exchange that never fail. Filed as the
  status-board item wf-need-halo-coroutines, which collects what Halo's
  coroutines need from Whitefoot, with Whitefoot's swap length and capacity
  fact rule, coord-wfbl-09-04-rule, under it. The owner ruled these sites an
  exception to the rule against routing around a Whitefoot gap: they stay
  until that rule lands, each site cites both items, and their removal is
  Halo's item halo-coroutine-swap-workaround.
- A qualified constant used as an assigned value gets a misplaced
  diagnostic. The `qualified_constant` witness assigns
  `pkg::qualified_source::marker` to a field; the compiler reports FORM-3,
  an unexpected token, at the next line's `set` instead of at the constant.
  Halo names such constants through an alias. Status-board item
  halo-req-qualified-constant-diagnostic.

The witness workflow concluded "failure" in every run (38214254017 at
`7babfa7`, 38223306565 at `c91b56b`, 38223717366 at `319bf27`) because of
exactly these two expected refusals: the workflow attempts every witness and
fails when any refuses, and in each run the other three witnesses
(`box_exchange`, `owner_branch`, `dispatch_exchange`) compiled and exited
zero.

## Work order

1. Record the oracle group on Redis 7.0.15, failing on Halo (a red
   baseline on the work branch, which is not merged until step 3 makes
   the gate pass).
2. The thread value, its slab kind, its tracing and the upvalue change,
   validated as the [VM stress experiment](../../experiments/halo-gc/README.md#vm-stress-experiment-f4)
   validates roots (Halo has no complete reachability verifier): the
   coroutine group under collector stress, and one missing-edge mutant per
   new edge (a suspended stack, its frames' closures, an inactive
   coroutine's open upvalues, the waiting resumer) that must change at
   least one coroutine reply (status-board card
   halo-card-coroutine-gc-validation, option A, the owner's ruling).
3. `resume`, `yield`, `status`, `wrap` and `running`, until comparison 1
   passes.
4. Comparisons 2 and 3 on the 14900K, through the coordinator's queue.
5. The design-tree change: the node's exclusion replaced by the decision
   and its grounds, or kept with the rejection's.
