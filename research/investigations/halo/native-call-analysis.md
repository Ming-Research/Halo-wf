# Halo native-call analysis

Read-only source analysis, 2026-10-13. Source: Halo
`8ee6634fa608ddb13aa8272b51c0a2a696fa22e3`, the current worktree's HEAD and
local `origin/main`. Paths and line numbers below refer to that revision.
No compiler, build, test, benchmark, timing, commit or approval log was run
or written. The analysis itself is the only delivered file.

## Finding and recommendation

The successful `assert` body is small, but Halo reaches it through several
layers of native-function classification, reads arguments the success path
does not need, compacts **all** arguments into the result position, restores
an unchanged stack length twice, and runs the general return machinery.
PUC dispatches through the C closure's function pointer; its successful
`luaB_assert` returns the argument count without moving anything, and
`luaD_poscall` moves only the requested results.

Two corrections to the initial attribution matter:

* An ordinary native `assert` does **not** execute Halo's `Return` opcode.
  It returns within the `Call` handler. An allocation of the surrounding
  Lua function's Return-arm cost to `assert` needs checking against the
  profile's call edges.
* It does **not** construct a callback plan, push a library context or Lua
  frame, invoke `enter_lua`, or nil-fill a Lua register window. It pays
  classification tests for those possibilities, not their execution costs.

Recommend a successful-assert shortcut in native preparation, retaining the
existing argument compaction and `finish`. This removes routing overhead
without changing residual stack roots. It is a new selective call-lowering
decision and needs a design-tree addition. **Stop after phase 1.** Neither
the VM nor RESULTS.md nor the design tree has been changed.

I do not have evidence that this conservative change reaches 170–220
instructions. A provisional saving envelope is approximately 100–200
instructions per successful ordinary call (roughly 49–98M in Towers,
1.4–2.7% of the supplied 3,583,098,494 Ir baseline). This is a hypothesis,
not a reconstructed instruction tally. It leaves the budget/GC work, full
argument compaction, general finish and checked Step exit. The original
100–130M saving requires roughly 204–265 instructions removed per call at
the rounded 491K call count; source reading alone does not establish that.

## Evidence boundary

Read `../listtowers-attribution.md`, particularly 3(a)5, R7 and R8, and
`research/experiments/halo-bench/RESULTS.md:6423–6605`. The supplied
callgrind attribution is for profile head `d3746c1` based on `1f90750`,
Towers 60 iterations, full LTO, compiler `wf-d837678c6905`, hosted x86-64.
The selected calls/library/handler/state source files have no diff between
that source base and current HEAD. These are historical measurements, not
a fresh measurement of HEAD. The current pin is still `wf-d837678c6905`.

The approximately 181 for native preparation, 141 for `library_base` and
17 for `resize_stack` are supplied profile attributions. There are two
source-level resize calls; it is not established whether 17 covers one,
both, or one surviving after inlining. Do not multiply it by two. The
report has no retained binary or disassembly, and its PUC case-body
allocation is partly inferred. Consequently it does not support assigning
an exact instruction count to each source branch or treating the residual
of 530 minus these numbers as a native Return arm.

PUC comparison was read directly from the existing reference checkout at
`../redis-7216-oracle/redis-7.2.16/deps/lua/src/`; PUC citations below are
relative to that directory. No reference build was run.

## Exact path: successful ordinary `assert(x)`

For one explicit argument and discarded results, CALL has B=2 and C=1;
Towers' `assert(top, message)` instead has two arguments. The path below
also explains fixed-result and multiple-result uses. Global lookup is
outside this path and outside the proposed saving.

