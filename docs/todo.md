# Known defects and follow-up work

Items the work has found and not yet done, each with its impact, the change
that would address it and when to reopen it ([AGENTS.md](../AGENTS.md#how-work-proceeds),
"Fix or record what you notice"). Remove an item in the change that resolves
it.

## Whitefoot requirements

Gaps Halo needs Whitefoot to close, each stated as its minimal semantic
example apart from the engine code that exposed it
([AGENTS.md](../AGENTS.md#the-whitefoot-boundary)).

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

- **The gate runs the oracle corpus only.** `make check` builds the
  end-to-end test program and compares the 80 oracle scripts at budgets 1,
  7 and 1000 in ordinary and collector-stress modes. Not in the gate: the
  JSON and MessagePack comparisons (`research/experiments/json`,
  `research/experiments/msgpack`, the latter needing its C reference), the
  number library's checks (`lib/halo/number/tests`), the runner's error,
  SHA-1 and memory probes (`--verify-errors`, `--verify-sha1`,
  `--verify-memory`) and the removed-root controls of
  `research/experiments/halo-gc`, which must fail. Its fixtures and runner
  also still live under `research/`. Impact: a regression in those paths
  passes the gate. Change: wire each into `make check` with a control that
  shows it detects a wrong result, and move the gate's fixtures and runner
  to `tests/`. Reopen at the next gate change.

- **Halo iterator and CJSON closure routing share a sentinel.** Both
  `library-pattern-api.wf::pattern_is_iterator` and
  `library-cjson.wf::cjson_binding` select proto `no_handle`, while
  `calls.wf::prepare` changes the view to a pattern builtin first.
  Impact: a CJSON method closure can enter iterator handling before its native
  binding is decoded. Change: distinguish these native closure payloads and
  test extracted CJSON methods alongside gmatch iterators with independent
  Lua replies. Reopen before changing native closure routing; the bounded
  call-entry trial leaves sentinel paths unchanged. This source overlap
  needs a minimal executable witness before selecting the repair.

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

- **Halo codec error names need Lua debug metadata.** The library comparison
  in `research/experiments/halo-luacodecs/RESULTS.md` includes
  `local f=bit.tobit; return f(false)` and operations on `cjson.null`.
  Halo reports the builtin's static name or a generic userdata error;
  Redis reports the local or field name. `pkg::value::Script` carries lines
  but no local-name ranges. Impact: alias and field-call error text differs
  from Redis. Change: preserve the compiler's local names and
  Lua's register-origin information, then use them in argument and type
  errors. Validate alias, field, upvalue and unnamed calls against Redis.
  Reopen before claiming byte-exact Lua library error compatibility.

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
  Change: repeat fixed Lua entry with explicit sentinel exclusion, preserving
  every native/invalid/vararg fallback; establish that exclusion independent
  of the prototype count and repeat the full runtime, check-time, oracle and
  removed-root criterion. Frame/result transport and residual table copying
  remain separate attribution targets. Compare these, the VM.md candidates
  and library/heap paths with same-source,
  full-LTO pairs, preserving checksums, normal GC, roots and handle validity.
  Reopen at the next performance experiment; require a discriminating native
  comparison before selecting a candidate or claiming a causal speedup.

- **Halo's oracle hides next/pairs hash iteration order.**
  `research/experiments/halo-oracle/scripts/lua-core/next-pairs.lua` sorts both
  observations; passing the 240 comparison rows proves contents, not order.
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

- **Halo's number library and oracle corpus were checked on macOS only.**
  `lib/halo/number` matches Redis 7.0.15's bundled Lua built on macOS
  (research/experiments/halo-number), except that NaN text now follows glibc
  (`-nan` for a negative NaN), the Linux reference firn uses, as does
  `string.format`'s NaN text in `lib/halo/vm`; its `strtod`
  details (NaN payloads, hexadecimal forms, range errors) and the oracle
  corpus (research/experiments/halo-oracle) were produced against macOS
  builds. Impact: Linux formatting and parsing parity remains unverified.
  Change: rerun both comparisons on the x86-64 Linux runner against a glibc
  build of Redis 7.0.15 and its Lua, and adopt glibc's behavior wherever they
  differ. Reopen before Halo's first release or when firn's EVAL lands.

- **Reconcile the Halo embedding boundary record with current work.**
  `research/experiments/halo-e2e/GAPS.md` presents the first comparison's
  retired file-permission boundary as a current constraint ("this task
  permits no changes to the VM or project TODO"), while the current F4
  experiment changes both. Impact: readers can confuse an old editing
  restriction with a technical limitation. Change: remove historical task
  scope narration and retain the reproducing semantic witnesses and actual
  boundaries. Reopen when that boundary record is next updated, before
  using it as current integration guidance; verify its witnesses against
  the then-current compiler and Halo revision.

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
