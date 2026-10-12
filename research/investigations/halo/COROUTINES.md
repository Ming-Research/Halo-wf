# Coroutines in Halo

Status: approved as an experiment; nothing here is implemented or measured
yet. Board item `halo-coroutine-study`.

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

Comparison 1. The 31 coroutine oracle scripts, with their replies
recorded on Redis 7.0.15, pass the gate together with every other oracle
script: 420 of 420 runs at budgets 1, 7 and 1000, both ordinary and
under collector stress (gate run 38207703397, source `d08f224`).

Collector validation (work order step 2). Twenty-six controls each delete
one marking line, or one closing call, of what coroutines added, and run
the coroutine group under collector stress (run 38208572999, `d08f224`):

- 14 change a recorded reply: a suspended frame, the open-upvalue list, a
  captured value, an owner's close, the library contexts' comparator, key
  and error, sort's two operands and pivot, a pattern's source and
  pattern, the current thread and the waiting resumer.
- 3 stop every case in host setup: the running thread's contents, its
  stack and the main thread. All 93 runs fail with native exit 4 while
  the baseline passes all 93, because the collector's live-cell guard
  finds the installed execution's cell freed and ends the script before
  any reply. `thread-controls.sh` now counts this fail-stop as detection.
- 9 leave every reply unchanged: a library context's table and function,
  a pattern's replacement, a dead coroutine's error value, a stopped
  coroutine's value, the explicit close of a dead coroutine's upvalues,
  the entry function, and the child and arguments of a transfer in
  progress. The code-reading review predicted exactly these nine. Each
  one's isolated probe observes the deletion. Whether a probe may stand
  in for a reply change is the owner's ruling (status board, coroutine
  item).

Comparison 2 passes. The 14900K ran it on CPU 2 with governor
`performance` (run 38213220871): main `3e86f0f` against branch `90d950b`,
six interleaved pairs, and a twin of main. For each kernel, the branch
over main against the allowance (larger relative range plus the twin's
difference):

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