| Stage and source | Work performed; comparison with PUC |
| --- | --- |
| Registration: `lib/halo/vm/library.wf:143–152`, `module.wfm:138`; decoding: `state.wf:98–104` | `assert` has builtin ID 8. A normal builtin value becomes `FuncView::Native` directly. An alias still has this identity; no optimization may key on the source spelling `assert`. |
| Call arm: `dispatch.wf:414–415` | Calls `instruction_call`; the result later passes through the shared Step epilogue. PUC `lvm.c:588–608` calls `luaD_precall` and directly continues on PCRC. |
| `instruction_call`: `handlers.wf:3323–3356` | Computes the call slot and counts; charges budget before execution; checks collection stress, limit and allocation threshold, collecting if due; establishes argument top for B!=0, or derives argc from dynamic top for B=0; converts C to wanted (-1 for all). Budget charging is Halo's host-slicing work, not PUC's ordinary CALL path. Its GC rule is also a Halo requirement, not dispensable overhead. |
| `prepare`: `calls.wf:322–350` | Calls `prepare_inner`, then reconciles coroutine storage when current thread differs from main; preserves suspended/pending/host-stop precedence if accounting fails. Main-thread assert only tests the thread identities. PUC has no equivalent Halo coroutine-capacity accounting wrapper. |
| `prepare_inner`: `calls.wf:355–389` | Checks the function slot and classifies the value. A raw builtin skips the Lua-handle arm. For a `Fun` value only, `coroutine_is_wrapper` checks its closure, then `native_binding` checks live closure/callee and may decode codec configuration (`coroutines.wf:212–225`, `library-cjson.wf:168–200`). These helpers do not run for ordinary assert. |
| Native preparation: `calls.wf:391–440` | Checks coroutine ID range, writes active codec configuration (zero for ordinary assert), checks the invalid-call ID and pcall, classifies large-result functions (unpack, byte, xpcall, MessagePack, struct) and pattern functions. All room predicates are false for ID 8: **no `ensure_stack` executes**. PUC's C path checks LUA_MINSTACK once and uses a C CallInfo (`ldo.c:307–318`), rather than these ID classes. |
| Native routing: `calls.wf:441–466` | Distinguishes host IDs, computes call pc, reads context length, checks the five callback-capable builtins. For assert these are false: **no argument copy into a context, Frame, LibraryContext or CallbackPlan is built**. PUC calls the function pointer directly at `ldo.c:320`. |
| `builtin`: `builtins.wf:280–288` | Saves stack length, checks ID>=8, enters `library_dispatch`. Its argument reads below line 289 are skipped. |
| `library_dispatch`: `library-dispatch.wf:15–65` | Saves length, masks codec ID, checks codec and library ranges, finally calls `library_base`. PUC has no library-ID dispatch after choosing the C closure. |
| `library_base`: `library-base.wf:49–67` | Saves length; source eagerly reads arguments 0, 1 and 2 through `argument`, creates nil, checks xpcall, then assert; checks argc and truth. `argument` (`builtins.wf:122–130`) checks argc, uses saturating slot sums and checks bounds. Success needs only argument 0; whether LLVM already sinks the other loads is unverified. |
| `adjust_results` / `move_results`: `library-base.wf:65–67`, `calls.wf:29–74` | Compacts all argc arguments from func+1 to func, using clamped bounds and ascending copies, then updates vm.top. Even a caller requesting zero results pays this copy. PUC `lbaselib.c:334–338` checks argument presence and truth, then returns `lua_gettop`; it performs no compaction. |
| Stack restoration: `library-dispatch.wf:66`, `builtins.wf:287`; `state.wf:276–301` | Both wrappers call `resize_stack` with their entry length. Successful assert's movers preserve length. Thus both calls check capacity and the grow/shrink loop conditions but neither grows, fills nor shrinks anything. `library_dispatch` already advertises length preservation, so the outer restoration is redundant by contract. |
| Native outcome: `calls.wf:467–512` | Checks suspension and host stop, matches outcome; successful assert needs no error-location step or context discard. Non-tail Returned goes to `finish` with src=dest=func. Tail calls instead pop the invoking Lua frame and close its upvalues before finishing: outside the recommended shortcut. |
| `finish`: `calls.wf:77–134` | Calls `move_results` again to truncate/pad to wanted. With positive wanted this can self-copy returned values; with wanted=0 it has no value-copy iterations, but still does setup. Completes matching protected pcall frames, detects empty/different-activation callers, reads caller base/kbase, restores frame_top for fixed results or leaves top past dynamic results, and returns Step. PUC `ldo.c:343–360` also adjusts result count, nil-pads and restores caller state, but moves directly from original C results once; Halo's protected-frame/activation handling is extra work. |
| Dispatch continuation: `handlers.wf:3357–3371`, `dispatch.wf:454–478`, `calls.wf:979–1001` | Errors unwind; ordinary success becomes Jump. `checked_step` rechecks the two 256-slot windows, their overflow bounds, and next pc, constructs a Cursor, then resumes. PUC's successful C-call branch restores top/base and continues; it has no Halo Step/Cursor/window-contract boundary. |

