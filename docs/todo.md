# Known defects and follow-up work

Items the work has found and not yet done, each with its impact, the change
that would address it and when to reopen it, as the owner-wide instructions
ask. Remove an item in the change that resolves it.

## Whitefoot requirements

Gaps Halo needs Whitefoot to close, each stated as its minimal semantic
example apart from the engine code that exposed it
([Whitefoot-kit](../whitefoot-kit/downstream.md#trying-an-unmerged-whitefoot-change)).

- **A loop invariant is lost where a guarded update joins an untouched
  path.** A loop whose body sets a variable from a guarded value on one path
  and leaves it on another, then joins the two before the back edge, loses
  the header invariant both paths re-prove, because the join keeps only
  facts identical on both inputs (`INV-1 UndischargedLoopInvariant`,
  obligation `Backedge`). Impact: Halo's dispatch loop is written as a
  self-tail call rather than `loop { match }`, whose arms update different
  loop variables. The minimal witness and the candidate repairs are in
  Whitefoot's `docs/todo.md` (Ming-Research/Whitefoot#246). Reopen when
  Whitefoot changes INV-1's join.

- **Checking Halo's vm package is on the build's critical path.** Whitefoot's
  [compile-speed investigation](https://github.com/Ming-Research/Whitefoot/blob/main/research/investigations/compile-speed/DESIGN.md#remaining-costs)
  brought `pkg::vm`'s module check to 16.6–17.2 s and records the remaining
  costs on Halo's critical path, symbolic validation above all. Reopen when
  Halo's edit-check loop or the gate's build becomes the bottleneck.

- **A graph path's spelling changes the compiler's cache key.** The same
  graph named by a relative and by an absolute path misses the other's
  cache entry and repeats front-end work; keep graph spellings consistent
  in runners and the Makefile until Whitefoot separates input identity from
  display paths (its `docs/todo.md`, Ming-Research/Whitefoot#246).

- **Halo's instruction cells and one handler copy more than needed.** The
  12-byte `Cell` (an `i32` enum tag) and an unattributed operand copy in
  `run`'s `AddRR` arm are lowering findings handed to Whitefoot's
  match-dispatch work (Ming-Research/Whitefoot#237). The Halo-side layout
  question is the Cell stride entry under *Engine*.

## Engine

- **The gate's fixtures and runners still live under `research/`.**
  Impact: maintained regression checks share a home with experiments, so
  their location does not distinguish gate dependencies from research
  tooling. Change: move the gate's fixtures and runners to `tests/` and
  update their callers and references. Reopen at the next gate change.

- **Argument errors hardcode the called function's name.** Lua 5.1's
  `luaL_argerror` uses `getfuncname` (`getobjname` at the caller's CALL
  register), so `bad argument #N to 'NAME'` names a local alias or a field,
  and for a method it subtracts the implicit self argument and reports a bad
  self as `calling 'NAME' on bad self`. Halo's builtins hardcode their names,
  for example `bad argument #1 to 'select'` in `lib/halo/vm/builtins.wf`.
  Witness: `local f=bit.tobit; return f(false)` gives Redis 7.0.15's
  `bad argument #1 to 'f' (number expected, got boolean)` and Halo's
  `... to 'tobit' ...` (`research/experiments/halo-luacodecs/RESULTS.md`,
  case cjson/222). Impact: aliases, field calls and methods can disagree in
  both name and argument number. Change: route argument errors through the
  operand description at the caller's call cell and apply `luaL_argerror`'s
  method adjustment. Validate with recorded oracle replies for local aliases,
  fields, methods and bad self. Reopen before clients compare argument-error
  text.

- **pcall's error field is read raw.** With an error field named
  (`set_pcall_error_field`), `pcall` reads it with a raw lookup; Redis's
  replacement `pcall` uses `lua_getfield`, which also consults the table's
  `__index`. Witness: `pcall(error, setmetatable({}, {__index={err="E"}}))`
  returns the string `E` in Redis and the table in Halo (by reading
  `script_lua.c`, not recorded). Impact: only an error table whose field
  comes from a metatable differs. Change: run the lookup through the VM's
  metamethod-aware get, which may call Lua during unwinding. Reopen when a
  script raises such a table, with a recorded oracle case.

- **A closure kept from one script cannot be called while another runs.**
  `start` in `lib/halo/vm/calls.wf` replaces the VM's prototypes and line
  metadata with the started script's, and a Lua closure finds its
  prototype by index in that current table. A closure the host pins (or a
  value holding one) from script A, called while script B runs, executes
  B's prototype at that index. Witness: pin the result of
  `return function() return 42 end` from one cached script, start another
  script, and call the pinned value. Impact: a host may keep only data, not
  Lua closures, across scripts; Redis's own reply conversion turns a
  returned function into nil, so the oracle corpus cannot reach this. Change:
  give each cached script's prototypes an engine-wide identity, appended
  rather than replaced, so a closure keeps its code across starts and
  flushes invalidate it explicitly. Validate with the witness and a flushed
  script's closure. Reopen when a host needs to keep or call a closure
  across scripts.

- **Halo F4 has no every-allocation reachability verifier.**
  The safepoint stress and four missing-root mutations in
  `research/experiments/halo-gc/RESULTS.md` distinguish selected root
  omissions, but do not check every heap reference or collect at every
  allocation as VM.md's original F4 requires. Impact: passing these cases
  cannot establish complete collector reachability or bound temporary
  allocation between safepoints. Change: add an independent test-build
  handle/reachability check and establish temporary-root handling before
  extending stress to allocation boundaries. Reopen at the next F4 extension
  or before claiming every-allocation validation; verify omitted-reference
  controls and allocating helpers with live temporary values.

- **Halo retains cjson instance configurations after collection.**
  `Vm.cjson_configs` owns settings and reusable encoding buffers; native
  closures select an instance, but collecting its last closure does not
  release that configuration. Impact: repeated `cjson.new()` retains
  configuration slots and buffers for the VM's lifetime. Change: connect
  instance lifetime to reachable native closures and reclaim unreachable
  buffers and slots. Validate retained extracted methods, discarded tables
  and repeated new/encode/collect cycles. Reopen before long-lived Halo VMs
  use independent cjson instances.

- **Halo's measured hot paths exceed the P1 median target.** The source
  `lib/halo/vm/dispatch.wf` retains joined `Step` continuations on cold and
  frame-changing paths; C1's 18 selected hot arms now tail-call directly.
  The full-LTO native baseline already had per-arm functions and indirect
  tail jumps; a single native dispatch point was not the measured cause ([P1 results](../research/experiments/halo-bench/RESULTS.md#value-width-handles-and-native-dispatch-inspected-first)).
  Impact: the initial six unscaled workloads measured 1.964–4.081 times PUC;
  depth-14 binary-trees measured 1.910 times. The
  [repair rerun](../research/experiments/halo-bench/RESULTS.md#p1-rerun-after-the-retained-changes)
  still misses P1 after removing repeated resume copying and guarding the
  collector call on the not-due path. Numeric profiles expose dispatch/continuation
  traffic, tag tests, repeated window tests and safepoint predicate work;
  table rehash, concat and sorting have separate substantial costs. Fresh
  [C1 profiles](../research/experiments/halo-bench/RESULTS.md#profile-selection-and-frame-window-criterion)
  place 54.01–58.62% of fib(34) samples in frame helpers and 31.12–32.31% of
  integer-table samples in rehash. The bounded frame-window clearing trial
  improves fib only 2.99%, below its 10% criterion; it does not rule out
  other frame changes or establish C2/C3 performance. The
  [bounded table-growth change](../research/experiments/halo-bench/RESULTS.md#six-pair-table-growth-result)
  removes per-array-key histogram walks, repeated Nil initialization and
  retained-prefix reinsertion, improving integer-table by 25.70% on the
  measured host. Fresh prefix allocation/copying and checked handle/bounds
  work remain; their isolated costs are unmeasured. The
  [frame inspection](../research/experiments/halo-bench/RESULTS.md#fib-frame-input-for-the-next-experiment)
  points to metadata checks, native call storage and 80-byte frame/result
  transport; sampled offsets do not isolate cycle shares. The
  [bounded call-entry trial](../research/experiments/halo-bench/RESULTS.md#sentinel-qualification-defect-found-before-selection)
  improves fib by 19.47% but is reverted because prototype bounds alone do not
  preserve explicit native-sentinel routing for the public prototype window.
  The [sentinel-qualified repeat on the 14900K](../research/experiments/halo-bench/RESULTS.md#14900k-repeat-with-wf-e1708490c384)
  failed its criterion with `wf-e1708490c384` and clang 22: fib improved only
  1.7% against the required 10%, and sort regressed beyond the recorded
  noise limit. It was reverted in `46cad3c17`; the module-check limit passed,
  and the earlier oracle and removed-root gates passed.
  Change: investigate frame/result transport and residual table copying as
  separate attribution targets. Compare these, the VM.md candidates
  and library/heap paths with same-source,
  full-LTO pairs, preserving checksums, normal GC, roots and handle validity.
  Reopen at the next performance experiment; require a discriminating native
  comparison before selecting a candidate or claiming a causal speedup.

- **A slow-executor call inside a hot library function may slow its fast
  path.** Moving `sort_compare`'s call to `slow` into its own function made
  the sort kernel 25% faster on the 14900K in a same-source, twinned pair
  ([seventh run](../research/experiments/halo-bench/RESULTS.md#seventh-run-the-splits-share-and-the-heads-check-time));
  why is not established, and other library functions that call `slow` or
  callbacks beside a fast path (string comparison and pattern matching,
  `table.concat`, the codecs) were not examined. Change: inspect the
  compiled code of `sort_compare` before and after to name the cause, then
  apply the split where the same pattern holds, each with a same-source
  pair. Reopen at the next performance experiment.

- **Halo's dispatch arms take the next pc from their helpers.** In
  `lib/halo/vm/dispatch.wf`, an arm receives `next` from its instruction
  helper (for example `instruction_move` returning `Ok(next)`), so
  Whitefoot's code cursor (from release `wf-0b7f5c5b9854`) cannot see that
  `next` is `pc + 1` and forms the code address from the index as before. The
  stage-3 wasm interpreter computes `let next = pc + 1_u64` in the arm and
  tail-calls with it, which the cursor turns into one addition per dispatch;
  the wf session reported about 13% on CoreMark on x86-64 there (not
  measured on Halo). Change: after Halo moves to a release with the cursor,
  compute the constant-step `next` in the hot arms and keep helpers for the
  operation itself, measured as a same-source pair. Reopen after that pin
  move.

- **Halo's oracle hides next/pairs hash iteration order.**
  `research/experiments/halo-oracle/scripts/lua-core/next-pairs.lua` sorts both
  observations; passing the oracle comparison proves contents, not order.
  Impact: a table-layout change can pass while diverging from the selected
  Redis Lua order. Change: add an independent unsorted table-growth and
  iteration observation in the oracle's existing home, with recorded Redis
  expected bytes and unchanged existing cases. Reopen at the next oracle
  coverage update; validate that an order-only permutation fails comparison.
  The [bounded growth experiment](../research/experiments/halo-bench/RESULTS.md#iteration-order-evidence-correction)
  uses scratch unsorted PUC comparisons to qualify its own change.

- **Halo reused-binary reports identify current inputs, not build inputs.**
  `research/experiments/halo-e2e/run.py --binary` hashes the current library
  and harness source even when the supplied executable was built from other
  bytes. Impact: the printed source digest can be mistaken for the binary's
  provenance; the fixed-call repeat uses separately retained source and
  executable hashes for its before build. Change: accept and verify an
  explicit build-input manifest for reused binaries, and label current
  fixture/runner inputs separately. Reopen at the next reused-binary
  experiment; validate that a mismatched source/binary manifest fails and
  that current fixture changes remain identified independently.

- **Halo's C1 fast variants repeat operation logic in full handlers.**
  Callback-free variants make next-pc summaries available outside the VM's
  recursive callback component, but the corresponding full handlers retain
  their original numeric/table fast paths. Impact: later instruction edits
  could make hot and cold behavior diverge; fast misses also repeat operand
  views or table lookup. Change: give both paths one operation owner, with
  explicit cold execution after a fast miss, preserving errors, suspension
  and window proofs. Validate the oracle and fresh same-source full-LTO pairs:
  changing cold code can also change native placement. Reopen when an affected
  instruction changes or the next VM performance experiment compares that
  factoring; C1's measured source stays fixed for this bounded experiment.

- **The Halo embedding boundary record's witnesses are unchecked against
  the current revision.** `research/experiments/halo-e2e/GAPS.md` records
  the integration gaps of the first comparison; its scope narration is
  gone, but its witnesses were written against an older compiler and Halo.
  Impact: a gap it lists may be closed, or one it omits may exist. Change:
  rerun each witness against the current compiler and Halo revision and
  keep only the boundaries that still hold. Reopen before using it as
  current integration guidance.

- **Halo's instruction Cell stride differs from the proposed eight bytes.**
  The [P1 native inspection](../research/experiments/halo-bench/RESULTS.md#value-width-handles-and-native-dispatch-inspected-first)
  observes a 12-byte Cell stride and operand offsets 4/5/6/8, while VM.md
  section 4 proposes eight bytes. Both Halo and PUC value slots are 16 bytes;
  PUC's instruction fetch is four bytes. Impact: the proposed instruction
  density is not implemented, and its throughput effect remains unmeasured.
  Change: reconcile the intended Cell layout with native enum emission and
  compare representation alternatives under C6, preserving operands, tags,
  targets and all verified access conditions. Reopen with the next layout or
  dispatch experiment; require native size/offset evidence and a matched
  throughput comparison before claiming an improvement.