`enter_lua` (`calls.wf:213–319`) validates a Lua closure, handles tail/vararg
layout, ensures its register window, nil-fills and pushes a Frame. None of
that belongs to native assert. Likewise `instruction_return`
(`handlers.wf:3434–3464`) closes/pops a **Lua** frame and calls `finish`;
it is not how native assert returns. R8's Lua nil-fill and Frame-copy
observations must not be counted as native-call opportunities.

### Failure and boundary behavior

No arguments: `library-base.wf:61–62` uses `lib_argtext`
(`library.wf:1126–1133`) for the call-derived bad-argument prefix and
"value expected". False/nil argument: lines 69–81 coerce a numeric message
to text (`state.wf:533–543`), use "assertion failed!" for absent/nil message,
reject a nonstring/nonnumber message through `lib_argerror`, or raise the
message. Success does not examine or validate the message's type.

After the wrappers restore length, `prepare_inner` runs
`library_call_error_location` exactly once for Raised
(`calls.wf:473–476`). `library-dispatch.wf:142–153` consumes the native-error
mark and distinguishes immediate Lua from native callers; the ordinary
location step is at lines 70–121. `instruction_call` then unwinds.
The existing failure path is retained in both proposals.

## Two proposals, ranked by expected saving relative to risk

### 1. Complete successful ordinary assert in native preparation

**Scope.** After native resolution and the existing active-codec assignment
at `calls.wf:397`, recognize ID 8, a non-tail call and a nonzero argc.
Read argument 0 and, only if truthy, run the existing full argument
compaction, preserve suspension/stop precedence, and call existing `finish`.
Everything else falls through to the existing path. This works for aliases
and a resolved `__call` handler too; no script or benchmark is recognized.

**Code shape** (insertion fragment, not compiled code):

```wf
if bound_id_1 == builtin_assert {
  if bnot(tailing) {
    if nargs > 0_u64 {
      let first = argument(stack: stack, func: fslot, argc: nargs, index: 0_u64);
      if truthy(v: first) {
        let source = fslot +sat 1_u64;
        let count = adjust_results(vm: vm, stack: stack, dest: fslot,
                                   src: source, count: nargs, wanted: -1_i64);
        if vm^.suspended { return Step::Budget(); }
        if vm^.host_stopped { return Step::Stop(); }
        return finish(vm: vm, stack: stack, dest: fslot, wanted: nr,
                      return_pc: return_pc, src: fslot, count: count);
      }
    }
  }
}
```

This removes the successful call's remaining native result-room and
callback classifications, host/library routing, base-library prologue and
both length restorations. It retains both result helper calls deliberately.
The generic assert body remains authoritative for errors and tail calls.
No public host outcome or module interface changes.

**Prediction and risk.** First choice because the hot path can bypass
substantial routing while sharing all return semantics, and its new
recognition condition is easy to inspect. Estimated saving: 100–200 Ir per
ordinary successful call, with low confidence in the numerical range.
The 141 attributed to library_base is not all removable because compaction
survives, and the 181 preparation figure is not a set of measured source
subtotals. Code layout/inlining could erase the gain or affect other native
functions. This is a moderate performance/design risk, with deliberately
narrow semantic scope. It moves the reported 530 toward roughly 330–430,
not a demonstrated 170–220.

**Behavior to preserve.** The Call/TailCall budget charge and collection
predicate stay in their existing positions; `prepare` still reconciles
coroutine storage after this return. Full compaction and `finish` keep the
same stack contents, top, protected-call completion and activation exit.
Every failure, argument name, message conversion and location stays in the
old path. Tail calls stay there too, retaining their caller for errors.
No new nested activation is entered: the callback checks at
`slow.wf:218–225` still refuse the activation/logical-depth boundary of 200.
Calling assert *inside* a callback does not erase that callback's level.

**Why not fuse the result moves yet?** Replacing both calls with
`finish(src: fslot+1, count: nargs, wanted: nr)` looks like PUC, but changes
unrequested argument slots. Halo marks up to max(dynamic top, all frame
tops), capped at stack length (`heap/gc.wf:180–206,226–231`); a safepoint
clears slots above that limit (`vm/collect.wf:84–99`). An open-argument
call such as `assert(true, f())`, with f returning several allocated values,
can have arguments above the static frame top. The old compaction moves
one of them below that cutoff even when results are discarded. Omitting
it can change which object survives, hence live-byte accounting and later
collection timing. This is a source-derived risk, not an executed witness.
Keep compaction rather than silently change that behavior.

Minimal Lua shape to investigate in CI:

```lua
local function f()
  return {}, string.rep("x", 10000), {}
end
assert(true, f())
assert(true)
```

The compiler leaves the last argument call open
(`compile/expr.wf:161–162,175–188`), while static maxstack follows reserved
registers (`compile/code.wf:172–186`). This supports the cutoff concern;
the exact emitted registers and retained-byte difference still need
verification. This is a diagnostic candidate, not a passing regression test.

**Design impact: yes, an added decision.** The existing owning node is
`design/halo/calls.md:1`:

> Decision: Lua-to-Lua calls, `__call`, `pcall`, `error` and host calls use the VM's own value stack and frame records, never the machine stack, while Lua code that the slow executor or a library function calls back (a `table.sort` comparator, `__tostring`, metamethods reached from the slow path) runs as a nested activation refused with "C stack overflow" at PUC's limit of 200, because script call depth then costs no machine stack and a script that reaches the callback limit gets Redis's error ([VM design, calls](../../research/investigations/halo/VM.md#3-calls)), instead of recursing on the machine stack for every Lua call. The machine stack that 200 nested activations use is unmeasured; this is provisional until it is (VM design, open ruling H2).

That rule remains unchanged. It does not decide whether preparation owns a
specialized library-success path. Choosing that ownership over uniform
library dispatch is a new material performance/structural choice, so it
needs an addition, not a claim that the old node already approves it.
Proposed line for that node (proposal only):

> Decision: Provisionally, a successful non-tail call to the resolved assert builtin completes in native call preparation using the existing full argument compaction and return machinery, while failures and tail calls retain library dispatch, because this nonallocating success path needs neither callback setup nor library routing and preserving compaction retains the same stack roots, instead of routing every successful assert through the general native-library dispatcher; retain this specialization only if Towers loses at least 2.5% of callgrind instructions and passes the 14900K timing, regression and gate criteria recorded before measurement.

The calls descendants (return-upvalue bound and coroutines), dispatch
continuations, budget, heap safepoints and operand-error decisions remain
intact. The shortcut still returns Step through the shared checked exit.

### 2. Remove the redundant outer length restoration; delay unused assert arguments

**Code shape.** In `builtins.wf:285–288`, return the outcome of
`library_dispatch` without the subsequent resize: its existing contract at
`library-dispatch.wf:12` already guarantees exactly the saved length.
In `library_base`, put the assert branch before the common a/b/c loads,
read only argument 0 before its success test, and read argument 1 only on
failure; other base functions retain their original reads. Keep the full
compaction and `finish`, as in proposal 1. Preserve the original error
body; this is not an opportunity to change coercion or error text.

**Prediction and risk.** Lower implementation risk, but much smaller
potential: approximately 10–40 Ir per successful assert (5–20M, about
0.14–0.56% of historical Towers Ir), inferred and possibly near zero if
LTO has already sunk the reads/eliminated the outer resize. It leaves all
preparation and library classification. It is ranked second because its
upside cannot plausibly meet the requested 2.5% whole-Towers falsifier by
itself. Its saving overlaps proposal 1 and must not be added to it.

**Behavior and design.** No design decision changes: neither public
interfaces, routing policy, result representation nor accepted behavior
changes. Error text/location, budget, collection points/root contents,
coroutine accounting and callback depth of 200 remain on the same paths.
The outer resize is provably redundant, not the collector's separately
approved swap-fact workaround (`collect.wf:55–61`), which stays untouched.
If the compiler cannot prove the existing contract without this redundant
call, stop with that minimal witness; do not add a runtime check.

## Validation to run only after a decision

No RESULTS.md section is appended because phase 2 was not entered. The
future experiment must record these conditions before measuring:

* Question: does skipping native-success routing remove enough instructions
  to produce a real Towers speedup without changing replies or execution
  control? Expected saving for proposal 1: approximately 49–98M Ir on
  the historical workload, uncertain and narrower than the original R7
  100–130M estimate.
* Falsifier: full-LTO Towers callgrind Ir must fall **at least 2.5%** against
  a fresh same-source base comparison; otherwise **no timing**. The
  historical baseline implies about 89.6M Ir must be removed, approximately
  182 Ir per call at the rounded 491K count. Keep profile binaries or
  disassembly so attribution can be checked.
* Keep rule: on the 14900K through CI, CPU 2, full LTO, **six interleaved
  pairs**, with a **byte-copy twin of the base**. Towers must be **at least
  3% faster**, beyond both ranges and the twin's difference; no other
  halo-bench kernel or are-we-fast-yet bundle may be slower beyond its
  larger range plus the twin's difference; gate green.
* Correctness: existing assert oracle (`lua-core/assert.lua`) covers returned
  arguments and a chosen error message but not every boundary. Check no
  arguments, false/nil with default/numeric/invalid messages, success with
  arbitrary extra arguments, zero/fixed/all/nil-padded results, aliases,
  __call, pcall/xpcall, tail calls, coroutine and callback contexts. Use the
  reference oracle at budgets 1, 7 and 1000, normally and with collection
  stress, plus the existing callback-depth and host suspension checks.
  Inspect the proposed shortcut's stack/top equivalence at each exit.

## Whitefoot suspects and unresolved facts

These are **inferred code-generation causes**, not compiler failures found
by this task:

1. Aggregate Step/HostOutcome/FuncView/Result boundaries may materialize
   temporaries and copies or prevent propagation of known tags and window
   facts. The supplied report calls Step's memory return already known
   (Whitefoot #408); this task has not inspected its generated code.
2. Broad generic dispatch and write effects may keep eager argument loads,
   stack-header reloads and redundant equal-length restorations alive after
   full LTO. The source has them; only disassembly can show which survive.
3. Result movers contain length clamps, tagged-value copies and top updates.
   Their machine instruction cost and inlining into library_base are
   unknown. R8's 23-Ir Lua nil-fill loop is not evidence about this native
   path.

Possible minimal diagnostic shapes, **not reproduced limitations**: a
length-preserving callee followed by a resize to the old length (does code
remain?); a function that reads three bounded arguments but returns after
testing only the first (are other reads sunk?); a Step carrying unchanged,
already-proven base/kbase followed by checked_step (are windows rechecked?).
Any actual rejected natural form must become a semantic witness and a
Whitefoot request before considering another spelling.

No Whitefoot limitation was hit: no compilation was attempted. No pin or
submodule moved, and no Whitefoot gap was filed. Oracle comparison, gate,
instruction saving and timing remain unverified. The exact 530 boundary,
surviving resize count and numerical benefit need new profile evidence.

The wf-board MCP and session-title tools are not available in this session;
no board update was made. This file carries the findings and stop reason.

## Completion review

A fresh read-only `gpt-6.1-sol` reviewer checked the complete analysis above,
its cited Halo and PUC source, the project checklist and relevant design
nodes against Halo base/HEAD
`8ee6634fa608ddb13aa8272b51c0a2a696fa22e3`. No findings within that scope.
C1–C2, G1–G3 and DC1–DC2 passed for the analysis/proposal correspondence;
C3–C5 and DC3 were not applicable to unchanged interfaces, gates, pins and
implementation. DC4 remains unverified: there is no implementation,
compilation, oracle/gate run or new performance evidence. The review used
only file reads/searches, git inspection and a document checksum. This
review record was appended afterward; it is not an owner approval.
