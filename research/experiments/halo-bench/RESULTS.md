# Halo P1 baseline — 2026-10-05

The initial P1 baseline below fails on all six unscaled workloads and on
the scaled binary-trees workload. Every timed pair has matching checksums.
At baseline no performance candidate was implemented or selected; no compiler,
Halo library, specification or conformance file changed. The later Halo cost
repair records its criteria and comparisons separately below.

## Environment and identity

Apple M1 Pro, 32 GiB RAM, macOS 26.6.2 (25G83), native ARM64. The reference
is the supplied Redis 7.0.15 Lua interpreter; `lua -v` confirms Lua 5.1.5.
No network or Cargo command was used. All work and generated outputs stayed
in this worktree, apart from the existing host-wide check lock.

The existing `compiler/target/gate/whitefootc` compiled `modules.wfg`, entry
`bench`, with `--full-lto`, without a compiler cache. Build exit 0; wrapper
wall 478.87 s (tool wall 478.77 s, user 374.60 s, system 50.34 s). The
compiler was still active at 4:33; no linker was then active. Another
compiler process was observed during construction, so this single build
is not a clean compiler-cost measurement. Before timing, a process listing
found no compiler, clang or Cargo process. The measurement session held the
host-wide lock; background OS activity was not eliminated.

The native host and library source are reproduced by commit
`5d2ab819af3b822f5f051efbc657632c40dbbe82`. Launch records name the then-current
HEAD, usually `2e6152e4d95861c87c4cbb7c2e46277584e0662a`, while the host's
working changes were not yet committed. Their host-source hashes match
that later commit and the delivered host. The library/compiler sources
were unchanged from the task base
`75c9d7b48ae29642a36c078edd00b0048f0a2fd3`; binary hashes, rather than an
assumption about how the supplied compiler was built, identify the tools:

- Native Halo: `fe06a41d7a4955132abc0426b2b613e95abf51c9468757efc8e5328c8965e5fd`.
- Compiler: `c71614ecb1da4ab8b5c4cfea7bec7afa3a39aeb967657e1aaa2019c76dbf3fc5`.
- PUC: `dd2f2bb469b8c423292e23a5ab0dea2c4f3ea23658b76d55cd5f296d5d94e91e`.

[measurements.json](measurements.json) retains all calibration, baseline,
budget and profiler launch observations, exits, checksums, hashes, scales,
spread and profile counts. Machine-local paths use role placeholders.
[profiles.txt](profiles.txt) retains sample metadata, complete call graphs
and collapsed leaf counts for the 22 primary profiles and three short
controls, excluding system-image inventories. The excerpt hashes describe
the retained, redacted bytes. These evidence files serve baseline and
attribution reproduction and remain until superseded without that need.

## Sizing and checksum evidence

Fib was launched once, then in three alternating pairs. Its first cold Halo
launch was 0.454588 s versus a three-pair median of 0.223491 s; the first
launch is calibration, not a baseline datum. Fib's three-pair relative
ranges were PUC 0.16%, Halo 2.95%. Each other kernel received one PUC sizing
launch, one paired correctness/timing launch and three alternating pairs
before choosing six pairs. Calibration relative ranges (PUC / Halo) were:
loop 3.52% / 1.41%; integer-table 0.23% / 2.08%; string-key 5.68% / 4.26%;
concat 1.03% / 2.52%; sort 1.66% / 2.08%; binary-trees depth 14
1.12% / 0.78%. Six pairs suffice to distinguish both 1.0 and 1.5; even the
largest final PUC range, 9.21% on the short string-key launch, cannot move
its ratio near either threshold. No baseline repetitions were discarded.

PUC at binary-trees depth 16 took 6.083905 s, so depth was reduced to 14;
one PUC launch at 14 took 1.270769 s. All other counts are P1's counts.
The tree workload includes stretch, retained and paired temporary trees.
The depth-14 result does not establish Halo's time at depth 16.

The equal outputs in every baseline pair are:

| Kernel | Checksum | Completed Halo collections per launch |
|---|---|---:|
| fib | `832040` | 0 |
| loop | `5.00000005e+15` | 0 |
| integer-table | `50000005000000` | 5 |
| string-key | `28500000` | 0 |
| concat | `5000000` | 0 |
| sort | `1.0733795172001e+15` | 3 |
| binary-trees depth 14 | `-43682` | 176 |

Sort also asserts nondecreasing order. The comparison checks exact printed
bytes, not hidden VM results; six injected wrong/missing/extra checksum,
unexpected-suspension and malformed-stat controls were rejected. Profiles
add missing, zero and ambiguous-worker controls; the genuinely empty
string-key sample is also rejected by the repaired validator. Both VMs
use their ordinary collectors; Halo stress mode is off and its logical
live-heap limit is 2 GiB. The four-key string and concat fixtures exercise
repeated present-key lookup and interned short results, not unique-string
growth or a broad table-key distribution.

## Baseline medians

Wall time is process launch through exit, including source loading,
compilation, initialization, execution and teardown. Both VMs read identical
stdin source bytes. Launch order alternates PUC/Halo then Halo/PUC. Spread
below is min–max; relative ranges are retained in the JSON. Every native
and PUC launch exits 0. Every large-budget launch has zero suspensions.

| Kernel (count) | PUC median s | Halo median s | Halo / PUC | PUC min–max s | Halo min–max s | Pairs |
|---|---:|---:|---:|---|---|---:|
| fib (30) | 0.077791 | 0.223039 | 2.867 | 0.077257–0.079849 | 0.221508–0.226294 | 6 |
| loop (100,000,000) | 0.460990 | 1.363583 | 2.958 | 0.460242–0.466331 | 1.354988–1.390903 | 6 |
| integer-table (10,000,000 fill + read) | 0.201466 | 0.822095 | 4.081 | 0.199138–0.203031 | 0.812461–0.837778 | 6 |
| string-key (1,000,000) | 0.026168 | 0.057557 | 2.200 | 0.025944–0.028356 | 0.056842–0.058564 | 6 |
| concat (1,000,000) | 0.055690 | 0.208976 | 3.752 | 0.055315–0.057728 | 0.202937–0.211831 | 6 |
| sort (1,000,000) | 0.379271 | 0.744996 | 1.964 | 0.377892–0.380363 | 0.742024–0.753705 | 6 |
| binary-trees (depth 14) | 1.278944 | 2.442658 | 1.910 | 1.274211–1.283148 | 2.438182–2.448181 | 6 |

## Budget 1000

Budget 2^64−1 is Halo's unlimited sentinel: it skips decrementing. Budget
1000 is the corpus default. One run and a three-pair spread check preceded
six selected pairs; the three-run Halo relative range was 1.02%.

| Mode | PUC median s | Halo median s | Halo min–max s | Suspensions | Collections | Pairs |
|---|---:|---:|---|---:|---:|---:|
| Unlimited | 0.460990 | 1.363583 | 1.354988–1.390903 | 0 | 0 | 6 |
| 1000 | 0.460766 | 3.043277 | 3.031091–3.071511 | 100000 | 0 | 6 |

The budget-1000 Halo median is 2.232× unlimited (+123.18%, +1.679694 s).
This is total decrement plus suspension/resume overhead in this embedding,
not an isolated counter-cost measurement or a real Redis end-to-end run.
The two modes were measured in separate batches, each interleaved with PUC;
PUC medians stayed within 0.05%. The large difference is resolved, but these
runs do not determine a sub-1% cost as P3 ultimately requires; measured total resume cost here exceeds its target.

One profiled budget-1000 run has 2355 worker samples: 1267 (53.8%) in
`embed.refresh_roots` or its descendants, including 689 in memmove/stub
copying, 248 in free descendants and 196 in allocation descendants; 912
(38.7%) in dispatch arms and 163 (6.9%) in the GC safepoint path. It
completed zero collections and 100000 suspensions. The source
`embed/engine.wf::refresh_roots` rebuilds the constant/pin bridge on each
resume, and `append_value` reserves one additional slot when full. The
measured attribution is repeated bridge copying/allocation, not collection
or a guess that arithmetic decrements alone explain the cost. A same-source
control would be needed to measure the gain from changing that mechanism.

## Attribution of ratios above 1.5

`/usr/bin/sample PID 10 1 -file REPORT` sampled at a requested 1 ms interval
until the process exited. The first sandboxed attempt returned 255 and no
report (runner exit 1); it is retained as a failed attempt. Local
process-inspection access then worked without network. An original
string-key launch returned profiler exit 0 but had an empty call graph;
the runner now refuses that condition. Fib(30) and concat at 1e6 captured
only 98 and 82 worker samples, so attribution alone lengthened fib to 34,
string-key to 20,000,000, and concat to 10,000,000. Baseline timings above
remain at the requested counts. Each extended workload was first run once.
A one/three-loop profiler calibration found a 2.88% Halo range; three
profiles per workload provided stable broad work categories. The extended
three-run Halo ranges were 0.98%, 3.69% and 3.25%, respectively. Primary
profile timings are excluded from baseline medians.

Counts use the execution worker under `wf__main_body`; the main thread's
matching `__ulock_wait` samples are excluded. For each call-graph node,
exclusive count is its count minus immediate children's counts. The
exclusive counts sum to that worker's total in each of the 22 profiles.
Groups give GC/safepoint and root-refresh ancestors priority, then sorting,
concat/intern, Lua frame helpers, slow executor, table heap and dispatch;
this keeps categories disjoint. `measurements.json` retains both the groups
and all exclusive symbol counts, so the grouping can be independently
recomputed from the complete call graphs. These are sampled occupancy,
not dispatch/call counts or causal fractions of the Halo–PUC difference.

| Workload profiled | Worker samples, three runs | Measured broad work (range across runs) |
|---|---|---|
| fib(34) | 1117, 1108, 1123 | Dispatch arms 48.2–51.8%; Lua call/frame helpers 43.8–47.8%; safepoint path 3.4–4.4%; no completed GC |
| loop, 1e8 | 1026, 999, 1019 | AddRR/ForLoop arms 85.7–87.8%; safepoint predicate 12.2–14.3%; no completed GC or sampled slow executor |
| integer-table, 1e7 | 551, 556, 555 | Table heap 35.7–37.9% (including rehash); dispatch 39.0–43.4%; slow executor 8.0–10.3%; GC/safepoint 7.7–8.8% |
| string-key, 20e6 | 792, 690, 798 | Dispatch arms 89.0–91.3%; table heap 5.6–6.5%; safepoint 2.8–4.5%; no completed GC |
| concat, 10e6 | 1508, 1562, 1563 | Concat/intern plus slow executor 60.0–66.8%; dispatch 31.5–37.1%; no completed GC |
| sort, 1e6 | 508, 513, 514 | Sorting library 73.7–76.2%; dispatch 9.1–10.5%; GC/safepoint 0.4–0.8% |
| binary-trees, depth 14 | 1845, 1854, 1848 | Table heap/allocation 28.4–29.4%; dispatch 28.7–30.2%; Lua calls/frames 19.0–20.3%; GC/safepoint 12.6–14.0%; slow executor 6.6–7.4% |

Sampling attaches after launch, omits the earliest part of execution, and
can alias very short hot loops. Tail calls and inlining erase some caller
ancestry; a table helper sampled at the root cannot be assigned to a
particular slow call. The table/sort workloads have allocation and execution
phases, so omitted early samples can bias phase shares. The three runs
support broad locations of work, not precise instruction-level costs.
We did not profile PUC or run an isolating before/after implementation pair,
so these percentages do not measure how much of the gap each cause explains.

### Value width, handles and native dispatch inspected first

`xcrun llvm-objdump --macho --disassemble --no-show-raw-insn` inspected both
hashed native binaries; exit 0 for both. The Halo Move arm loads/stores
`q0` (16 bytes) with `lsl #4`; PUC `luaV_execute` derives register addresses
with `uxtb #4` and `lsl #4`. Both value-slot strides are 16 bytes. Value
width by itself is therefore not a demonstrated difference from PUC.
Numeric AddRR still copies both 16-byte operands to temporary stack slots,
reads their tags and payloads back, and copies `Step`/continuation fields:

```text
Halo run arm 20 (AddRR):
100031c74: ldr q1, [x11, x9, lsl #4]
100031c7c: ldr q0, [x11, x9, lsl #4]
100031c80: stp q0, q1, [sp, #0x70]
100031c84: ldr w9, [sp, #0x80]
100031c88: cmp w9, #0x3
100031c94: ldr w9, [sp, #0x70]
100031c98: cmp w9, #0x3
100031ca4: ldr d0, [sp, #0x88]
100031ca8: ldr d1, [sp, #0x78]
100031cac: fadd d0, d0, d1
```

Sampled AddRR offsets include +76/+84 (the temporary store and tag compare),
but the collapsed reports do not give separate per-instruction counts.
This establishes that traffic/tests remain on the numeric hot path; it does
not assign a percentage or measured gain to eliminating them.

Numeric AddRR and ForLoop use no table/string handle. Fib has closure and
upvalue access; string-key GetTableR calls `node_find`, whose exclusive
samples account for most of the reported table-heap group. The source
GetTableR/GetTableK handlers check table handle bounds and `live`, and string
key paths check string handles. Those checks occur inside sampled arms and
helpers and cannot be separated from lookup, tags or payload access by these
profiles. Thus handle-check overhead remains unquantified; it is not asserted
to be the numeric-loop cause. No completed GC on fib or loop rules out full
collection work there, while safepoint predicate cost remains visible.

The current native build has 73 `run.body.arm.N` symbols and indirect jumps
in the hot arms: handlers have been inlined and source joining does not
produce only one native dispatch point. For example, AddRR's epilogue still
checks the frame and constant-pool windows, moves continuation fields, and
then dispatches directly:

```text
100031dc0: add x8, x27, #0x100
100031dcc: cmp x8, x9          ; stack window
100031ddc: add x8, x28, #0x100
100031de8: cmp x8, x9          ; constant window
100031e08: ldur q0, [x19, #0x58]
100031e0c: str q0, [x19, #0x70]
100031e14: ldp x26, x27, [x19, #0x70]
100031e18: mov w8, #0xc        ; 12-byte Cell stride
100031e20: madd x1, x26, x8, x0
100031e24: ldr w8, [x1, #0x10]!
100031e28: ldr x4, [x2, x8, lsl #3]
100031e38: br x4
```

ForLoop arm 66 calls `collect_if_due` on its hot path; sample occupancy
corroborates that call even with zero collections. Cell stride is 12 bytes,
where VM.md section 4 proposed 8. PUC fetches a four-byte instruction
(`ldr w23, [x28], #0x4` at `1000163d0`). This is a measured representation
discrepancy, not a demonstrated throughput attribution or a proposal to
weaken any bounds/handle condition.

### C1–C6 implications, without selection

- C1: current native hot arms already end in indirect tail jumps. Source
  epilogue changes might still change continuation/guard traffic, but the
  predicted gain from replacing one shared native dispatch point is not
  supported on this build; a matched source pair is still needed.
- C2 and C3: numeric profiles and the native AddRR spills/stores point to
  testing accumulator/pinned-local traffic reduction, while preserving
  safepoint stack roots. No measured gain or register-budget result here.
- C4: native AddRR and ForLoop retain numeric tag tests on the sampled paths.
  Specialization is a plausible test; these profiles do not isolate tag cost.
- C5: the kernels largely keep hot state in locals. Sort's checksum phase
  reads global `assert`, but sorting dominates its profile; there is no Redis
  corpus measurement here to select a globals fast path.
- C6: indexed frame/code address calculation, 12-byte Cell stride, repeated
  window tests and continuation traffic are observed on hot paths. This
  supports a representation/lowering experiment, without selecting one.

The budget root bridge, table rehash/allocation, concat helpers and sorting
library also need their own experiments; C1–C6 do not directly cover all
these measured costs. Profile shares cannot predict same-source speedups.

## Commands and exits

Executed commands (reference path shown as `<reference-root>`):

- Full-LTO build shown above: exit 0. Early host authoring probes exited 1
  on FORM-2 formatting, EFF-2 rows and OWN-1 move requirements; these were
  fixed before the successful build or any native timing. Lock-contention
  attempts exited 75 and ran no build or benchmark.
- Under `perl .github/run-check.pl halo-bench-measure /bin/zsh -f`,
  `python3 research/experiments/halo-bench/run.py --lua <reference-root>/redis/deps/lua/src/lua --kernels K --runs 1|3|6 --out ...`:
  exit 0 for every calibration and baseline checksum pair. Initial PUC sizing
  adds `--reference-only`; binary-trees adds `--scale binary-trees=14` after
  the depth-16 PUC sizing run. Final baseline: seven kernels × six pairs.
- Loop budget checks add `--budget realistic --runs 1|3|6`: exit 0,
  checksum unchanged, 100000 suspensions per launch.
- Profiler checks under the same wrapper pattern with label
  `halo-bench-profile` add `--profile`; primary runs use `--runs 3` and the
  attribution scales above: all native, reference and profiler exits 0.
  The budget profile uses `--budget realistic --runs 1 --profile`.
- First sandboxed `sample`: exit 255, runner exit 1, no report. The early
  empty string-key profiler returned 0; inspection found no worker samples,
  and the repaired validator rejects that report. Neither enters attribution.
- `python3 -m py_compile research/experiments/halo-bench/run.py`, validator
  valid/invalid controls, and native disassembly: exit 0.

`make design-lint` calibration passed (exit 0, wrapper wall 7.86 s).
`make static` passed all seven stages (exit 0): repository invariants, spec
archives, README translation, spec prose integrity, guidance, source size
and design lint. `git diff --check` passed (exit 0). These checks cover the
results and TODO/status edits in this working tree on parent
`5d2ab819af3b822f5f051efbc657632c40dbbe82`; the native host hashes are
unchanged. The canonical `make check` was not run: it invokes Cargo, which this task prohibits. No specification rules or design-tree decisions changed;
no decision card is needed for measuring the already requested P1 baseline.

## Independent review

A separate read-only reviewer, configured as GPT-6.1-sol, reviewed
`75c9d7b48ae29642a36c078edd00b0048f0a2fd3..d993ea49f7d670bc401d6115c1cd099c6015cb83`
against checklist groups A, D, R, M and V, including the design-tree
correspondence checks. C and T were not applicable because compiler,
library, formal tests, specification and gate wiring are unchanged;
publication was waived by the explicit no-push/no-PR instruction.

The reviewer read all changed artifacts, the VM commitments, research method,
compiler root and dispatch/self-tail decisions, and the embedding root-bridge
implementation. It independently recomputed accepted pair ordering,
checksums/stats/exits, medians/ranges/ratios and budget arithmetic; verified
source and available binary hashes; reconstructed every primary profile's
exclusive symbol counts and group totals from raw call graphs; and checked
all 22 primary excerpt hashes. No findings within scope. No suites were
rerun, and no file was edited by the reviewer. The remaining depth-16,
causal-speedup, isolated-decrement and full-gate limits remain open.

## Found along the way

- Fixed within the runner: a successful profiler exit can have an empty call
  graph. It now requires one nonzero sampled execution worker; valid, empty,
  zero and ambiguous controls distinguish the failure.
- Deferred in `docs/todo.md`: repeated resume root-bridge copying/allocation;
  Cell width differs from the proposed layout; baseline hot-path costs and
  stale single-native-dispatch attribution. No compiler or VM fix was made.
- The pre-existing full-package check cost remains open; this build's total
  time and contention do not isolate that cause.

## Halo cost repair criteria (recorded before measurement)

Requested scope: persistent embedding root bridges and an inline not-due
collector path; no compiler, language, oracle or normative expectation change.
Keep a candidate only after the unchanged 80 scripts at budgets 1, 7, 1000
pass all 240 comparisons. Stress replies and per-case collection counts must
remain identical at those budgets. Recheck local roots, the isolated frame
and suspended-stack witnesses, the embedding lifecycle probe, and a missing
root negative control.

1. Roots-only: loop(100,000,000), budget 1000, median at most 1.15 times
   the same binary's unlimited median. Report `(budget time - unlimited
   time) / 100000` before and after as total incremental time per suspension,
   including budget charging, rather than isolated resume latency.
2. Inline safepoint: loop unlimited median at least 5% lower than the
   roots-only binary in alternating same-source pairs; otherwise restore the
   safepoint change and retain its negative result.
3. Final P1: unchanged seven kernels, binary-trees depth 14, six alternating
   PUC/Halo pairs each, with matching checksums and unchanged collection counts.

Calibrate each selected comparison with one pair then three pairs, inspect
spread, and use six pairs unless uncertainty crosses a decision threshold.
Native timing builds use the supplied gate compiler and full LTO. Build
observations are separate from program timings. Before/after native pairs
use identical stdin bytes and alternate launch order, with independent PUC
checksum validation. Generated logs/binaries stay in `target/`; retained raw
observations serve this experiment until reproduction is no longer needed.

Structural assessment before implementation: keep the bridge in its existing
constant-pool tail so the collector's one constants argument and VM roots stay
unchanged. Per-script dirty flags invalidate all tails on root-set edits;
boolean invalidation cannot wrap as a generation can. Rebuild directly from
original constant lengths and pins, with geometric reserve; stale inactive
tails are never sources. A separate root registry and collector argument would
change that boundary without improving this experiment's required observation.
Keep the collection body separate and gate it at its callers using the exact
existing three-trigger predicate; a combined allocation/budget counter would
couple separate semantics and is not selected here. Q1, raised during the invalidation audit: make root storage public readonly,
retaining inspection while routing mutations through compile/pin/unpin/forget_all.
Otherwise external writes could bypass invalidation and lose a root. This is
the recommendation under test; owner ruling remains open. No mutable-constants
API is introduced without a concrete consumer.

### Fresh before control

The retained P1 timing binary, gate compiler and Redis Lua hashes match the
baseline identities above. A fresh full-LTO embedding host built successfully
in 464.06 s (exit 0); this construction scale was sized by the existing P1 and
F4 full-package build observations, rather than opening an hours-long batch.
Its one-script cold stress calibration passed in 0.245067 s. Warm whole-corpus
execution is sized separately from construction. The fresh before control
passes 240/240 ordinary comparisons and 240/240 stress comparisons. Stress
collections total 20,450 at each budget; local roots total 25 at each budget;
the isolated frame and parked-stack witnesses have 9 and 14 respectively.
The lifecycle probe exits 0. These fresh per-case counts, rather than an
assumption about historical outputs, are the preservation reference.

The loop budget comparison used one pair (cold unlimited 1.610025 s), then
three warm pairs (relative ranges 0.84% unlimited / 0.35% budget 1000).
Six selected pairs give 1.356240 s unlimited (1.355378–1.367506) and
3.044296 s at budget 1000 (3.035735–3.052223), ratio 2.245×, 100,000
suspensions and no collections per budgeted launch. Incremental time per
suspension is 16.881 microseconds. Calibration is retained, not pooled into
the selected medians. Every checksum agrees with independently executed PUC.

### Roots-only correctness milestone

The roots-only timing host and embedding host built with full LTO, exits 0,
448.25 s and 453.77 s respectively. Ordinary oracle 240/240, stress oracle
240/240, local roots 9/9, isolated frame 1/1 and parked snapshot 1/1 pass.
A tool comparison of every case/budget/status/collection row against the
fresh before control is identical, including 20,450 stress collections at
all three budgets, local totals 25, frame 9 and parked snapshot 14.
The extended lifecycle probe exits 0, checking that pin and compile while
suspended add roots before collection, and unpin while suspended releases its
sole pinned value at the next collection. Final selection awaits the complete
six-pair criterion measurement; the first same-binary budget pair is 1.007×.

The three-pair native before/roots calibration completed (exit 0), with a
0.43% before range and 5.92% roots range; even that full range separates the
large budgeted gain. A subsequent budget three-pair run was interrupted
(exit 129; outer interactive measurement shell exit 143) before its last
launch completed and produced no result JSON. Its partial log is retained
but none of those launches enters a selected median. The interruption's
cause is unknown; the repeat uses a noninteractive wrapper.

### Roots-only selection

Six alternating before/roots pairs at budget 1000 give before 3.049088 s
(3.032233–3.079309), roots 1.360235 s (1.355972–1.376209), a 55.39% reduction.
Six separate alternating unlimited/budget pairs on the roots binary give
1.359659 s (1.353488–1.363208) and 1.361283 s (1.358142–1.367504), ratio
1.001194×: **passes 1.15×; retain the roots change**. Relative ranges are
0.71% unlimited and 0.69% budgeted, far from the decision boundary.
Every launch exits 0, matches independent PUC, has zero collections and
100,000 budgeted suspensions. Incremental time per suspension changes from
16.881 microseconds in the fresh before control to 0.016 microseconds here.
That after point estimate is smaller than launch variation; it is not a
precise isolated resume or decrement latency, nor a proof of P3's 1% target.
The resolved resume-copying TODO is removed; full-package construction cost
and unrelated P1 hot paths remain deferred.

The initial safepoint authoring build exited 1 in 1.39 s at GRAM-9, refusing
nested `bor` calls in atom positions. A second authoring build exited 1 in 1.39 s at GRAM-5 because comparisons
also require binders in call argument positions. Binding all three comparisons
and the intermediate boolean values preserves the proposed predicate; no timing from that failed build is used.

### Inline safepoint measurement

The full-LTO timing build exits 0 in 477.21 s. The first new-binary launch
(1.485965 s) is calibration only. Three warm pairs give relative ranges
0.53% roots-only / 0.54% inline. Six selected alternating pairs give
roots-only 1.387613 s (1.383352–1.389477), inline 1.245011 s
(1.237761–1.248955), ratio 0.897232×, **10.28% faster: passes the 5%
performance criterion**. Relative ranges 0.44% / 0.90% cannot move the
conclusion across the threshold. Both sides use identical loop source bytes,
match independently executed PUC, exit 0, suspend zero times and collect zero
times. The final embedding oracle and stress checks below also pass; retain the
inline safepoint change.

The three tests of the paired runner distinguish valid data (exit 0), unequal
collection counts (exit 1), and wrong native checksums (exit 1); agreeing wrong
native outputs also fail against independent PUC (exit 1). Missing required
root-control flags fail with argparse exit 2. Lock-contention exits 75 launch
no build or benchmark; retrying acquisition never bypasses the host-wide lock.

### Final correctness and retained changes

Both changes are retained. The final full-LTO embedding build exits 0 in
457.89 s. Final ordinary oracle 240/240, stress oracle 240/240, local roots
9/9, frame isolation 1/1, suspended snapshot 1/1 and the extended lifecycle
probe pass. A tool compares every case/budget/status/collection row with the
fresh before control and finds identical outcomes and counts. Stress totals
remain 20,450 at each budget; local-root totals 25, isolated frame 9 and
parked snapshot 14. The independent every-allocation verifier remains open.

The parked-root omission control returns native exit 0 with a Lua error,
`attempt to index a function value`, instead of the unchanged expected bulk
`zzz`; the comparison exits 1 as required (5 collections before the error).
The positive witness returns `zzz` with 14 collections. Only the harness's
parked root visibility changes during the synthetic collection; the snapshot
is restored before resume and the ordinary collector and continuation are
used. No expected reply or oracle source is changed.

The 64 MiB memory exhaustion and same-engine/store recovery witnesses pass
with stress off, before and after, at budgets 1, 7 and 1000: the same
`not enough memory` error followed by bulk `alive`, 8 completed collections
and 9,846 recovered heap bytes at every budget. This separately exercises the
nonzero-limit path rather than hiding it behind stress's always-due trigger.
These existing F4 fixtures were sized by their recorded sub-second executions;
construction and execution remain separate. Q1 is still open: the readonly
root-storage boundary is a recommendation in the live tree, not an approval.

### P1 rerun after the retained changes

Every workload was first launched once and then in three alternating pairs
at the unchanged P1 counts (binary-trees depth 14). Calibration relative ranges
(PUC / Halo):

| Kernel | PUC range % | Halo range % |
|---|---:|---:|
| fib | 0.62 | 0.45 |
| loop | 16.71 | 2.45 |
| integer-table | 1.73 | 0.81 |
| string-key | 1.51 | 2.24 |
| concat | 0.76 | 2.41 |
| sort | 0.92 | 2.85 |
| binary-trees | 0.75 | 1.45 |

The loop reference's 16.71% calibration range does not approach the P1 ratio
boundary; six pairs still distinguish P1 failure on every workload. These
calibrations are retained and excluded from the table. The final six-pair
run alternates PUC/Halo and Halo/PUC and verifies equal source hashes,
checksums and completed collections against the initial baseline.

| Kernel | Before PUC s | Before Halo s | Before ratio | After PUC s | After Halo s | After ratio | After PUC min–max s | After Halo min–max s | Pairs |
|---|---:|---:|---:|---:|---:|---:|---|---|---:|
| fib | 0.077791 | 0.223039 | 2.867 | 0.080212 | 0.227613 | 2.838 | 0.080107–0.080977 | 0.225034–0.228453 | 6 |
| loop | 0.460990 | 1.363583 | 2.958 | 0.473806 | 1.249755 | 2.638 | 0.472441–0.474899 | 1.247932–1.274765 | 6 |
| integer-table | 0.201466 | 0.822095 | 4.081 | 0.206035 | 0.802504 | 3.895 | 0.204913–0.207563 | 0.801091–0.934778 | 6 |
| string-key | 0.026168 | 0.057557 | 2.200 | 0.027376 | 0.059457 | 2.172 | 0.026830–0.028418 | 0.058630–0.059922 | 6 |
| concat | 0.055690 | 0.208976 | 3.752 | 0.057729 | 0.213089 | 3.691 | 0.057574–0.058078 | 0.205546–0.216955 | 6 |
| sort | 0.379271 | 0.744996 | 1.964 | 0.391232 | 0.759584 | 1.942 | 0.387766–0.400727 | 0.752823–0.768441 | 6 |
| binary-trees | 1.278944 | 2.442658 | 1.910 | 1.326630 | 2.491015 | 1.878 | 1.314767–1.331011 | 2.476898–2.513080 | 6 |

All native and reference exits are 0; every unlimited launch has zero
suspensions. Collections remain fib 0, loop 0, integer-table 5, string-key 0,
concat 0, sort 3 and binary-trees 176 in all six launches. P1 still fails on
all seven workloads. Before and after P1 tables are separate sessions;
reference medians changed too, so their absolute differences do not isolate
causal gains on the other kernels. Only the alternating native source pairs
above isolate the selected mechanisms. No post-change profiles were collected;
baseline sample percentages are not current occupancies. Depth 16 and real
Redis end-to-end performance remain unmeasured here.

### Budget comparison before and after

Final-binary calibration uses one pair and then three; the latter ranges are
1.15% unlimited and 4.02% budgeted. Even the observed extremes are below the
1.15× limit, so six pairs suffice for the requested criterion. All selected
budgeted launches have exactly 100,000 suspensions and zero collections;
unlimited launches suspend and collect zero times.

| Version | Unlimited median s | Budget 1000 median s | Budget / unlimited | Incremental µs / suspension | Unlimited min–max s | Budget min–max s | Pairs |
|---|---:|---:|---:|---:|---|---|---:|
| Before | 1.356240 | 3.044296 | 2.244658 | 16.881 | 1.355378–1.367506 | 3.035735–3.052223 | 6 |
| Roots only | 1.359659 | 1.361283 | 1.001194 | 0.016 | 1.353488–1.363208 | 1.358142–1.367504 | 6 |
| Both retained changes | 1.255465 | 1.279899 | 1.019462 | 0.244 | 1.245278–1.265214 | 1.255019–1.294559 | 6 |

The final binary's ratio 1.019462× also passes the root criterion. Its
incremental estimate is 0.244 microseconds per suspension, including all
100 million budget charges, startup and embedding work divided by 100,000
suspensions. Final relative ranges are 1.59% unlimited / 3.09% budgeted;
paired delta variation and the roots-only estimate's near-zero size prevent
interpreting these as isolated resume latencies. The final median budget cost
is 1.95%, so this experiment does not establish P3's under-1% target. No extra
runs were selected to answer that separate question.

### Repair commands, identity and validation

[Cost measurements](cost-measurements.json) retain all 30 calibration/selected
run records with launch order, source/tool hashes, exits, checksums, stats and
spreads, complete oracle/root reports, memory observations, construction logs
and admission controls. This file serves reproducibility of the retained
repairs and is removed when that need ends. The final library manifest names
every Halo source digest. Reused binaries are identified by their SHA-256,
not an assumption that a launch record's HEAD describes uncommitted code.
Before/roots native sources correspond to the initial baseline and the roots
milestone respectively; final timing sources include only the safepoint code
change beyond the roots implementation, plus a doc clarification. The final
embedding host also includes the new root-omission control and lifecycle probe.
The supplemental before-memory report's working-tree source digest is from the
later runner; its reused binary hash identifies the original before host.

Commands below ran locally; `<reference-root>` is the existing Redis 7.0.15
checkout. Native construction and measurement run through
`perl .github/run-check.pl LABEL COMMAND ...`. Lock acquisition retries only
exit 75, never a failed executed command. Scratch fixture files are directed
into the benchmark's existing `target/` (earlier runs used a one-shot in-process
temporary-directory redirect; later ones use `--scratch-root`). No network,
Cargo, push or PR command was used.

- `compiler/target/gate/whitefootc --graph research/experiments/halo-e2e/modules.wfg --entry test --full-lto -o research/experiments/halo-bench/target/e2e-before|e2e-roots|e2e-after`: all exit 0, wrapper walls 464.06 / 453.77 / 457.89 s.
- `compiler/target/gate/whitefootc --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo-roots|halo-after`: exits 0, 448.25 / 477.21 s. The before timing binary is the retained P1 full-LTO binary. Two preliminary syntax probes exit 1 (GRAM-9 and GRAM-5, each 1.39 s), with no timing admitted.
- `python3 -B research/experiments/halo-bench/run.py --lua <reference-root>/redis/deps/lua/src/lua --before-binary BEFORE --binary AFTER --kernels loop --runs 1|3|6 --out target/NAME.json`, adding `--before-budget large|realistic --budget large|realistic` for the mode pairs: every completed run exits 0. Selected files are `before-budget-six`, `roots-six`, `roots-budget-six`, `safepoint-six` and `after-budget-six`. The incomplete budget calibration exits 129, outer shell 143; those observations are excluded. Native wrong-checksum/count admission controls exit 1 as required; valid data exit 0.
- `python3 -B research/experiments/halo-bench/run.py --lua <reference-root>/redis/deps/lua/src/lua --binary research/experiments/halo-bench/target/halo-after --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees --scale binary-trees=14 --runs 6 --out research/experiments/halo-bench/target/after-p1.json`: exit 0. Per-kernel one/three calibration uses the same flags and selected single kernel; all exits 0.
- `python3 -B research/experiments/halo-e2e/run.py --scratch-root research/experiments/halo-bench/target --compiler compiler/target/gate/whitefootc --binary research/experiments/halo-bench/target/e2e-after --budgets 1,7,1000 --report target/REPORT.md`: exit 0, 240/240; add `--gc-stress`: exit 0, 240/240. The before and roots hosts also pass both 240-comparison modes.
- Same runner with `--cases research/experiments/halo-gc/cases --gc-stress --budgets 1,7,1000`: exit 0, 9/9. Add `--filter gc/frame-closure --isolate-frames --budgets 1`: exit 0, 1/1. Add `--filter gc/suspended-stack --collect-suspended --budgets 1`: exit 0, 1/1. These pass on before, roots and final hosts. Adding `--omit-suspended-root` to the final suspended run exits 1 on the intended reply mismatch, native exit 0. Missing required omission flags exit 2 (expected).
- `research/experiments/halo-bench/target/e2e-before|e2e-roots|e2e-after a b c`: lifecycle probes exit 0 (roots/final include the suspended root-set update extension).
- Same e2e runner with before/final host, `--filter lua-core/counter-closure --verify-memory --budgets 1,7,1000`: exits 0, independently expected exhaustion and recovery replies and equal counts/bytes.
- RESP2 sensitivity and paired validator controls: exit 0 for the checking harness; deliberate rejected invocations have the exits described above. `git diff --check`: exit 0.
- `make design-lint`: exit 0, 7.99 s sizing run; `make static`: all seven stages exit 0, wrapper 32.77 s. Static uses a task scratch directory for native temporary files. No `make check` ran because it invokes prohibited Cargo; no ready/merge check or approval log was written. No specification or conformance rules changed.

Validation above ran on working source over parent `41a6fee1c9ddeae319d31aa1feef32e0c9954d2d`; binary and
source hashes identify the tested content. The runtime changes and result prose are committed separately from the
subsequent independent review record. Publication is explicitly out of scope.

### Found during the repair

- Fixed: repeated root bridge allocation/copying; one-slot append growth;
  unconditional collector-helper calls when no trigger holds. Their two
  requested criteria and independent replies/counts select the changes.
- Fixed on recommendation Q1: public root-storage writes could bypass
  invalidation. Root fields are public readonly; inspection remains available
  and embedding operations own writes. The owner ruling is still open.
- Fixed in the existing experiment home: suspended pin/compile/unpin changes
  lacked a lifecycle observation; the probe now covers additions and release.
  A parked-root omission control separates correct rooting from a reply pass
  without collection. A scratch-root option keeps fixture outputs in this
  worktree. Each remains until a maintained test takes over or this experiment
  is retired.
- Removed the resolved resume-copying TODO and updated the P1 TODO/status;
  other hot paths, Cell stride, the every-allocation verifier and compiler
  construction cost remain recorded in `docs/todo.md`. This task does not
  select C1–C6 or claim current profile occupancy for them.

### Review repair criteria

The independent review found that pin followed by compile before resume could
mask either missing invalidation: both operations dirtied the same bridge.
The corrected lifecycle probe requires a collection/survival observation after
pin alone, then after compile alone (while the bridge is valid again), then a
collection/release observation after unpin alone. Before execution, negative
controls are fixed to bypass only the corresponding embedding refresh using
the existing VM resume with its stale constant-pool bridge: pin must exit 59,
compile 69 and unpin 62; ordinary smoke must exit 0. No heap, VM, embedding
implementation, benchmark source or timing binary changes for this repair.
The final e2e host is rebuilt, and the changed CLI's ordinary comparisons and
root controls are rechecked. The interrupted command's reference path is also
redacted to `<reference-root>`; its observed timings and exits are preserved.

The corrected full-LTO e2e host builds with exit 0 in 461.87 s. Ordinary
smoke exits 0; omission of the pin, compile and unpin refreshes independently
fails with exits 59, 69 and 62 respectively, exactly the recorded observations.
The corrected host also passes ordinary 240/240, stress 240/240, local roots
9/9, frame 1/1 and suspended snapshot 1/1; a tool rechecks every row against
before and finds equal outcomes/counts. Memory recovery and the parked-root
omission control retain their earlier expected results. The complete repair
check batch exits 0 in 5.52 s. This supplies the independent invalidator
coverage the initial combined probe lacked.

### Repair independent review

A separate read-only reviewer, configured as GPT-6.1-sol, reviewed
`6cab1f2dcb7fe858846e68758fe210380e7fd7e0..ec69af2c494b5d26ede8cf319e5c73c1d9efc29f`
with A, D, C, R, M and V, including design checks G1–G3 and correspondence
DC1–DC4. T was not triggered; publication was excluded by the user's explicit
constraint. The reviewer reran no green suites. It read the full diff and
owners, independently checked launch ordering, medians/ratios, workload and
tool/binary hashes, all 71 library hashes and e2e source digests, every
case/count comparison and memory observations. It checked the compiler
ancestor and Halo siblings: 114→115 nodes, 550→553 decisions, depth 3 and
526 rejected alternatives unchanged.

Findings fixed: pin and compile mutually masked invalidation in the new
probe (C1/C2, DC4), now separated and each falsified by its own stale-bridge
control; a prospective review-record statement (D3/V2), now replaced by this
actual record; and a machine-local reference path in the interrupted log (A4),
now a role placeholder. The logic repair received the narrow follow-up review below. Q1 remains provisional.

The same read-only reviewer, configured as GPT-6.1-sol, reviewed the repair
`ec69af2c494b5d26ede8cf319e5c73c1d9efc29f..f069b49eba236d68e1f79b5370fd2742e3b98975`
under applicable A, D, C, R, M and V items. It independently verified control
routing, correct and stale-bridge resumes, updated host/source hashes, case
rows/counts, construction and control logs, unchanged timing evidence and
binaries, memory recovery and redaction. Each mutation starts with a valid
bridge and no intervening invalidator; each omitted refresh fails after an
observed collection at its own pin/cached-string/release observation. All
three original findings are resolved; none within narrow scope. No green
suite was rerun and no reviewer edited a file. Full-gate and publication
verification remain outside this explicitly constrained task.

Final `make static` on the reviewed probe repair passes all seven stages,
exit 0 in 33.59 s; `git diff --check` passes after the review record. The
handoff leaves the work branch local and the readonly boundary Q1 open;
no specification change, approval record, PR, push or merge is made.

## C1 bounded per-arm continuation experiment

Criterion fixed before any C1 measurement: keep C1 only if both the numeric
loop and fib improve by at least 10% in six interleaved same-source
before/after pairs (full LTO), and the median of three uncached
`whitefootc --graph lib/halo/modules.wfg --check-modules` runs grows by at
most 1.5 times. Otherwise revert the candidate and retain the observations.
Improvement is `1 - median(after) / median(before)`; individual paired ratios
are also retained to expose drift or spread near 10%. The seven P1 sources
remain identical within each pair; binary-trees uses the previously sized
depth 14. The oracle must pass under budgets 1, 7 and 1000, both normally
and with GC stress. The experiment changes only Halo dispatch/handler source,
not the compiler, language, or oracle.

A single accepted module-check run sizes each side before the remaining two
runs. One pair and then three pairs size each kernel before the selected
six. Failed formation or proof attempts are reported separately and do not
enter the check-cost statistic. Each heavy command holds the host-wide lock
separately; exit 75 waits and retries that same command. C1 generated outputs
and compiler temporary files live in this experiment's existing ignored
`target/`; retained observations serve reproduction and are retired when
this comparison no longer needs reproduction.

### Checked source boundary

The retained P1 leaf counts selected 18 arms: Move, LoadK, GetUpval,
GetTableR/K, SetTableRR/KR, AddRR/RK, SubRR/RK, MulKR, ModRK, EqJmpRK,
LtJmpRK/KR, LeJmpRR and ForLoop. GetUpval is prominent in fib; MulKR and
SubRR occur in binary-trees; ModRK occurs in string-key, concat and sort.
Unselected siblings, Call and Return retain the joined Step epilogue.
The latter two change frame bases, so this unchanged-base trial leaves
`prepare`, `enter_lua` and `finish` unchanged.

Move, LoadK, GetUpval and ForLoop return `Result<u64, Step>`; success carries
the next pc and checked stack-window postconditions. The 14 handlers with
callback slow paths get separate callback-free variants returning
`Result<FastCursor, Step>`. A cursor contains a pc and a Bool saying whether
the instruction was handled. A fast miss returns the current pc with that
flag false before mutation, and the arm invokes the unchanged full handler.
Success tail-calls directly from the arm; errors and suspension forward the
original Step to the shared epilogue. Table-write failures unwind once, as
before. Numeric comparisons only read the stack and preserve its window
fact directly; slot-writing variants publish it. The read-only constant
window keeps its caller fact and needs no new postcondition.

This boundary follows [FN-9](https://github.com/Ming-Research/Whitefoot/blob/13453860b462ad3ae169b8e7fb9e1318cf9463a0/spec/kernel-spec.md): a full handler's
callback can re-enter `run`, so its postconditions are unavailable within
that recursive component. The callback-free variants are outside that
component and their checked summaries reach the arms. Putting entire
arithmetic/table handlers inside `run` would instead expand its proof body;
small leaf variants keep operation proofs separate from dispatch control.
The experiment does not change the recursive-summary rule. P1 already
showed native per-arm dispatch in the joined source, so this trial tests
window checks and continuation traffic, rather than creating that native
split. Native layout and other traffic can also change.

### Check and kernel observations

The requested graph-check command checks the whole selected package graph;
these are its process wall times, not isolated vm-stage timings. Its only
changed inputs are the two VM implementation files. Waiting for the lock
is excluded. All six admitted checks exited 0.

| Check | Before s | After s |
|---|---:|---:|
| Run 1 | 216.28 | 241.00 |
| Run 2 | 210.07 | 241.95 |
| Run 3 | 206.35 | 239.36 |
| Median | 210.07 | 241.00 |

After/before is **1.147**: the 1.5-times check-cost criterion passes.

The first fib candidate launch took 0.573571 s versus 0.228337 s before;
this cold launch is calibration. The three warm-pair fib ratio was 0.8764,
with before/after relative ranges 2.52%/0.38%; loop's ratio was 0.4542,
with ranges 0.81%/0.23%. Every other kernel also received one pair and three
pairs before selection. The calibration and final raw launches, source
hashes, native/compiler/reference hashes, exits, checksums and spreads are
in [c1-measurements.json](c1-measurements.json).

Six alternating Before/After then After/Before pairs use identical stdin
bytes and full-LTO binaries. Each kernel also gets an independent PUC
checksum launch. Both native collection counts agree in every pair, every
native/reference exit is 0, and all unlimited-budget suspension counts are
zero. Both VMs use the normal collector and the benchmark's 2 GiB limit.

| Kernel | Before median s | After median s | Improvement | Before min–max s | After min–max s |
|---|---:|---:|---:|---|---|
| fib | 0.220752 | 0.193442 | 12.37% | 0.218624–0.221286 | 0.193185–0.201287 |
| loop | 1.244630 | 0.568529 | 54.32% | 1.238197–1.253410 | 0.566335–0.570564 |
| integer-table | 0.800244 | 0.754434 | 5.72% | 0.792646–0.808324 | 0.752455–0.758918 |
| string-key | 0.059308 | 0.039479 | 33.43% | 0.059137–0.061065 | 0.039038–0.039885 |
| concat | 0.214733 | 0.182682 | 14.93% | 0.211864–0.217162 | 0.174099–0.186722 |
| sort | 0.752426 | 0.734345 | 2.40% | 0.750257–0.782200 | 0.729774–0.740241 |
| binary-trees | 2.481321 | 2.448951 | 1.30% | 2.477680–2.490589 | 2.437143–2.452813 |

Both numeric median criteria pass. Fib's individual paired ratios range
from 0.8734 to 0.9123: five of six pairs clear 10%, while one improves only
8.77%. The agreed statistic is the ratio of medians, and both the three-
and six-pair results put that gain near 12.4%. The loop's six paired ratios
range from 0.4552 to 0.4592. Other kernel gains are observations, not
additional selection thresholds. This does not measure a new PUC-relative
P1 baseline, isolate window-check cost from layout/other continuation
traffic, or qualify other hosts, compilers, budgets or binary-trees depth 16.

### Outcome and validation

**Kept.** The fixed numeric and check-cost criteria pass, and both oracle
modes pass 240/240 comparisons: 80 unchanged scripts at each of budgets
1, 7 and 1000. GC stress performed at least one collection in every row.
No source or expected reply in the oracle changed. The normal and stress
samples each passed 3/3 before the full runs. The native source revision is
`bcb2ab4f35bf112471521875dea9c02aaafbdaae`; only `dispatch.wf` and
`handlers.wf` differ from the before library. The existing before benchmark
binary was built at `ec69af2c4` (full identity in the JSON), and a tool
comparison verified its Halo, benchmark host/graph, compiler, standard
library, JSON and MessagePack sources equal the before worktree. Its build
log records full LTO. Compiler hash stayed
`c71614ecb1da4ab8b5c4cfea7bec7afa3a39aeb967657e1aaa2019c76dbf3fc5`.

Every heavy command below was a separate
`perl .github/run-check.pl <label> <command>` invocation. Full-LTO builds
set TMPDIR to the existing benchmark target directory. Busy-lock attempts
returned 75 and retried the same command; none entered an admitted timing.
The host was the same M1 Pro/macOS environment as P1; the lock excluded
other cooperating heavy commands, not background OS activity.

| Command stage | Wall s | Exit | Observation |
|---|---:|---:|---|
| check-before-1 | 216.28 | 0 | whole graph accepted |
| check-before-2 | 210.07 | 0 | whole graph accepted |
| check-before-3 | 206.35 | 0 | whole graph accepted |
| check-after-1 | 241.00 | 0 | whole graph accepted |
| check-after-2 | 241.95 | 0 | whole graph accepted |
| check-after-3 | 239.36 | 0 | whole graph accepted |
| bench-build | 543.17 | 0 | full LTO, entry bench |
| fib-one | 1.03 | 0 | 1 cold sizing pair |
| others-one | 12.61 | 0 | 1 sizing pair per remaining kernel |
| three | 33.83 | 0 | 3 warm interleaved pairs per kernel |
| six | 66.84 | 0 | 6 selected interleaved pairs per kernel |
| e2e-build | 535.89 | 0 | full LTO, entry test |
| oracle-sample | 0.39 | 0 | 3/3 normal |
| stress-sample | 0.09 | 0 | 3/3 stress |
| oracle | 0.98 | 0 | 240/240 normal |
| stress | 1.05 | 0 | 240/240 stress |
| design-lint | 7.67 | 0 | smallest static sizing sample |
| static | 33.62 | 0 | every component within its macOS budget |

The JSON retains exact command arguments with `<PUC_LUA>` as the supplied
local Redis 7.0.15 Lua path. Reproduction commands use:

```sh
perl .github/run-check.pl halo-c1-check compiler/target/gate/whitefootc --graph lib/halo/modules.wfg --check-modules
perl .github/run-check.pl halo-c1-bench-build compiler/target/gate/whitefootc --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo-c1
perl .github/run-check.pl halo-c1-six python3 -B research/experiments/halo-bench/run.py --lua /path/to/redis/deps/lua/src/lua --before-binary research/experiments/halo-bench/target/halo-after --binary research/experiments/halo-bench/target/halo-c1 --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees --scale binary-trees=14 --runs 6 --out research/experiments/halo-bench/target/c1-six.json
perl .github/run-check.pl halo-c1-e2e-build compiler/target/gate/whitefootc --graph research/experiments/halo-e2e/modules.wfg --entry test --full-lto -o research/experiments/halo-bench/target/c1-e2e
perl .github/run-check.pl halo-c1-oracle python3 -B research/experiments/halo-e2e/run.py --compiler compiler/target/gate/whitefootc --binary research/experiments/halo-bench/target/c1-e2e --full-lto --scratch-root research/experiments/halo-bench/target --budgets 1,7,1000 --report research/experiments/halo-bench/target/c1-oracle.md
```

Add `--gc-stress` and use a separate report for the stress run. Substitute
the supplied Lua path for `<PUC_LUA>`; set TMPDIR to the worktree's existing
target directory for builds. The before binary must be rebuilt from its
recorded source if absent, not substituted with an older pre-repair binary.

Five excluded check attempts exited 1: FN-9 postcondition formation
(6.33 s), FN-8 unavailable recursive summary (381.27 s), FORM-4 comment
(2.59 s), GRAM-9 nested Bool construction (3.48 s), and EFF-2 unused
constant reads (6.31 s). The accepted boundary above resolves all five;
formation fixes add no language rule. `make design-lint` and `make static`
passed on the measured implementation and the accompanying evidence/tree
edits. The latter checked repository invariants, archives, translation,
prose, guidance, source size and tree form. `make check` and CI were not run:
the task prohibits Cargo and network. No Cargo, network, PR or push command
was issued for C1. A concurrent process committed and pushed the
pre-existing DESIGN.md edit after the criterion milestone; the C1
implementation commits remained local.

Found along the way: the C1 row's single-native-dispatch premise was stale
against P1 disassembly and is corrected; callback-free summaries are
required by FN-9, not a checker defect. Duplicate fast/full operation logic
and repeated work on fast misses are recorded in docs/todo.md for a later
measured factoring. No specification or conformance rule changed. The
new design node is provisional; no approval log or readiness action is
part of this local experiment.


Independent read-only review covered
`7b410745caba81d0c0c6df187198f7e8576fbf99..d282a76c8714fc24075d68fe098d185db897c41b`,
with requested model `gpt-6-sol`, excluding the unrelated pre-existing
DESIGN.md edit. It checked groups A, D, C, R, M and V; T was not triggered,
and publication/PR checks were outside the task. For M1 it applied G1–G3
and DC1–DC4 to the relevant compiler/language ancestors and the new node.
It read the complete C1 diff and surrounding dispatch, handlers, continuation
checks, results, raw measurements and reports; `git diff --check` passed.
It independently recomputed the medians, checked alternating launch order,
oracle counts and hashes, and inspected the static logs without rerunning
green suites. Findings: **none within scope**, so no finding required a fix.
The implementing agent also rechecked the raw medians, 80-by-three oracle
rows, after source hashes, native/compiler/report hashes and source equality
at handoff. Only this review/result record changed after the reviewed
revision; the measured implementation remains unchanged. Full `make check`
and CI are unverified as stated above.

## C2/C3 profile-directed bounded experiment

Criteria fixed before measurement against the C1 source at
`dc39d44d9811d65f92fc4262c7b7f5f8359a1812`: C2 is kept only if both fib(30)
and loop(100,000,000) improve by at least 10%; C3 is kept only if each
additional pinned local improves both numeric kernels by at least 5%.
Improvement is `1 - median(after) / median(before)` from six alternating
same-source full-LTO pairs. Measure all seven existing kernels (binary-trees
depth 14), preserving independent PUC checksums and native collection counts.
The median of three uncached `--graph lib/halo/modules.wfg --check-modules`
runs may be at most 1.25 times C1's 241 s median (301.25 s). This is whole
graph wall time, not an isolated vm stage. Size each command with one run
and inspect three-run spread before selecting six pairs.

First re-profile fib and integer-table on the C1 binary, with one sizing
profile then three profiles, using the previously sized fib(34) attribution
count. Profiles choose which candidate to try first; if frame work or table
access is indicated instead, record that alternative's criterion before
implementing or measuring it. Profile occupancy alone does not select a
change. Stack slots remain authoritative at every safepoint and slow path.
The unchanged oracle must pass all 240 comparisons at budgets 1, 7 and
1000 in ordinary and GC-stress modes, and the local halo-gc witnesses and
root omission controls must remain discriminating. No compiler, specification,
or expected reply changes are in scope.

Structural assessment: use the existing C1 callback-free boundary for any
hot-path trial, preserving shared slow execution and collector enumeration.
Assess a profile-selected frame/table alternative in its current owner
before implementation. Generated binaries, profiles and logs belong in the
existing ignored benchmark `target/`; retained observations belong in this
experiment and remain only while the comparison needs reproduction. Work
stays local: no network, Cargo, PR or push.

### Profile selection and frame-window criterion

The C1 binary's retained source hashes all match the current inputs. One
sizing profile then three profiles used fib(34) and integer-table(10,000,000).
Fib has 1090, 1090 and 1122 worker samples: frame helpers occupy 54.01–58.62%,
including `enter_lua` 36.99–42.66%; dispatch arms occupy the remainder.
Integer-table has 586, 588 and 588 worker samples: table heap 41.33–42.52%,
dispatch 38.95–39.97%, slow/assignment 12.80–13.61%, GC/safepoint 4.93–5.12%.
Rehash alone occupies 31.12–32.31%. Exclusive counts subtract immediate
children and sum to each worker total; main-thread waiting is excluded.
Inlined predicates remain attributed to their containing arm. Profiles
are occupancy, omit startup before attachment and can alias short loops;
they do not predict a causal gain. Profile timing is excluded from pairs.
The warm Halo ranges are 2.29% for fib and 0.81% for integer-table, adequate
for these broad categories. The first sandboxed profile failed (`sample`
255, runner 1, no report); local process-inspection access permits the
sizing and three-run profiles, both runner exit 0.

The authorized alternative is a bounded frame-window trial, instead of
implementing C2 or C3 on evidence dominated by frame setup and table growth.
C2/C3 remain unmeasured, not rejected by their performance criteria. Before
implementation and timing, fix this criterion: keep frame-window clearing
only if fib(30) improves at least 10% in six alternating full-LTO C1/candidate
pairs and the three-check median is at most 301.25 s. Report all seven kernels;
other gains do not substitute for fib. Preserve the complete oracle and root
controls stated above.

Structural assessment: retain `enter_lua` as the single frame-construction
owner. Express its existing saturating room rejection as an equivalent
base bound, reserve the same 256 slots, and clear the same range with proved
ordinary addition. This removes repeated saturation and slot comparisons
without changing frame fields, callback boundaries, collectors, or C1 arms.
A separate fixed-arity dispatch handler would duplicate frame initialization
and is not needed to test this arithmetic. No register is left uncleared and
no value is cached outside the stack. Table growth remains a separate trial.

### Six-pair frame-window result

One pair then three warm pairs sized all seven kernels. The first candidate
fib launch was cold (3.1988 times before) and is calibration only. Three
warm pairs give fib improvement 3.53%, with before/after ranges 3.60%/1.18%.
Six pairs suffice to separate this result from the fixed 10% criterion; no
calibration is pooled into the selected medians. Raw launches and identities
are retained in [c23-measurements.json](c23-measurements.json); complete
re-profile excerpts are appended to [profiles.txt](profiles.txt).

| Kernel | C1 median s | Trial median s | Improvement | C1 min–max s | Trial min–max s | Pairs |
|---|---:|---:|---:|---|---|---:|
| fib | 0.199645 | 0.193672 | 2.99% | 0.198370–0.205063 | 0.191796–0.194708 | 6 |
| loop | 0.572553 | 0.568471 | 0.71% | 0.568169–0.576355 | 0.565223–0.576784 | 6 |
| integer-table | 0.760434 | 0.758343 | 0.27% | 0.751175–0.772991 | 0.755339–0.766632 | 6 |
| string-key | 0.040090 | 0.040056 | 0.09% | 0.039993–0.040833 | 0.039953–0.040961 | 6 |
| concat | 0.182554 | 0.182411 | 0.08% | 0.176662–0.189711 | 0.177668–0.186253 | 6 |
| sort | 0.733036 | 0.729796 | 0.44% | 0.725248–0.748573 | 0.725477–0.749748 | 6 |
| binary-trees | 2.476578 | 2.428629 | 1.94% | 2.450180–2.547833 | 2.418796–2.438365 | 6 |

Fib improves **2.99%, failing 10%**. Its individual paired ratios and all
launches remain in the JSON; even min/max variation does not support 10%.
Every native/reference exit is 0, source bytes and printed checksums agree,
suspensions are zero, and paired completed-collection counts agree: fib 0,
loop 0, integer-table 5, string-key 0, concat 0, sort 3, binary-trees 176.
These are same-source total process times on the recorded M1 Pro/macOS
host; native placement can change along with the source arithmetic. No
claim assigns the measured gain solely to check removal. This trial is
reverted after its cost/correctness observations; C2/C3 are unmeasured.

### Check-cost observations

The same candidate source passes three uncached whole-graph checks. Tool
wall times are 271.14, 250.02 and 251.17 s (all exit 0), median **251.17 s**.
Against the supplied C1 median of 241 s this is **1.042× (+4.22%)**, below
301.25 s: the 1.25× guard passes. The range is 250.02–271.14 s; the baseline
was measured earlier, so this is not a paired attribution of checker cost.
No module-stage or proof-phase cost is isolated. The runtime criterion still
fails and determines reversion. Two early authoring checks exited 1 at
FORM-2 because an overbroad edit touched unchanged `prepare` indentation;
that suffix was restored before any accepted check/build/timing. Their
exact raw logs were overwritten during repair and no duration from them
enters the admitted statistic.

### Trial correctness observations

The full-LTO trial oracle host builds with exit 0 in 552.00 s. One-script,
three-budget ordinary and stress samples pass 3/3 each before the complete
runs. Ordinary oracle **240/240** and stress oracle **240/240** pass at
budgets 1, 7 and 1000. A tool compares every case/budget/result/collection
row with C1's retained reports and finds all 240 rows identical in each
mode. Stress totals remain 20,450 collections at each budget, with no
zero-collection script. No script or expected reply changed.

The local root witnesses pass 9/9 with stress at the three budgets, 25
collections per budget. Frame alias isolation passes 1/1 with 9 collections;
the parked-stack collection probe passes 1/1 with 14. Hiding that snapshot
only during collection fails comparison (exit 1), returning the existing
`attempt to index a function value` error after 5 collections rather than
expected `zzz`. Embedding smoke exits 0. Independent omitted pin, compile
and unpin refresh controls exit 59, 69 and 62 as required.

The remaining source-root omission controls are constructed separately with
a worktree-local compiler cache; they test discrimination, not performance.
Each removes one marking call, retains the surrounding reads/iteration,
uses unchanged cases, and restores the collector before the next control.

### Root discrimination and final source

The independently built controls all compile successfully: open-upvalue
marking omitted, 569.65 s; frame-closure marking omitted, 523.78 s; constant
marking omitted, 525.38 s (each exit 0, worktree-local cache, no timing
selection from these builds). Open-upvalue omission fails 3/3 comparisons
at budgets 1, 7 and 1000, returning bulk `wrong` rather than `kept`, with
3 collections each. Frame omission fails the isolated budget-1 witness
after 9 collections, returning `invalid upvalue index` rather than `qqq`.
Constant omission fails 50/80 scripts at each budget, **150/240** comparisons.
All three comparison runners exit 1 as required. A short repeat retained
the typed negative replies; its source and executable digests match the
first runs. The JSON retains removed calls, collector/binary hashes, raw
reports and typed replies. Each collector change is restored independently.

**Reverted.** Library bytes now equal the task's C1 base, confirmed by
`git diff --exit-code dc39d44d9811d65f92fc4262c7b7f5f8359a1812 -- lib`
(exit 0). C1 remains kept; no additional optimization is kept. C2 and C3
criteria are recorded but neither mechanism was implemented or measured: the
authorized profile-directed alternative was tried instead. The 2.99% result
rejects only this frame-window trial under its 10% criterion, not frame
optimization generally or C2/C3. There is no new design-tree decision or
specification rule change. VM.md's C2/C3 rows say unmeasured; the performance
TODO records remaining frame and table work and the failed bounded trial.

Busy-lock attempts during the typed-reply repeat exited 75 and retried
only that same command. A stale design-lint record then blocked acquisition:
its recorded owner PID was absent (`ps` exit 1 and `kill(pid, 0)` reporting
`ProcessLookupError`), and the command record was inspected before removing
only its pid/command files and empty lock directory. The next retry acquired
the normal lock. No live owner was interrupted and no lock override was used.

### Commands and limits

Every heavy child was its own `perl .github/run-check.pl LABEL COMMAND ...`;
the one-shot orchestration drivers ran outside the wrapper, and were deleted
after use. Generated binaries, logs, cache and typed replies stay in the
existing ignored worktree target. Native speed pairs use full LTO; cached
negative-control builds are correctness checks only. Commands, exits, raw
launches and redacted logs are in c23-measurements.json. Reproduction uses
C1's retained full-LTO binary or a rebuild from the base above, and the
trial source in commit `600ac4ec6e5ec0eb3cee8c25a84774919821182b`.

| Stage | Tool wall s | Exit | Observation |
|---|---:|---:|---|
| bench-build | 561.16 | 0 | accepted |
| one-pair | 13.23 | 0 | accepted |
| three-pairs | 32.46 | 0 | accepted |
| six-pairs | 62.01 | 0 | six pairs per kernel |
| e2e-build | 552.00 | 0 | accepted |

Reproduction commands run from the worktree root. Use the trial source at
the recorded commit for candidate builds; the final branch has reverted it.
Replace `<PUC_LUA>` with the supplied local Redis Lua executable. Set TMPDIR
to the existing benchmark target for builds.

```sh
perl .github/run-check.pl halo-c23-profile python3 -B research/experiments/halo-bench/run.py --lua <PUC_LUA> --binary research/experiments/halo-bench/target/halo-c1 --kernels fib,integer-table --scale fib=34 --runs 3 --profile --out research/experiments/halo-bench/target/c23-profile-three.json
perl .github/run-check.pl halo-frame-check compiler/target/gate/whitefootc --graph lib/halo/modules.wfg --check-modules
perl .github/run-check.pl halo-frame-bench-build compiler/target/gate/whitefootc --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo-frame
perl .github/run-check.pl halo-frame-pairs python3 -B research/experiments/halo-bench/run.py --lua <PUC_LUA> --before-binary research/experiments/halo-bench/target/halo-c1 --binary research/experiments/halo-bench/target/halo-frame --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees --scale binary-trees=14 --runs 6 --out research/experiments/halo-bench/target/frame-six.json
perl .github/run-check.pl halo-frame-e2e-build compiler/target/gate/whitefootc --graph research/experiments/halo-e2e/modules.wfg --entry test --full-lto -o research/experiments/halo-bench/target/frame-e2e
perl .github/run-check.pl halo-frame-oracle python3 -B research/experiments/halo-e2e/run.py --compiler compiler/target/gate/whitefootc --binary research/experiments/halo-bench/target/frame-e2e --scratch-root research/experiments/halo-bench/target --budgets 1,7,1000 --report research/experiments/halo-bench/target/halo-frame-oracle.md
```

For the oracle's stress mode, add `--gc-stress` and a separate report. Local
root runs add `--cases research/experiments/halo-gc/cases`; the isolated frame
adds `--filter gc/frame-closure --budgets 1 --isolate-frames`, and the parked
probe adds `--filter gc/suspended-stack --budgets 1 --collect-suspended`. Its
omission control adds `--omit-suspended-root` with stress on (expected exit 1).
The source-root controls remove exactly the JSON's named call from the trial
collector, one at a time, build with `--cache` inside the target instead of
full LTO, and use the unchanged selected root case or full stress corpus.
Restore before the next control; an accepted control build exits 0 and the
comparison exits 1. No oracle expectation is changed.

Unverified: C2/C3 performance, other hosts/compilers, budgeted performance,
binary-trees depth 16, isolated frame/checker sub-costs, and F4's existing
every-allocation reachability-verifier gap. The canonical `make check` and
CI are excluded by the task's Cargo/network prohibition. No Cargo, network,
push, PR, merge, specification or conformance change is made.

Found along the way: fixed the performance TODO's stale all-joined C1
description and the benchmark README's present-tense candidate status;
recorded remaining frame/table costs in the existing TODO. The two early
formation repairs and excerpt-boundary whitespace were corrected locally.
No new compiler or collector defect was inferred from sampled occupancy.

Static validation on the reverted library and complete evidence: the
`make design-lint` sizing run exits 0 in 7.98 s; `make static` exits 0 in
34.38 s with all seven stages within their macOS budgets. It checks repository
invariants, specification archives, translation, prose, guidance, compiler
source-size records and tree form. `git diff --check` exits 0. The revision
to be reviewed below preserves the C1 library byte for byte.

### Independent review

A separate read-only reviewer, configured as GPT-6.1-sol, reviewed
`dc39d44d9811d65f92fc4262c7b7f5f8359a1812..51e58fc8ce90bec5d5e52896ab5cc33b82336066`
under A, D, R, M and V, plus C for the archived experimental source delta.
T was not applicable: no final specification, formal test or gate change.
Publication was excluded by the task's explicit instruction. The reviewer
read the full diff, experimental frame delta, evidence, all Halo tree nodes
and the design-tree procedure, and independently checked library/input
equality, baseline and candidate identities, medians and launch conditions,
all eight excerpt hashes and sampled groups, oracle/count equality, root
omission failures, check times and prior criterion commits. It ran no green
suite and edited no file. Findings: **none within scope**. G1–G3 and DC1–DC4
found no missing or contradictory retained decision: the trial preserves the
existing frame owner and stack roots, is reverted, and C2/C3 are explicitly
unmeasured. No decision card, other tree edit or specification rule delta
is introduced by this task.

The implementing agent rechecked all 71 baseline and 111 candidate identity
hashes against their recorded source revisions (compiler against its actual
bytes), and confirmed no task diff under lib, design, spec, tests, compiler
or .github. The final prose-only review record adds no new implementation
claim or change of direction.

Final `make static`, after the review record, passes all seven stages in
32.58 s (exit 0), within their macOS budgets. Active-owner contention returns
75, waits, and retries this same command without overriding the lock.
Final `git diff --check` passes (exit 0); the library and all design,
specification, formal test, compiler and gate bytes remain unchanged from
the task base. All task commits stay local.

## Bounded table-growth experiment

Criterion recorded before attribution builds, source changes and timing,
against task head `66fa1c8b9f422fb9e1bc3885f8c75f1fdbfbabf2`: keep a
change only if integer-table (10,000,000 fill then read) improves at least
10%, the other six kernels do not regress beyond noise, and the unchanged
oracle passes 240/240 comparisons in both ordinary and `--gc-stress` modes,
including byte-identical `next`/`pairs` order against the supplied Redis Lua.
Use six alternating before/candidate full-LTO pairs per kernel, with
binary-trees depth 14 and all other original counts. Improvement is
`1 - median(candidate) / median(before)`. Size with one pair then three
warm pairs before the selected six; retain every selected launch.
For the other kernels, a regression is beyond noise when its median loss
exceeds the larger before/after relative min–max range in the six pairs;
report the ranges and paired results even when that guard passes.
No performance result can substitute for failed behavior checks.

Attribution precedes the candidate: derive the integer table's array/hash
size sequence from both implementations and confirm with a temporary
counter build. Count array and hash scans, histogram-bin work and resize
movement separately. Temporary sources, binaries and logs belong in the
existing ignored benchmark target and are removed when no longer needed;
retained raw observations serve this comparison in this experiment until
superseded. No compiler, specification, conformance, network, Cargo, push
or PR change is in scope. The owner's task supplies the bounded direction
and keep/revert rule; any retained Halo decision is provisional at handoff.

### Growth attribution and structural assessment

Both implementations require **25 rehashes**, triggered at key 1, then
`2^e + 1` for e=0..23. The array grows from empty through
1, 2, 4, ..., 16,777,216 slots; the real hash part stays empty.
Halo's absent-key insertion into an empty hash requests rehash; its
half-full histogram rule picks exactly the same powers as Lua. The
temporary PUC counter confirms every old/new size and triggering key on
the 10-million kernel, excluding startup tables by table identity. The
1,000-element sizing run took 0.42 s including wrapper (exit 0), and the
full counter run 0.31 s (exit 0), checksum `50000005000000`.
The count for Halo is derived from its unchanged insertion and histogram
rules, rather than from a Halo counter build.

Both numusearray equivalents inspect 16,777,215 array slots in total.
Halo additionally makes 352,321,563 bin advances for those array keys,
with integer-to-float-to-integer conversion and Value construction per
live slot; Lua accumulates each power-of-two range directly. Extra-key
classification adds 300 bin advances in Halo. Halo scans zero hash slots;
Lua visits its nil dummy node once per rehash (25 visits), with no hash
element moved. Halo computesizes always visits 27 bins (675 total); Lua
stops after 1..25 bins (325 total). These small differences do not explain
the profile by themselves.

Halo initializes 33,554,431 fresh array slots to Nil and then
reinserts 16,777,215 existing values through insert_parts, including
numeric conversion and bounds work. Lua initializes only the
16,777,216 newly added slots and retains the old prefix through realloc,
whose physical copy count depends on the allocator. Both perform zero
semantic hash-node reinsertion on this kernel; Lua does not semantically
reinsert the retained array prefix. Thus Halo does the same number of
rehashes with substantially more work per rehash, not merely the same
algorithm more slowly. Baseline native rehash offsets +452 and +920
map respectively to the per-array-key histogram loop and fresh-array Nil
initialization; these are prominent sampled offsets, without precise
per-instruction time shares. Raw counter sequence and input identities
are retained in [table-growth-measurements.json](table-growth-measurements.json).
The retained full-LTO C1 binary's 71 input hashes match the task base
66fa1c8b9 (the compiler is checked against its retained binary bytes);
its hash matches the preceding experiment's retained launches. The
candidate input map differs only in tables.wf.

Selected trial: retain rehash as the size-selection and replacement owner,
count array values in power-of-two ranges, and construct the fresh array
by copying its surviving prefix once and initializing only the added
suffix. Reinsert only a shrinking array's vanishing suffix, in ascending
order, then old hash nodes in descending order as Lua does. This removes
redundant work for every table without a workload-specialized path and
preserves the existing accounting and failure boundary: replacement occurs
only after successful insertion and charge. In-place grow/realloc is a
viable further alternative, but this bounded trial isolates redundant
classification, initialization and reinsertion without changing table
ownership or mutation on failed rehash. Reopen prefix allocation copying
if the selected change still leaves measured growth cost. No new public
interface or representation is needed.

### Iteration-order evidence correction

The unchanged corpus has 80 scripts at three budgets (240 comparisons),
not 240 distinct scripts. Inspection finds `lua-core/next-pairs.lua` sorts
both observations before returning them; its README explicitly says it
avoids hash-order dependence. Passing it cannot establish byte-identical
iteration order. Preserve all corpus source and expected bytes and add
scratch, unsorted PUC comparisons of that script and mixed-table growth,
holes, shrink and regrowth. These supplement the required ordinary/stress
oracle, rather than silently strengthening its reported coverage. The
original corpus's order-observation gap is a maintained TODO.

### Fib frame input for the next experiment

The retained three fib(34) profiles contain 1,090, 1,090 and 1,122 worker
samples. Exclusive enter_lua counts are 465, 430 and 415; prepare counts
68, 74 and 84; push_frame 56, 63 and 60; finish 50, 44 and 47. Together
these account for the reported 54.01–58.62%. Their source and native code
show per-call closure/live-handle and prototype checks, a prototype copy,
saturating argument/base/top arithmetic, stack-room checks, register
clearing, construction and copying of an 80-byte Frame, frame-capacity
checks and result Value copying with source/destination bounds checks.
The native enter_lua reserves 464 stack bytes and push_frame reserves 160;
these are native call storage, not Lua's register count. Prominent
enter_lua offsets +492 and +592 map to saved-register restoration and
the room-sentinel test respectively, not the clearing loop; push_frame
+292 is saved-register restoration, +60 its depth check. finish +92/+156
map to result Value stores/addressing. Function occupancy therefore does
not justify assigning the 37–43% enter_lua share to register clearing.

The independent PUC `luac -l -p` listing identifies fib as one fixed
parameter, four registers, no varargs and ordinary recursive calls (two
calls and one addition), so its dominant path needs neither tail argument
movement nor vararg relocation. On Halo's corresponding fixed-arity path,
enter_lua clears registers after the parameters, constructs a frame and
returns a Jump; ensure_stack reserves room for 256 slots but extends
only when needed. No resize_stack child appears in these steady-state
profiles. Frame transport, call/return overhead and repeated checked
metadata work are concrete next attribution targets; exact cycle shares
inside them remain unmeasured. No frame code changes in this experiment.

### Runtime sizing

The full-LTO benchmark build passes in 547.65 s (exit 0). One pair
per kernel takes 12.89 s; the candidate's first fib launch is cold
(0.66915 s versus 0.20765 s), and no sizing launch enters the selected
medians. Three subsequent warm pairs take 31.64 s (exit 0): integer-table
improves 25.68% with before/candidate relative ranges 0.68%/1.08%.
This separates the expected result from the 10% threshold, so select the
requested six alternating pairs. One loop candidate calibration launch
gives an 11.47% range; retain it as calibration, do not pool it or
attribute it to the source change. All sizing checksums and completed
collection counts agree. Report the independent six-pair spread for every
kernel under the already recorded noise rule.

### Six-pair table-growth result

Same-source full-LTO pairs on the recorded M1 Pro/macOS host, normal GC,
unlimited execution budget; process time includes startup, source loading,
compilation and execution. The selected six-pair batch takes 59.92 s
(exit 0); no selected launch is discarded.

| Kernel | Before median s | Candidate median s | Improvement | Before min–max s | Candidate min–max s | Before/candidate range |
|---|---:|---:|---:|---|---|---|
| fib | 0.197299 | 0.197550 | -0.13% | 0.196233–0.202212 | 0.196077–0.200146 | 3.03% / 2.06% |
| loop | 0.561178 | 0.560938 | 0.04% | 0.560504–0.563639 | 0.558494–0.563817 | 0.56% / 0.95% |
| integer-table | 0.747147 | 0.555112 | 25.70% | 0.742155–0.750803 | 0.552090–0.557001 | 1.16% / 0.88% |
| string-key | 0.038109 | 0.038426 | -0.83% | 0.037955–0.038297 | 0.037725–0.041416 | 0.90% / 9.61% |
| concat | 0.178958 | 0.178930 | 0.02% | 0.176419–0.184531 | 0.174141–0.183689 | 4.53% / 5.34% |
| sort | 0.726877 | 0.718753 | 1.12% | 0.725983–0.731520 | 0.716615–0.721970 | 0.76% / 0.74% |
| binary-trees | 2.419485 | 2.418981 | 0.02% | 2.411753–2.433051 | 2.413501–2.429184 | 0.88% / 0.65% |

Integer-table improves **25.70%**, passing the 10% runtime threshold.
Fib loses 0.13%, below its 3.03% before range; string-key loses 0.83%,
below even its 0.90% before range (candidate range 9.61%). The other
five improve. Thus no other kernel regresses beyond the fixed noise rule;
the short string-key result remains noisy. Every native/reference exit
is 0, printed checksum bytes agree, suspensions are zero, and paired
completed collections remain fib 0, loop 0, integer-table 5, string-key 0,
concat 0, sort 3 and binary-trees 176. Individual pairs, launch order,
source/binary hashes and all calibration runs remain in the raw JSON.

The combined trial removes the source-level redundant work identified
above; these timings do not isolate gains from counting, prefix copying
and suffix-only initialization, or native layout changes separately.
Candidate retains fresh allocation and copies the retained prefix:
physical in-place resize and isolated copy costs remain possible follow-up
experiments, not prerequisites for this bounded trial. The computesizes
loop still examines all 27 bins; its small total was not selected.

### Table behavior and selection

**Kept under the recorded criterion.** The candidate oracle host builds
with full LTO in 536.27 s (exit 0). One existing next/pairs script at
three budgets passes 3/3 in ordinary mode (0.65 s including a cold host
launch) and stress (0.21 s), before the complete comparison. Ordinary
**240/240** and GC-stress **240/240** comparisons pass at budgets 1, 7 and
1000. All typed replies match the unchanged recorded Redis corpus bytes.
The implementing agent checks all 240 report rows per mode, actual
ordinary/stress reply bytes, and unchanged oracle, runner and host source.

The supplemental corpus input records the unsorted sequence
`beta=2|alpha=1|gamma=3` for both next and pairs, byte-identical to the
supplied unmodified Lua. A second probe observes mixed numeric, string
and boolean keys through four snapshots of growth, holes, shrink and
regrowth, including borders. Its PUC counter confirms a 64-to-1 array
shrink with keys 24 and 64 still live in the vanishing suffix, and a
later 128-to-0 shrink with sparse numeric entries. Unmodified and counter
PUC outputs agree exactly. Candidate comparisons pass **6/6 ordinary**
and **6/6 stress** (two scripts at three budgets); stress performs 17
and 3,371 collections respectively at each budget. Reversing only the
expected next sequence while preserving its contents and script gives
**0/3**, runner exit 1, as required. These probes protect this trial's
order and border observations; the original corpus's sorted order
observation remains the recorded gap. Probe source, independent expected
bytes, native excerpts, reports and redacted command logs are in the raw
JSON, so the ignored scratch probes can be reproduced without depending
on a new maintained harness.

The ordinary supplementary sizing attempt returned 75 while the stress
oracle wrapper still owned the lock. Subsequent commands acquired it
only after that owner exited; the identical size command was retried and
passed. Its size result therefore follows the full supplemental run,
rather than preceding it; the original corpus samples preceded all
complete runs. No command bypassed the lock and no timed pair overlapped
another heavy command. No original expectation was edited.

The provisional Halo tree choice is `design/halo/heap/tables/growth.md` (Q1 at
handoff). It selects range counting and single-pass replacement against
the measured original algorithm; it does not reject future in-place
resize. No approval log is written. Leftovers in docs/todo.md are the
oracle's order-coverage gap, residual allocation/copying and checked
access costs, and frame-helper attribution. Compiler, specification,
conformance, collector and frame bytes are unchanged. No language rule
changes: every specification rule has identical before/after behavior.

### Table experiment commands and limits

Every heavy child is a direct `perl .github/run-check.pl LABEL COMMAND ...`;
the benchmark and oracle runners are compiler-independent existing
callers. Generated compiler temporaries use the existing benchmark target.
Commands are reproduced below; each listed positive command exits 0.
The order-only control exits 1 as intended, and the one busy sizing
attempt exits 75 before its successful retry. Counter construction uses
clang -O2 on a temporary copy of the supplied ltable.c with the JSON's
fprintf inserted immediately before resize, then links that object with
the supplied lua.o and liblua.a (both wrapper exits 0). The 1,000-element
size run precedes the 10-million fill/read count. `<PUC_LUA>` denotes
the supplied unmodified Lua executable.

```sh
perl .github/run-check.pl halo-table-check compiler/target/gate/whitefootc --graph lib/halo/modules.wfg --check-module pkg::heap
perl .github/run-check.pl halo-table-bench-build compiler/target/gate/whitefootc --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo-table
perl .github/run-check.pl halo-table-six-pairs python3 -B research/experiments/halo-bench/run.py --lua <PUC_LUA> --before-binary research/experiments/halo-bench/target/halo-c1 --binary research/experiments/halo-bench/target/halo-table --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees --scale binary-trees=14 --runs 6 --out research/experiments/halo-bench/target/table-six.json
perl .github/run-check.pl halo-table-e2e-build compiler/target/gate/whitefootc --graph research/experiments/halo-e2e/modules.wfg --entry test --full-lto -o research/experiments/halo-bench/target/table-e2e
perl .github/run-check.pl halo-table-oracle python3 -B research/experiments/halo-e2e/run.py --compiler compiler/target/gate/whitefootc --binary research/experiments/halo-bench/target/table-e2e --scratch-root research/experiments/halo-bench/target --budgets 1,7,1000 --report research/experiments/halo-bench/target/table-oracle.md
```

For the first and three-pair samples replace `--runs 6` with 1 and 3
and use distinct labels and outputs. For oracle stress add `--gc-stress`
and a distinct report. For the original one-script oracle sample add
`--filter lua-core/next-pairs`. Reconstruct supplemental scripts and
canonical expected JSON from the raw JSON in the ignored target, then
add `--cases <probe-root>` to the same oracle runner; the negative
control uses its separately retained order-permuted expectation.
Set TMPDIR to the existing worktree benchmark target for native builds.
The retained baseline full-LTO binary is identified by hash and its
matching source map; if absent, rebuild from task base 66fa1c8b9 with
the same benchmark command and compiler, rather than substituting another
binary. Candidate source is recorded in the raw JSON at ca75ec503.

Unverified: canonical make check and CI (Cargo and network are excluded),
other hosts/compilers, isolated contributions of the combined trial,
physical realloc copy counts, precise intra-frame-helper cycle shares,
binary-trees depth 16, budgeted kernel performance and broader iteration
coverage beyond the corpus and two supplemental scripts. No network,
Cargo, push, PR or merge command is used; all milestones are local.

Static validation: the design-lint sample passes in 7.06 s (exit 0).
`make static` passes all seven stages in 32.34 s
(summed wrapper wall), all exits 0 and all within their macOS budgets.
It checks repository invariants, archives, translation, prose, guidance,
source-size records and tree form. `git diff --check` exits 0. The
unchanged compiler/specification/conformance and original oracle/host
paths are verified against the task base. The benchmark and oracle
source revision is ca75ec503; later edits are evidence and the Halo
decision. The local design choice is provisional (Q1); no readiness
or approval log is part of this experiment.

### Table-growth independent review

A separate read-only reviewer configured as GPT-6.1-sol reviewed
`66fa1c8b9f422fb9e1bc3885f8c75f1fdbfbabf2..84ce1e7ffabe9060a40e03d763a3ba1e36f8aef8`,
plus the local evidence repairs below, under A, D, C, R, M and V.
T is not triggered; publication, canonical make check and CI are
excluded by the task. It read the full diff and contexts, constitution,
checklist and skill, the Halo ancestor and every child, and applied
G1–G3 and DC1–DC4. It recomputed the six-pair medians and guards,
checked all 84 alternating native launches, rehash/work counts,
source and binary identities, report hashes/counts, all 480 actual
corpus replies, supplemental PUC outputs, the order-only failure,
and fib counts/offsets. It ran read-only Git/Python inspections and
git diff --check, and did not rerun green suites.

Fixed finding D3/V2: the baseline identity sentence said its 71 hashes
matched the current head, although the candidate changes tables.wf.
It now names task base 66fa1c8b9. The implementing agent independently
checks every tracked baseline input against that base and the compiler
against its actual bytes; the candidate differs only in tables.wf.
The review also requested retained evidence for the PUC four-register
fib count: a direct read-only `luac -l -p` wrapper exits 0 in 0.10 s,
and the listing and tool hash are now in the raw JSON. The earlier
counter stdout is also retained there. The reviewer verified both
added fields. These are local evidence repairs, with no new choice
or implementation change. **No unresolved findings within scope.**

Found along the way: redundant table histogram, initialization and
reinsertion are fixed; original next/pairs order coverage, residual
allocation/copying and checked access work, and frame transport costs
are recorded in the existing TODO. Temporary counter/probe sources and
control cases are removed after retaining their bytes and observations.
The kept implementation remains identical to its measured revision.
Q1 is the only provisional tree decision in this task; other tree
edits and specification changes are none.

Final `make static` after the review/evidence repairs passes all seven
stages in 32.06 s summed wrapper wall (all exits 0, within budgets).
Final git diff --check passes (exit 0). The implementing agent rechecks
current candidate/source/binary hashes, oracle input identity and each
six-pair median and guard against the retained observations; all agree.
All commits remain local and the final library is the measured candidate.


## Bounded Lua call/return experiment

### Call-path criterion recorded before implementation

Task base: `8f69de69544fdc302f0defd216d791699532d95e`. Attribute fib(30)
from Halo and Lua 5.1.5 source and a scratch counter build before selecting
one smallest supported call/return trial. Keep only if fib improves at least
10%, no other kernel regresses beyond noise, the vm module check-time median
is at most 1.25 times the before median (the preceding measurements were
about 241–251 s), ordinary and GC-stress oracle comparisons each pass
240/240, and the Halo GC root witnesses still fail when their roots are
removed. Any failed gate reverts the implementation; results remain.

Use six alternating before/candidate full-LTO pairs per kernel, fib(30),
binary-trees depth 14, other original counts. Improvement is
`1 - median(candidate) / median(before)`. A regression exceeds noise if
its median loss exceeds the larger before/candidate relative min–max range
in the selected six pairs. Retain all selected launches. First size with
one pair and three warm pairs. Size the vm check with one run, then choose
repetition from its spread and distance to 1.25. Size oracle/root commands
with a single relevant case before complete batches. Build time is separate
from execution time. Every heavy command is a direct host-lock wrapper;
exit 75 means wait and retry that same command.

No compiler, specification, conformance, network, Cargo, push or PR actions.
Temporary counter sources, executables and logs use the existing ignored
benchmark target, serve only this attribution and its controls, and are
removed after retaining reproducible observations. A retained evidence JSON
in this experiment owns raw launches and counter input/output until this
comparison is superseded. Any kept representation or dispatch choice belongs
only in the Halo tree, provisionally pending the owner ruling. No approval
log is inferred from the experiment instruction.


### Lua call attribution and structural assessment

Lua's counter build selects the fib prototype by its line 2 definition,
one parameter and four registers. fib(10) gives 177 calls/returns, 531 Nil
stores and 177 result copies; fib(30) gives **2,692,537** calls/returns,
**8,077,611** Nil stores and **2,692,537** result copies. These agree with
`calls(n) = 2*F(n+1)-1`, an independent recursion-tree count. Both print the
expected 55/832040. There are zero result fills and vararg adjustments.
The full PUC run makes 2,692,537 stack checks, one stack growth and three
CallInfo growths inside fib; the small run has zero stack growth and one
CallInfo growth. Counts exclude the enclosing chunk and host calls.
The counter reports `sizeof(CallInfo)=40`, `sizeof(TValue)=16`, and
`sizeof(Proto)=120` on this ARM64 build. It links one instrumented ldo object
with the supplied unmodified Lua objects/archive; it is not a timed baseline.

Per fib invocation, the source paths perform:

| Work | Halo before | PUC Lua 5.1.5 |
|---|---|---|
| Frame | 80 bytes, 11 named field initializations: func, base, return_pc, kbase, closure, nresults, activation, flags, varbase, varcount, frame_top; passed to push_frame and copied into frame storage; taken and passed to finish on return | 40 bytes, five new-frame writes: func, base, top, tailcalls, nresults; saves caller savedpc separately; savedpc is the sixth record field |
| Function classification | One function-slot bound; Value to FuncView; iterator test; CJSON binding test | function tag, then Lua/C flag |
| Closure/prototype validation | Three closure-bound and three live tests (iterator, CJSON, entry), two native-sentinel tests, one prototype-bound test; 16-byte Proto snapshot | Direct closure/prototype pointers, with no slab/live/index tests or whole Proto copy |
| Stack/frame checks | Saturating base/room arithmetic, room sentinel, ensure_stack extent check for base+256; push_frame depth/capacity checks | luaD_checkstack for maxstack+numparams (5 slots); inc_ci capacity check |
| Arguments | zero moves, zero missing-argument fills | zero moves, clamps top to parameter end |
| Register initialization | three Nil Values, each source index guarded | three Nil tags, loop pointer bound |
| Varargs/tail adjustment | zero moves; general entry branches on both flags | zero moves; branches on is_vararg; ordinary OP_CALL |
| Return | close_upvalues, take 80-byte record; one 16-byte Value copy with source/destination bounds; protected/activation continuation checks | open-upvalue test, one TValue copy; result loop and hook checks, restores caller base/savedpc |

Halo totals follow from these source operations and the independently counted
recursion tree, not a Halo instrumentation build. These are source operations,
not a claim that every field copy survives optimization or a cycle allocation.
The retained native code reserves 464 bytes in enter_lua and 160 in push_frame;
these are native helper storage, not Lua registers. Frame layout and transport
are known, but their isolated runtime cost is still unmeasured. Startup stack
growth differs: Halo reserves a 256-slot dispatch window, PUC requests five
slots. No startup-growth count for Halo is claimed by the PUC counters.

Avoidable without weakening checked conditions: classify ordinary live Lua
closures once, retain explicit native-sentinel exclusion, prove their
prototype exists once, and enter fixed-arity calls
without transporting tail/vararg/native-path state. Frame transport might be
reduced after a separate representation/continuation comparison. Copying the
single result remains required when its source and destination differ;
removing it outright would change behavior. Missing parameters and register
initialization remain required, including their GC effects. PUC's pointer
validity assumptions are not a reason to remove Halo handle checks.

Selected single trial: a fixed-arity Lua entry helper called by ordinary
instruction_call after its existing budget and collector safepoint. It
qualifies the function Value, live closure, prototype bound and nonvararg
status once; calls outside those guards use prepare. Its missing explicit
sentinel exclusion is the defect recorded below. It retains room,
stack extent and frame-depth checks, argument padding, all Frame fields,
register clearing and the shared return path. This isolates ordinary-entry
classification and native helper traffic against the current general path.
The helper owns qualification plus fixed stack preparation; existing
push_frame remains the frame-capacity owner and finish the result owner.
A separate fast return path or smaller shared frame is viable, but would
change another measured cost, so is deferred until this comparison decides
whether ordinary entry alone meets the criterion. No public representation,
interface, collector root or language rule changes are selected.

Found during attribution: iterator classification and CJSON binding use the
same no-prototype sentinel, and prepare tests iterator classification first.
This pre-existing routing overlap is deferred in docs/todo.md; the trial
leaves the observed sentinel paths unchanged at the measured prototype counts,
but does not preserve them for every public window extent (see the sentinel
qualification defect below).


### Check sizing and candidate boundary

Before vm checks pass in 250.22 and 238.16 s: median 244.19 s, range
4.94%. Select two candidate checks initially: this spread is substantially
smaller than the 25% gate; lengthen only if the observed ratio is close enough
for it to matter. The threshold is 305.2375 s on that median. The call helper
adds no public type or new module; its stack-slot requirement is discharged
at instruction_call's existing dispatch window. The source trial changes
only calls.wf and instruction_call in handlers.wf. Invalid handles/prototypes and varargs return to the unchanged general path.
Native sentinel closures also fall back at the measured prototype counts;
the larger-window boundary is the defect below.


Candidate vm checks pass in 241.14 and 245.90 s (median 243.52 s,
relative range 1.95%), versus before 244.19 s (range 4.94%): **0.997×**,
a 0.27% median decrease, well below 1.25×. Two samples per variant suffice
for this wide margin; this does not establish a checking-speed improvement.
Early authoring commands reject comment syntax, nested constructors,
indentation and a match binder matching its field name, all exit 1; the
corrected source passes both checks. The first C counter compile rejects
stdio included after Lua's getline macro; moving the include before Lua
headers fixes it (compile/link exit 0). These failed commands and the busy
counter attempt are retained separately, outside successful check medians.


### Call-entry runtime result

Full-LTO benchmark construction passes in 547.29 s (exit 0). One pair per
kernel takes 12.41 s; the candidate's first fib launch is cold, 0.639257 s,
versus its subsequent warm median. Three warm pairs take 30.64 s (exit 0),
with fib improving 20.94% and ranges 9.89% before/0.97% candidate; this is
well separated from 10%, so select the requested six pairs. These calibration
launches remain outside the selected medians. The selected batch takes
58.39 s (exit 0). All selected launches remain in the evidence.

Process wall times include native startup, source compilation, execution and
teardown, on the recorded M1 Pro/macOS host, normal GC, unlimited budget.
Both binaries have full LTO; the before binary's source map and bytes match
the task base. The candidate source map differs only in calls.wf and
handlers.wf. Source/compiler/binary identities, individual pairs and order
are retained in [call-path-measurements.json](call-path-measurements.json).

| Kernel | Before median s | Candidate median s | Improvement | Before min–max s | Candidate min–max s | Before/candidate range |
|---|---:|---:|---:|---|---|---|
| fib | 0.197647 | 0.159160 | 19.47% | 0.196894–0.199182 | 0.157697–0.160452 | 1.16% / 1.73% |
| loop | 0.569601 | 0.568215 | 0.24% | 0.566129–0.576614 | 0.565052–0.578396 | 1.84% / 2.35% |
| integer-table | 0.568280 | 0.569914 | -0.29% | 0.560854–0.575519 | 0.549791–0.571468 | 2.58% / 3.80% |
| string-key | 0.039413 | 0.040129 | -1.82% | 0.038873–0.039832 | 0.039674–0.041803 | 2.43% / 5.30% |
| concat | 0.180638 | 0.185538 | -2.71% | 0.176327–0.188565 | 0.183825–0.187981 | 6.77% / 2.24% |
| sort | 0.727381 | 0.717749 | 1.32% | 0.713762–0.829831 | 0.714480–0.727934 | 15.96% / 1.87% |
| binary-trees | 2.466777 | 2.253587 | 8.64% | 2.448322–2.576820 | 2.238027–2.276540 | 5.21% / 1.71% |

Fib improves **19.47%**, with ranges 1.16%/1.73%, passing the 10% gate.
Integer-table loses 0.29%, string-key 1.82% and concat 2.71%; each loss is
below its larger before/candidate range, 3.80%, 5.30% and 6.78% respectively.
Thus no other kernel regresses beyond the pre-recorded guard. The wide sort
range (15.96%) and short string-key/concat spread limit any stronger statement
about those kernels. Every native/reference exit is 0; printed checksums,
zero suspensions and completed-collection counts agree. Collections remain
fib 0, loop 0, integer-table 5, string-key 0, concat 0, sort 3 and trees 176.

This measures the combined fixed-entry qualification and helper-traffic
change; it does not isolate repeated-check removal from native storage,
branching or code-layout effects. Return and frame transport remain unchanged.
The runtime and module-check gates pass; completed behavior/root gates are
recorded below. The sentinel qualification defect prevents keeping the trial.
The oracle host uses the existing module cache for correctness builds, not
for performance measurements; all timed benchmark binaries use full LTO.


### Sentinel qualification defect found before selection

The trial guards the closure's prototype only with `pi < vm.protos.len`.
That excludes the native sentinel on the measured scripts, but is not the
same predicate as prepare's explicit sentinel classification. `Vm.protos`
is a public u64-length window (`vm/module.wfm`), and no entry contract caps
it below `no_handle`. A live closure with proto `no_handle` and a window
containing that index can therefore enter the fixed Lua path instead of
prepare's native path. The source-level witness is this state relation,
independent of whether this 32 GiB host can allocate that window. No such
large allocation is attempted, and the corpus does not observe this boundary.

The measured trial is therefore **ineligible and reverted**:
runtime and check-time successes cannot substitute for preservation of
routing conditions. Removing repeated classification remains a viable future
trial with an explicit native-sentinel exclusion before prototype lookup;
this result does not reject that guarded design. The requested root
controls were completed on the measured trial, then the original call code
was restored. A second
performance candidate is outside this single bounded comparison. Record the
missing predicate and its required follow-up in the existing Halo TODO.


### Call behavior, root controls and reversion

The cached oracle host builds in 540.20 s (exit 0), using the measured trial's
library bytes and the unchanged host. Before full batches, counter-closure
passes 3/3 ordinary in 0.62 s and 3/3 stress in 0.21 s. Ordinary **240/240**
and GC-stress **240/240** comparisons then pass (1.23 and 1.34 s, exits 0),
at budgets 1, 7 and 1000: 80 distinct scripts at three budgets. All 480
actual typed replies and all report rows were independently checked against
the original expected bytes. Stress reports 20,450 collections per budget;
ordinary reports zero. These are behavior timings, not performance pairs.

The existing local root cases pass 9/9 at stress and the three budgets.
The sole-frame probe passes 1/1 at budget 1 with `--isolate-frames`, and the
parked-stack probe passes 1/1 with `--collect-suspended`. Each removal below
retains the same script and expected reply. Collector mutants remove one
marking call at a time; original collector bytes are hash-verified between
mutants. The parked-root control uses the existing harness flag.

| Removed root | Positive observation | Removal observation | Runner exit |
|---|---|---|---:|
| Open upvalues | `kept` at all three budgets | `wrong` at all three budgets, 3 collections each | 1 |
| Frame closure | `qqq`, isolated budget 1 | `invalid upvalue index`, 9 collections | 1 |
| Constants | original stress corpus 240/240 | 90/240 pass, 150 failures; sizing hash-cas fails during setup with native exit 4 | 1 |
| Parked stack | `zzz`, synthetic collection at budget 1 | function-index error at user_script:5, 5 collections | 1 |

Mutant constructions exit 0 in 564.49, 563.76 and 602.83 s for open,
frame and constants. Constant sizing takes 0.52 s (expected exit 1), then
its full 240-comparison negative batch takes 1.45 s (expected exit 1).
Replies, single-call source patches, input/binary hashes and reports are
retained in the raw JSON. The three root probe scripts and all original
oracle expectations remain byte-identical. These controls detect the selected
omissions; they do not establish every-allocation reachability.

**Reverted.** calls.wf and handlers.wf are restored byte-for-byte from task
base 8f69de695; collect.wf is restored from its original bytes. Every retained
baseline benchmark input hash and every library-source hash agrees again.
No compiler, specification, conformance, runtime, gate, fixture or tree change
survives. No rule has changed before/after behavior in the delivered source.
There is no kept Halo decision, no open decision card and no approval log.

Found along the way: repeated entry work is attributed, but its guarded
replacement remains a follow-up; explicit sentinel exclusion is required by
this source audit. The existing Halo performance TODO records that comparison
and the unchanged 80-byte frame/result transport costs. A separate TODO
records the iterator/CJSON sentinel routing overlap and its required minimal
executable witness. The isolated contributions of checks, helper storage,
branching and native layout remain uncertain. The native inspection finds no
separate enter_fixed_lua symbol (objdump exits 0 but warns that the symbol is
missing); no standalone candidate helper stack size is claimed.

### Call experiment commands and limits

Every heavy command below is a direct host-lock wrapper. Complete expanded
commands, exits, wall times and authoring failures are retained in the raw
JSON's `commands`. `<PUC_LUA>` is the supplied unmodified interpreter,
`<PUC_SOURCE>` its source directory; native temporaries use this experiment's
existing ignored target. Successful native constructions/checks exit 0;
root omission comparisons exit 1 as intended.

```sh
perl .github/run-check.pl halo-call-counter-compile clang -O2 -I <PUC_SOURCE> -c research/experiments/halo-bench/target/call-counter/ldo.c -o research/experiments/halo-bench/target/call-counter/ldo.o
perl .github/run-check.pl halo-call-counter-link clang -o research/experiments/halo-bench/target/call-counter/lua <PUC_SOURCE>/lua.o research/experiments/halo-bench/target/call-counter/ldo.o <PUC_SOURCE>/liblua.a -lm
perl .github/run-check.pl halo-call-counter-full research/experiments/halo-bench/target/call-counter/lua research/experiments/halo-bench/kernels/fib.lua
perl .github/run-check.pl halo-call-check-before compiler/target/gate/whitefootc --graph lib/halo/modules.wfg --check-module pkg::vm
perl .github/run-check.pl halo-call-bench-build compiler/target/gate/whitefootc --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo-call
perl .github/run-check.pl halo-call-six python3 -B research/experiments/halo-bench/run.py --lua <PUC_LUA> --before-binary research/experiments/halo-bench/target/halo-table --binary research/experiments/halo-bench/target/halo-call --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees --scale binary-trees=14 --runs 6 --out research/experiments/halo-bench/target/call-six.json
perl .github/run-check.pl halo-call-e2e-build compiler/target/gate/whitefootc --graph research/experiments/halo-e2e/modules.wfg --entry test --cache research/experiments/halo-bench/target/frame-gc-cache -o research/experiments/halo-bench/target/call-e2e
perl .github/run-check.pl halo-call-oracle python3 -B research/experiments/halo-e2e/run.py --compiler compiler/target/gate/whitefootc --binary research/experiments/halo-bench/target/call-e2e --scratch-root research/experiments/halo-bench/target --budgets 1,7,1000 --actual research/experiments/halo-bench/target/call-actual-ordinary --report research/experiments/halo-bench/target/call-oracle.md
```

For the second before check, both candidate checks and all sizing pairs, use
the raw JSON's corresponding labels, outputs and committed source states.
The counter patch there reconstructs ldo-counter.c from the hashed supplied
ldo.c; its fib(10) input replaces only N=30 with N=10. For oracle stress add
`--gc-stress` and distinct report/actual paths. For local roots add
`--cases research/experiments/halo-gc/cases`; the raw commands state each
filter, budget and isolation/checkpoint flag. For each collector mutant,
apply only its retained patch to collect.wf, build with the same cached oracle
command under its own label/output, run its unchanged witness, then restore.
The frame flag is `--isolate-frames`; the parked omission adds
`--collect-suspended --omit-suspended-root` at stress, budget 1. Constant
removal uses the original full stress corpus after the one-case sizing run.

Six busy attempts exit 75 before later retries: counter compilation, two
oracle sizing attempts, the frame probe, one premature constant-build attempt,
and constant sizing. No busy wrapper starts a child. After the frame probe's
75, dependent preparation was attempted too early; its missing-reply assertion
stopped before source mutation, and the premature constant wrapper also
returned 75. The collector remained the frame mutant, verified by hash. After
waiting, the frame probe was retried successfully as a negative control;
only then was the collector restored and the constant mutation built. The
sequence error is retained, rather than described as a clean first attempt.
Other authoring rejections are recorded outside successful medians: C include
placement, canonical WF syntax/trivia/binder spelling, and a doc token in a
mutant loop body, all exit 1 before their corrected commands pass.

Unverified: execution of the large prototype-window boundary, precise cycle
shares and isolated contribution of each entry cost, a repaired sentinel
predicate's performance, other hosts/compilers, depth-16 trees, budgeted kernel
performance, full every-allocation GC reachability, canonical make check and
CI. Cargo and network are excluded; no push, PR or merge action is used.


The first form-lint sample (`make design-lint`) passed but was inadvertently
invoked without an outer host-lock wrapper. This execution error is excluded
from locked timing claims and repeated under `perl .github/run-check.pl
halo-call-design-lint make design-lint`. No performance or compilation stage
was concurrent in this worktree; activity elsewhere during that unwrapped
sample is not established. The record does not present it as a locked run.


## Sentinel-qualified fixed Lua entry repeat

### Repeat criterion recorded before measurement

Task base: `b374e880e6749fe5d1a0e4a40b0b2187f52f63b0`. Repeat the reverted entry helper with an explicit
`proto != no_handle` guard before prototype lookup, independent of prototype
window length. Every native, invalid-callee and vararg miss retains `prepare`;
room, frame-depth and dispatch window facts, roots and return handling remain.
Keep only if fib(30) improves at least 10% in six interleaved full-LTO pairs
against this base, no other kernel regresses beyond noise, median
`--check-module pkg::vm` time is at most 1.25 times before, ordinary and
GC-stress oracle batches each pass 240/240 at budgets 1, 7 and 1000, every
existing removed-root control fails as required, and a new ordinary-CALL
witness for native (including sentinel closure), invalid and vararg callees
retains the independently specified reply on before and candidate.

Noise means a median loss exceeding the larger variant's relative min–max
range in the selected six pairs, as in the prior trial. Use all seven kernels,
binary-trees depth 14 and the original remaining counts; retain launches,
checksums and GC counts. Size with one pair then three warm pairs; size each
check/build with its smallest useful existing entry and each behavior batch
with one relevant case. Use two module-check samples initially, lengthening
only near the 1.25 threshold or if spread prevents a decision.

The helper owns qualification and fixed stack preparation; existing
`push_frame` owns frame capacity and `finish` owns results. Changing frames,
return handling or public representation would mix another cost into this
comparison and remains deferred. This preserves the C1 window contracts and
shared frame-changing epilogue. The owner's task selects this bounded
direction; any kept decision belongs in the Halo tree, pending its ruling.

No network, Cargo, push or PR actions. All heavy commands use their own
direct host-lock wrapper and retry exit 75 after waiting. Scratch sources,
logs, binaries and probes live in the existing ignored benchmark target and
are removed after retaining their evidence; `fixed-call-measurements.json`
in this experiment retains raw observations until this repeat is superseded.
On any failed criterion, restore source bytes to the task base and commit
the reversion while retaining the results.


### Repeat baseline sizing and routing assessment

Baseline module checks pass in 296.96 and 263.13 s (wrapper wall),
median 280.045 s, relative range 12.08%.
Two candidate checks are selected initially; the threshold is 350.0562 s.
The first baseline command started after the criterion file was written but
before its milestone commit: Git staging initially failed (exit 128) because the
linked worktree metadata is outside the sandbox. Local Git authorization
then permitted the milestone; no network or publication was attempted.

The candidate checks `proto != no_handle` before conversion and lookup, so
for every u64 prototype-window length the sentinel returns `None` and enters
unchanged `prepare`. Builtin and nonfunction tags, out-of-range/dead handles,
invalid prototypes and varargs also return `None` without stack/frame changes.
The ordinary call retains its budget charge and collector safepoint. Its
function-slot fact follows from the existing 256-slot dispatch precondition;
the shared `checked_step` still establishes the next code/stack/constants
windows before C1 dispatch. No public type, frame, root or return path changes.

The scratch fallback witness expects `[17, "a", 0, 1, 0, 1, 21]`: `math.abs`,
a sentinel-backed gmatch iterator, number and nil call failures (with their
message classes), and a vararg argument count. Each callee is invoked as
`local result = f(a, b)`, forcing ordinary CALL rather than a tail call.
The independently stated typed reply passes 3/3 on the verified before
correctness binary; stress and candidate observations are recorded below.
The script and expected bytes are retained in the raw JSON and leave the
original oracle untouched. The pre-existing CJSON/iterator sentinel overlap
remains recorded in TODO and the general routing order remains unchanged.


### Repeat module-check result

Candidate checks pass in 278.31 and 284.70 s, median 281.505 s
(relative range 2.27%), versus before 280.045 s:
**1.0052×**, +0.52% median change. Even the slower candidate
against the faster baseline is 1.0820×, below 1.25.
The samples are sufficient for this threshold; no checking-speed improvement
is established. Baseline stress fallback replies pass 3/3, with 17 collections
each; PUC's bytecode listing confirms ordinary CALL in the invocation helper.
The baseline stress runner's current-input digest names candidate sources,
but executes the separately hash-verified before binary; it is not a build
identity. This reused-binary reporting limitation is recorded in TODO.

A single full-LTO benchmark construction is the smallest executable sample
for this comparison; do not batch or repeat constructions without a failure.
Execution is sized separately after that construction.


### Repeat runtime sizing

Full-LTO benchmark construction passes in 561.64 s, exit 0. The one-pair
launch sample takes 13.10 s and the three warm pairs 31.25 s, exits 0.
Warm fib improves 20.08% with before/candidate relative ranges
3.23%/0.52%; select the six requested interleaved
pairs. Sizing remains outside selected medians. Every sizing checksum agrees
with PUC. Some other-kernel sizing losses are close to their ranges; the six
pairs, not these sizing results, determine the fixed noise gate.

All library/runtime and benchmark/oracle host inputs are unchanged between
the retained baseline construction revision and the task base. Compiler
source has advanced, but the supplied compiler executable hash matches the
baseline, and its native runtime sources are embedded with `include_str!`.
Both variants use that executable; it is not rebuilt at current source HEAD.
The source/binary maps and broader input audit are retained in the raw JSON.


### Repeat six-pair runtime result

Selected six-pair batch: 59.60 s, exit 0. Process wall times include startup,
Lua source compilation, execution and teardown, M1 Pro/macOS, normal GC,
unlimited budget. Both benchmark binaries use full LTO and the same supplied
compiler; their inputs and all selected launches are retained in
[fixed-call-measurements.json](fixed-call-measurements.json).

| Kernel | Before median s | Candidate median s | Improvement | Before min–max s | Candidate min–max s | Before/candidate range |
|---|---:|---:|---:|---|---|---|
| fib | 0.202835 | 0.164326 | 18.99% | 0.200329–0.204864 | 0.159018–0.270310 | 2.24% / 67.73% |
| loop | 0.581221 | 0.582421 | -0.21% | 0.569314–0.592788 | 0.565982–0.634371 | 4.04% / 11.74% |
| integer-table | 0.596881 | 0.595351 | 0.26% | 0.579897–0.621996 | 0.581595–0.612972 | 7.05% / 5.27% |
| string-key | 0.039602 | 0.039761 | -0.40% | 0.039160–0.039921 | 0.038994–0.040081 | 1.92% / 2.73% |
| concat | 0.182877 | 0.184112 | -0.68% | 0.177550–0.185815 | 0.176211–0.185361 | 4.52% / 4.97% |
| sort | 0.763706 | 0.757662 | 0.79% | 0.738119–0.816155 | 0.740026–0.778439 | 10.22% / 5.07% |
| binary-trees | 2.481454 | 2.266137 | 8.68% | 2.475321–2.483546 | 2.260854–2.266970 | 0.33% / 0.27% |

Fib improves 18.99%, passing 10%. Every other loss is below
the larger relative range: the runtime noise gate passes. Every native and
PUC exit is 0, printed checksums agree, suspensions are zero, and paired GC
counts agree. Two fib candidate launches (0.270310 and 0.208316 s) are
slower than the remaining four (0.159018–0.166682 s); their causes are
unmeasured and every launch is retained, not discarded. Leaving out any
one pair gives 17.64–20.32% fib median improvement, an exploratory robustness
observation, not a replacement selection batch. Loop and sort also have wide
spread, limiting stronger performance claims. This measures the combined
entry qualification/helper and code-layout change, not isolated cycle shares.
The check-time and runtime gates pass; selection awaits behavior/root gates.
For the subsequent selection verdict, see the [14900K repeat](#14900k-repeat-with-wf-e1708490c384).


### Repeat correctness construction and sizing

The candidate oracle host builds in 521.32 s, exit 0, from the measured
candidate library bytes. It uses the existing module cache for behavior
checks only; all benchmark pairs use full LTO. The counter-closure sample
passes 3/3 ordinary in 0.42 s and 3/3 at stress in 0.21 s, exits 0, at
budgets 1, 7 and 1000. These samples justify the complete batches. Build,
source and binary hashes and sample reports are retained in the raw JSON.


### Repeat correctness gates on Halo-wf

Checked on x86-64 Linux (GitHub `ubuntu-24.04`, release `wf-648338c31240`)
at `3c3926fc2`: the candidate entry, now selecting by the closure's explicit
callee kind (`6f050f3d6`), merged with Halo-wf main `526f67bef`.

- Oracle, `make check` (run 37531183552): the embedding probe passes, and 92
  scripts at budgets 1, 7 and 1000 pass 276/276 ordinary and 276/276 under
  collector stress.
- Removed-root controls (`.github/workflows/fixed-call-gates.yml`, run
  37531185040; logs in its artifact). Each mutant removes one marking line of
  `mark_roots` and is rebuilt; the parked-root control uses the harness flag.

| Root | Positive observation | Removal observation | Runner exit |
|---|---|---|---:|
| Open upvalues | `kept`, budgets 1, 7, 1000 at stress | 0/3: reply differs | 1 |
| Frame closure | `qqq`, isolated, budget 1 | 0/1: `invalid upvalue index` | 1 |
| Constants | stress corpus 276/276 | 99/276 pass, 177 fail | 1 |
| Parked stack | `zzz`, collected while parked, budget 1 | 0/1: `attempt to index a function value` | 1 |

- Call-kind witness: the scratch witness is now the oracle script
  `lua-core/call-kinds`. Its first form matched the error text Halo prints;
  Redis 7.0.15 names the variable ("attempt to call local 'f' (a number
  value)", run 37529328302), a known gap in `docs/todo.md`. The script now
  matches the error's kind and value type, and its reply recorded on the
  reference platform (run 37530330415) is `[17, "a", 0, 1, 0, 1, 21]`.
  Before (main `526f67bef`) and candidate each pass 3/3 ordinary and 3/3 at
  stress.

The behavior and root gates pass. The runtime and check-time gates stay as
measured on the M1 Pro above until the 14900K repeat, which waits for that
runner's move to clang 22 so the result holds for the toolchain that follows.
That repeat is now recorded [below](#14900k-repeat-with-wf-e1708490c384), including the failed criterion and reversion.


### 14900K repeat with wf-e1708490c384

The repeat ran on the owner's i9-14900K CI runner, x86-64 Linux
6.8.0-142-generic with glibc 2.39, in
[run 37547846309](https://github.com/Ming-Research/Halo-wf/actions/runs/37547846309).
The `STEP: compare` workflow at
[`c35c53b59`](https://github.com/Ming-Research/Halo-wf/blob/c35c53b594ec4a3fb412224bb1b6c150af087200/.github/workflows/bench-14900k.yml)
built both entry-comparison binaries with full LTO, Whitefoot release
`wf-e1708490c384` (built with LLVM 22), `/usr/bin/clang` 22.1.8 and LLD
22.1.8. The before binary, `halo-after-upgrade`, uses main source
`526f67befe929bfdb33513a0c557d832d4868c43`; `halo-entry` uses branch
`c35c53b594ec4a3fb412224bb1b6c150af087200`. Thus this repeats the criterion
against the merged main baseline, rather than the original task base. The
branch also contains number-library and gate changes; of the kernels, only
binary-trees reaches the number library, through `^` (`pkg::number::pow`,
whose NaN handling changed), and its ratio stayed within noise; Lua's `%`
in sort uses `ffloor` directly. This is the candidate comparison,
not an attribution of isolated entry costs.

The run's `halo-bench-compare` artifact holds `manifest-after.txt`,
`entry-{1,3,6}.json`, `upgrade-{1,3,6}.json`, their logs and
`check-times.txt`. The manifest maps sources and compiler releases to the
executables; the JSON's current checkout revision alone is not a binary's
build provenance. Recorded SHA-256s:

| Executable | SHA-256 |
|---|---|
| `wf-e1708490c384/whitefootc` | `a413e443c702681c931635cae9a536682591b0d47ef2a5e702cdf60f6779400e` |
| `halo-after-upgrade` | `ac982b1843b33a24485c6658d480c71a63ba2eaf525ff9bb8a9f259378e8cbe5` |
| `halo-entry` | `9d3ecfac06a29204518c594ba6f63a27da477f9c3f50d8d9a1c3c3b6c02bd7f5` |

The workflow first prepares the pinned compiler with `make compiler`, checks
the host toolchain with `make toolchain-check`, fetches Redis 7.0.15's Lua
with `sh research/experiments/halo-oracle/fetch-redis.sh "$PWD/build/redis"`,
and archives the main baseline into `build/main-src`. Its build and timing
commands are reproduced below; the workflow also records each command's
logs and stops on failure. `compare upgrade` runs before `compare entry`.

```sh
release=wf-e1708490c384
wfc="$PWD/build/whitefoot/$release/whitefootc"
out="$PWD/build/bench-out"
lua="$PWD/build/redis/redis-7.0.15/deps/lua/src/lua"
"$wfc" --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o "$out/halo-entry"
(cd build/main-src && "$wfc" --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o "$out/halo-after-upgrade")
kernels=fib,loop,integer-table,string-key,concat,sort,binary-trees
compare() {
  label=$1; before=$2; after=$3
  for runs in 1 3 6; do
    python3 -B research/experiments/halo-bench/run.py --lua "$lua" \
      --before-binary "$before" --binary "$after" --kernels "$kernels" \
      --scale binary-trees=14 --runs "$runs" --out "$out/$label-$runs.json" --compiler "$wfc" \
      > "$out/$label-$runs.log" 2>&1 || { cat "$out/$label-$runs.log"; exit 1; }
  done
}
compare upgrade "$out/halo-before-upgrade" "$out/halo-after-upgrade"
compare entry "$out/halo-after-upgrade" "$out/halo-entry"
TIMEFORMAT=%R
for sample in 1 2; do
  for side in main entry; do
    dir=build/main-src; [ "$side" = entry ] && dir=.
    seconds=$( { time (cd "$dir" && "$wfc" --graph lib/halo/modules.wfg --check-module pkg::vm > "$out/check-$side-$sample.log" 2>&1); } 2>&1 )
    echo "check-module pkg::vm $side sample $sample: $seconds s" | tee -a "$out/check-times.txt"
  done
done
```

One sizing pair and three warm pairs precede each selected six-pair batch;
they are not pooled into the selected medians. The entry batch starts at
`2026-10-07T00:09:41Z`. Process wall times include startup, Lua compilation,
execution and teardown, with normal GC and unlimited budget. Launch order
alternates before/after and after/before. Binary-trees uses depth 14; the
other kernel counts are unchanged. In `entry-6.json`, ratio is candidate
median / main median; each relative range is `(maximum - minimum) / median`.

| Kernel | Main median s | Entry median s | Entry/main ratio | Main relative range | Entry relative range |
|---|---:|---:|---:|---:|---:|
| fib | 0.102447 | 0.100728 | 0.983 | 1.647% | 1.995% |
| loop | 0.436116 | 0.435895 | 0.999 | 2.010% | 0.768% |
| integer-table | 0.591408 | 0.593963 | 1.004 | 1.458% | 1.642% |
| string-key | 0.033935 | 0.033974 | 1.001 | 3.394% | 2.787% |
| concat | 0.101048 | 0.100705 | 0.997 | 0.698% | 0.952% |
| sort | 0.726625 | 0.734516 | 1.011 | 0.764% | 0.978% |
| binary-trees | 2.086497 | 2.108678 | 1.011 | 1.482% | 1.549% |

**The retention criterion fails.** Fib improves only 1.678% (about 1.7%),
below the required 10%. The earlier M1 Pro result (-18.99% time) was not
reproduced on this host and compiler; this comparison does not establish
why. The other-kernel noise gate also fails: sort's median loss is 1.086%,
exceeding the larger of its two relative ranges, 0.978%. Integer-table's
0.432%, string-key's 0.114% and binary-trees' 1.063% losses are below their
respective larger ranges; loop and concat improve. This applies the recorded
noise definition using unrounded JSON values. It corrects the reversion
commit message's claim that all other kernels stayed within noise.

The interleaved module-check samples in `check-times.txt` are main
7.158 / 7.163 s and entry 7.252 / 7.143 s. Their medians are 7.1605 and
7.1975 s, respectively: 1.0052×, within the 1.25× limit. The two samples
per side suffice for this threshold. All selected benchmark and independent
PUC reference exits are zero, checksums agree, suspensions are zero and
paired GC counts agree. The full oracle and removed-root gate passes remain
the earlier results at `3c3926fc2`
([correctness gates](#repeat-correctness-gates-on-halo-wf)); this benchmark
run does not rerun those gates or validate the subsequent reversion.

Under the pre-recorded rule to revert on any failed criterion, commit
[`46cad3c17`](https://github.com/Ming-Research/Halo-wf/commit/46cad3c17e4e96e174eaa37582cb7d58d82bb872)
removed `enter_fixed_lua` and restored ordinary CALL's direct `prepare` path
in `calls.wf` and `handlers.wf`, retaining this branch's later operand-error
description changes. The fixed-entry change is reverted; its measurements
remain as evidence.


## Whitefoot wf-e1708490c384 upgrade comparison

The same [14900K run](https://github.com/Ming-Research/Halo-wf/actions/runs/37547846309)
also records the compiler-upgrade comparison required by
[downstream.md, upgrade step 5](../../../whitefoot-kit/downstream.md#upgrading-whitefoot).
Both sides use main source `526f67bef` and full LTO. The before executable,
`halo-before-upgrade`, was built by
[run 37543253469](https://github.com/Ming-Research/Halo-wf/actions/runs/37543253469)
with `wf-648338c31240`, clang 18.1.3 and LLD 18.1.3, then downloaded for
this run. Its SHA-256 is
`b1558f4c72ce5e53d448a6af17ddd0cdd2c6851a74e459bb90d80328ee9b0c7e`;
the old compiler's is
`07b0969d5b1b6d761321f04153c6990e307c9cd30e2b14f1f2405f12891e4171`.
The after executable is `halo-after-upgrade`, built with
`wf-e1708490c384`, clang/LLD 22.1.8 as identified above. Both build steps use
`--graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto`.

`upgrade-6.json` (batch start `2026-10-07T00:08:13Z`) supplies these selected
six-pair results after one sizing pair and three warm pairs, with the same
host, commands, kernel sizes, normal GC and unlimited budget described above.
Ratio is after median / before median; ranges use each side's own median.

| Kernel | Before median s | After median s | After/before ratio | Before relative range | After relative range |
|---|---:|---:|---:|---:|---:|
| loop | 0.499451 | 0.436068 | 0.873 | 0.517% | 0.737% |
| fib | 0.106292 | 0.102975 | 0.969 | 3.306% | 2.404% |
| sort | 0.747802 | 0.725945 | 0.971 | 0.569% | 0.412% |
| binary-trees | 2.140436 | 2.079276 | 0.971 | 1.400% | 0.961% |
| integer-table | 0.603874 | 0.595150 | 0.986 | 2.299% | 2.059% |
| concat | 0.101707 | 0.100784 | 0.991 | 1.154% | 1.013% |
| string-key | 0.033770 | 0.033947 | 1.005 | 3.953% | 1.373% |

All selected benchmark and independent PUC reference exits are zero,
checksums agree, suspensions are zero and paired GC counts agree. There is
no twin-of-base noise control, and both Whitefoot and clang/LLD changed.
These observations report only the upgrade's combined effect on these
kernels on this host; they do not isolate Whitefoot's contribution or
establish a causal explanation for individual changes.

## Operand descriptions' cost

### Criterion recorded before measurement

Question: do the runtime type errors' operand descriptions (design node
`design/halo/operand-names.md`) slow ordinary execution? Their handlers pass
the faulting operand's register to the slow executor, and the compiler keeps
local-variable ranges and upvalue names; the description itself is computed
only when an error is raised, which no kernel does.

Comparison: on the 14900K, Halo-wf main `526f67bef` and the branch head that
adds the descriptions, both built with full LTO by the pinned release
`wf-e1708490c384` and clang 22, run as interleaved pairs over all seven
kernels (binary-trees depth 14), one sizing pair, three warm pairs, then six
selected pairs; a copy of main's binary run against main the same way is the
twin that measures noise. Then two interleaved `--check-module pkg::vm`
samples per side. Workflow: `.github/workflows/bench-14900k.yml` at the
measured head.

Rejected if any kernel's six-pair median is slower than main's by more than
the larger of the two variants' relative min–max ranges in those six pairs
and more than the twin shows for that kernel, or if the median module-check
time exceeds 1.25 times main's. A rejection is investigated before the
change is kept.

### First run stopped by the same-work guard

[Run 37553543866](https://github.com/Ming-Research/Halo-wf/actions/runs/37553543866)
at `c4ab50d03` completed the twin's 1, 3 and 6 pairs, then stopped in the
first operand-description pair: `run.py` refuses a pair whose collection
counts differ, and binary-trees collected 176 times on main and 178 on the
branch. The other six kernels' counts agreed. The branch also adds the
`_VERSION` global, a one-time allocation at engine creation, and the
compiler's local-variable records live outside the Lua heap, so the
hypothesis is that the difference is a shift in the collector's timing, not
added allocation per operation.

Second run, recorded before it ran: the timing criterion above is evaluated
on the six kernels whose counts agree; and each binary runs binary-trees once
at depths 12, 13, 14, 15 and 16 (`local N` replaced), recording its
collection count. The hypothesis is rejected if the branch's extra
collections grow with depth (roughly with the work) rather than staying
within a few collections at every depth; a rejection is investigated before
the change is kept.

### Second run and the third run's hypothesis

[Run 37554171249](https://github.com/Ming-Research/Halo-wf/actions/runs/37554171249)
at `987cb9435`, six selected pairs (branch median / main median; relative
ranges main, branch):

| Kernel | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|
| fib | 1.018 | 2.25% | 1.91% | 0.994 |
| loop | 1.002 | 0.27% | 0.61% | 1.000 |
| integer-table | 1.004 | 1.40% | 2.17% | 0.996 |
| string-key | 0.990 | 4.15% | 0.89% | 1.000 |
| concat | 0.999 | 1.11% | 1.37% | 1.001 |
| sort | 1.022 | 1.12% | 0.34% | 1.002 |

Sort is 2.2% slower, beyond both its 1.12% range and the twin's 0.2%, so the
criterion rejects the change as measured; fib's 1.8% is inside its range.
`--check-module pkg::vm` took 7.407 and 7.402 s against main's 7.198 and
7.174 s (1.03 times). Binary-trees' collection counts, main then branch:
depth 12, 144 and 142; 13, 152 and 154; 14, 176 and 178; 15, 186 and 186;
16, 214 and 212. The difference stays within two collections and does not
grow with the work, so the timing-shift hypothesis stands.

Third run, recorded before it ran: the change inserted its three debug-data
fields into the `Vm` record after `source`, ahead of fields the dispatch and
the library touch on every call (`top`, `budget`, `saved_pc`,
`callback_plan` and the rest after `source`), moving each by three box
widths. Hypothesis:
that shift, not added work, slows sort. The third run repeats the second
after moving the three fields to the end of `Vm`. The hypothesis is rejected
if sort stays slower than main beyond the same bounds; the next suspect is
then `sort_compare`'s larger slow branch.

### Third run and the phase localization

[Run 37555046795](https://github.com/Ming-Research/Halo-wf/actions/runs/37555046795)
at `f2bf5b6e4`, with the three fields at the end of `Vm`, six selected pairs:

| Kernel | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|
| fib | 1.017 | 8.12% | 2.00% | 0.998 |
| loop | 0.999 | 0.53% | 0.43% | 1.001 |
| integer-table | 0.992 | 2.00% | 0.90% | 0.998 |
| string-key | 0.991 | 2.04% | 5.60% | 1.000 |
| concat | 1.002 | 0.98% | 1.26% | 0.992 |
| sort | 1.016 | 0.82% | 0.46% | 0.999 |

Sort is still 1.6% slower, beyond its 0.82% range and the twin's, so the
field-shift hypothesis is rejected. Module check 7.329 and 7.362 s against
7.130 and 7.134 s (1.03 times); binary-trees' collection counts repeat the
second run's.

Fourth run, recorded before it ran: sort.lua has three phases, building the
table (`*`, `%`, table writes), `table.sort` (the library's `sort_compare`,
whose slow branch grew) and the check loop (a native `assert` call per
element, through the call path and the builtin dispatcher, which both
changed). Each binary runs three cumulative prefixes of the kernel (build;
build and sort; the whole kernel) in eight interleaved launches each, and the
phase cost is the difference of medians. The phase whose cost rises by most
of sort's 1.6% (about 12 ms) is the one to repair; if none does, the
difference is not localized by phase and the next step is a code-layout
comparison.

### Phase result and the `_VERSION` hypothesis

[Run 37555535049](https://github.com/Ming-Research/Halo-wf/actions/runs/37555535049),
eight interleaved launches of each prefix, medians main then branch: build
0.0376 and 0.0383 s; build and sort 0.6498 and 0.6886 s (+6%); the whole
kernel 0.7298 and 0.7438 s (+1.9%). The prefixes do not add up: the check
loop alone would be 25 ms faster on the branch, which no change to its path
explains. A difference that depends on where the run stops points to the
collector's timing, which binary-trees' shifted counts already showed, rather
than to a per-operation cost.

Fifth run, recorded before it ran. Hypothesis: the `_VERSION` global, a
one-time allocation at engine creation that PUC also makes, shifts when
collections run and how much they find live; the operand descriptions add no
cost. Three binaries: main, main with only the `_VERSION` change (the
branch's diff of `lib/halo/vm/library.wf` applied to main), and the branch.
Each runs the three prefixes in eight rotating launches, recording time and
collection count; then `run.py` compares the branch against main with
`_VERSION` over the six kernels, one, three and six pairs, under the
criterion above; then binary-trees' collection counts at depths 12 to 16 for
those two. The hypothesis is rejected if main with `_VERSION` stays as fast
as main where the branch is slower, or if the branch is slower than main
with `_VERSION` beyond the criterion's bounds; the noise twins of the second
and third runs (all kernels within 0.8%) stand for this run's.

### Fifth run: `_VERSION` explains the collection counts, not all of sort

[Run 37556088935](https://github.com/Ming-Research/Halo-wf/actions/runs/37556088935).
Binary-trees' collection counts of main with only the `_VERSION` change equal
the branch's at every depth (142, 154, 178, 186 and 212 against main's 144,
152, 176, 186 and 214), so the one-time allocation alone shifts them. Sort's
prefixes, medians of main, main with `_VERSION` and the branch, all with three
collections: build 0.0382, 0.0379 and 0.0381 s; build and sort 0.6489,
0.6574 and 0.6866 s; the whole kernel 0.7282, 0.7346 and 0.7407 s. Against
main with `_VERSION`, six pairs: fib 1.016 (ranges 1.64% and 1.18%), loop
1.002, integer-table 1.001, string-key 1.000, concat 1.001 and sort 1.011
(ranges 0.46% and 0.53%). `_VERSION` accounts for the collection shift and
part of sort's difference; the branch's own code still makes sort 1.1%
slower, beyond its ranges, and the sort phase is where it differs most.

Sixth run, recorded before it ran: the branch grew `sort_compare`'s slow
branch, the code that remains of the change on the sort phase's path. The
sixth run repeats the fifth after moving that branch's body into its own
function, `sort_compare_slow`, so `sort_compare` has main's shape. The
change is kept if sort against main with `_VERSION` is then within the
criterion's bounds; if not, the remaining difference is reported to the
owner with these measurements rather than chased further in this change.

### Sixth run and the verdict

[Run 37556822953](https://github.com/Ming-Research/Halo-wf/actions/runs/37556822953)
at `e2bf5852a`, after the `sort_compare_slow` split. Against main with
`_VERSION`, six pairs: fib 1.020 (ranges 11.75% and 2.01%), loop 0.998,
integer-table 0.996, string-key 1.002, concat 0.997 and sort 0.755 (ranges
0.53% and 0.68%). Sort's prefixes, medians of main, main with `_VERSION` and
the branch, three collections each: build 0.0381, 0.0378 and 0.0387 s; build
and sort 0.6515, 0.6592 and 0.5057 s; the whole kernel 0.7285, 0.7356 and
0.5542 s. Binary-trees' collection counts repeat the fifth run's. Outputs and
checksums agreed throughout.

**The runtime part of the criterion passes.** No kernel is slower than its
baseline beyond the bounds, and the collection shift and part of the earlier
sort difference belong to the `_VERSION` global, which PUC also allocates.
The module check was last measured at `f2bf5b6e4` (1.03 times), before the
split; the final head's is measured in the seventh run.

Sort ran 24.5% faster than main with `_VERSION` in this run. The fifth and
sixth runs compare against the same baseline source and differ on the branch
only by the split, which moved `sort_compare`'s call to the slow executor
into a function of its own (sort 1.011 then 0.755), but they were not
interleaved with each other and had no twin, so they do not attribute the
speedup to the split.

Seventh run, recorded before it ran: the source before the split
(`f70f0a8af`) and after it (the head; the two differ in
`lib/halo/vm/library-sort.wf` only), built alike, run as interleaved
`run.py` pairs on the sort kernel (one, three and six pairs), with a copy of
the pre-split binary as the twin; then two interleaved `--check-module
pkg::vm` samples each for main and the head. The split's speedup is
attributed if the post-split median is faster than the pre-split one by more
than both ranges and more than the twin's difference; the module-check part
of the criterion passes at the head if its median is at most 1.25 times
main's.

### Seventh run: the split's share and the head's check time

[Run 37557695747](https://github.com/Ming-Research/Halo-wf/actions/runs/37557695747)
at `22aadda57`. The pre-split (`f70f0a8af`) and post-split (head) sources
differ in `lib/halo/vm/library-sort.wf` only, as the run's own `git diff
--stat` showed. Sort kernel, six interleaved pairs: pre-split median
0.7406 s (range 0.39%), post-split 0.5530 s (range 0.80%), ratio 0.747; the
twin, the pre-split binary against its copy, 1.001 (ranges 0.60% and
0.71%). One and three pairs gave 0.748 and 0.748. The split's 25% speedup is
attributed: it exceeds both ranges and the twin by far.
`--check-module pkg::vm`: main 7.155 and 7.121 s, head 7.476 and 7.460 s,
1.046 times; within 1.25. **The criterion passes at the head and the change
is kept.**

## P1 on the 14900K with wf-e1708490c384

### Question, recorded before measuring

On the reference platform, the owner's i9-14900K running x86-64 Linux, with
Whitefoot `wf-e1708490c384` (LLVM 22) and clang 22, how far is Halo from P1
([VM design](../../investigations/halo/VM.md), Halo's median at most PUC
5.1.5's) on each kernel, after Halo-wf#3's changes, the `sort_compare` split
included? The earlier P1 tables were measured on an M1 Pro with older
compilers. This run tests no proposal; it orders the performance candidates
in `docs/todo.md`, nearest the largest ratio first.

Comparison: `run.py` with Halo (Halo-wf `c0168e213`, full LTO) against
Redis 7.0.15's bundled PUC Lua built from source, all seven kernels at the
P1 counts with binary-trees at depth 14, one, three and six alternating
pairs, unlimited budget, checksums and collection counts recorded. The run
also records whether `perf` and `objdump` are available on the runner, for
the attribution that follows.

### Result

[Run 37560444248](https://github.com/Ming-Research/Halo-wf/actions/runs/37560444248),
six alternating pairs, Halo at `c0168e213` against the reference Lua (medians in
seconds; checksums agreed in every launch):

| Kernel | PUC | Halo | Halo / PUC | PUC range | Halo range |
|---|---:|---:|---:|---:|---:|
| fib | 0.0406 | 0.1050 | 2.584 | 2.75% | 0.67% |
| loop | 0.2819 | 0.4351 | 1.544 | 1.32% | 0.31% |
| integer-table | 0.2203 | 0.5921 | 2.688 | 4.30% | 9.12% |
| string-key | 0.0200 | 0.0335 | 1.678 | 4.76% | 1.38% |
| concat | 0.0414 | 0.1002 | 2.418 | 1.95% | 1.86% |
| sort | 0.2580 | 0.5543 | 2.148 | 1.89% | 1.87% |
| binary-trees | 0.8693 | 2.1156 | 2.434 | 0.59% | 0.53% |

P1 still fails on every kernel. In order of ratio: integer-table, fib,
binary-trees, concat, sort, string-key, loop. The runner has `perf` 6.8.12
with `perf_event_paranoid` at -1 and `objdump`.

### Profiles, recorded before they ran

For each kernel: `perf stat` of PUC and of Halo (cycles, instructions,
branches, branch misses, L1 data-cache load misses), three launches each, to
separate executing more work from executing it slowly; and `perf record` of
Halo (cycles, default frequency, one launch), reported by symbol, the top 30.
The first candidate is chosen from these: the kernel with the largest ratio
whose profile shows one attributable cost, with a criterion recorded before
its change.

### Profile result

[Run 37560653349](https://github.com/Ming-Research/Halo-wf/actions/runs/37560653349).
The runner is a Hyper-V guest without hardware performance counters: every
`perf stat` event reported `<not supported>` for both engines, so the
separation of work from speed planned above is not available here. `perf
record` sampled Halo (one launch per kernel); the leading symbols, as shares
of samples, with `vm.run` arms named by their arm number in the compiled
dispatch function:

- fib: arm 63 18.8%, `enter_lua` 16.6%, `push_frame` 14.7%, arm 54 12.6%,
  arm 5 11.9%, `finish` 7.4%, arm 65 6.9%, `prepare` 3.8%; the call path's
  four functions together take 42%.
- concat: `heap.intern` 21.7%, arm 11 20.2%, `vm.slow` 16.3%,
  `concat_strings` 7.8%, `concat_step` 4.4%, `malloc` 4.2%.
- binary-trees: `heap.node_find` 13.8%, `collect_if_due` 5.5%, libc
  `_int_malloc`, `malloc` and `calloc` 13.4% together.
- string-key: arm 11 55.6%, `heap.node_find` 19.0%.
- integer-table: arm 13 24.0%, arm 11 16.4%, `heap.rehash` 9.3%, arm 66
  6.9%, `vm.slow` 6.8%.
- sort: `sort_run` 55.0%, `heap.table_set` 13.8%, `raw_assign` 7.3%,
  `sort_compare` 4.9%.
- loop: arm 66 63.4%, arm 20 36.6%.

One launch per kernel gives shares, not costs, and the arms are not yet
mapped to instructions; the candidate is chosen after reading these paths
against PUC's.

### Candidate order

A read of the hot paths against PUC's (concat, sort, integer-table stores,
string-key lookup, the call path), ranked by expected recovery of each
kernel's ratio and by risk to roots, handles and budget suspension, puts
concatenation first: `concat_step` (`lib/halo/vm/continuations.wf`) folds
the operands right to left one pair at a time, enters the slow executor for
each pair, allocates and copies a fresh buffer per pair and interns every
intermediate string, where PUC's `luaV_concat` joins every adjacent string
or number operand in one buffer and creates one string. Sort's synchronous
comparison, integer-table's store slot, string-key's lookup and the call path
follow, each to be measured on its own.

## Batched concatenation

### Criterion, recorded before the change

Change: `Concat` joins each maximal run of adjacent string or number
operands, from the top as `luaV_concat` does, into one buffer and interns the
result once; numbers convert with Lua's `%.14g`; an operand that is neither
still goes to `__concat` with PUC's operand order, its errors and the
continuation that budget suspension and callbacks need.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of the head
before the change against the head after it, with a twin of the before
binary: the concat kernel's median falls at least 15%, by more than both
relative ranges and the twin's difference; no other kernel is slower beyond
its larger range and the twin's; `--check-module pkg::vm` takes at most 1.25
times as long; and `make check` passes, the oracle at budgets 1, 7 and 1000
ordinary and under collector stress included. Otherwise the change is
reverted with its measurements kept.

### Result

[Run 37562788975](https://github.com/Ming-Research/Halo-wf/actions/runs/37562788975):
main `7920b3c8d` against the branch at `f85c49c5b`, whose engine differs from
main only in `lib/halo/vm/concat.wf`, `continuations.wf` and the license note
(the run's own `git diff --stat`); six interleaved full-LTO pairs, medians in
seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1049 | 0.1045 | 0.997 | 0.85% | 1.88% | 0.998 |
| loop | 0.4360 | 0.4348 | 0.997 | 1.38% | 0.88% | 0.998 |
| integer-table | 0.5944 | 0.5885 | 0.990 | 3.67% | 4.88% | 1.000 |
| string-key | 0.0336 | 0.0338 | 1.005 | 1.09% | 2.70% | 1.009 |
| concat | 0.1004 | 0.0730 | 0.727 | 0.94% | 0.79% | 0.998 |
| sort | 0.5541 | 0.5516 | 0.996 | 0.53% | 0.35% | 1.002 |
| binary-trees | 2.1019 | 2.1088 | 1.003 | 1.12% | 0.72% | 1.004 |

`--check-module pkg::vm`: main 7.408 and 7.473 s, branch 7.551 and 7.544 s
(1.014 times). `make check` passed at `6e9a50773`, the same engine
([run 37562088965](https://github.com/Ming-Research/Halo-wf/actions/runs/37562088965)),
the strengthened concatenation scripts and budgets 1, 7 and 1000 under
collector stress included; their assertions also hold on Redis
(oracle-reference run 37561720007).

**The criterion passes and the change is kept.** Concat is 27.3% faster, far
beyond both ranges and the twin, and no other kernel is slower beyond its
bounds. Against PUC's median in the P1 run above, concat's ratio goes from
2.42 to about 1.76 (not measured in one session).

## Whitefoot wf-0b7f5c5b9854 upgrade

### Question, recorded before measuring

`whitefoot.pin` moves from `wf-e1708490c384` (Whitefoot `e1708490c`,
specification v0.93) to `wf-0b7f5c5b9854` (`0b7f5c5b9`, v0.94). The
specification adds only scanning and clearing a `ConcurrentHashMap`, which
Halo does not use; code generation changes through Whitefoot #258 (the
match's code cursor), #261 (edges by their step; spill order) and #260. How do
the kernels and the vm module-check time move? Whitefoot-kit's upgrade step 5
asks for this comparison; it reports the difference and rejects nothing. The
Whitefoot session measured Halo at `acb39ad7f` with #261's fix against the
pre-cursor compiler: loop 1.000, fib 1.005.

Comparison: the same source (this branch's engine) built with each release,
six interleaved full-LTO pairs over the seven kernels, a twin of the old
build, and two interleaved module-check samples per compiler.

### Result

[Run 37566520775](https://github.com/Ming-Research/Halo-wf/actions/runs/37566520775)
at `014b4082d`, six interleaved full-LTO pairs, medians in seconds:

| Kernel | Old release | New release | Ratio | Old range | New range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1055 | 0.1047 | 0.993 | 1.74% | 1.24% | 0.998 |
| loop | 0.4348 | 0.4350 | 1.001 | 0.64% | 0.77% | 1.000 |
| integer-table | 0.6003 | 0.5949 | 0.991 | 1.90% | 12.58% | 0.999 |
| string-key | 0.0337 | 0.0339 | 1.007 | 2.27% | 1.03% | 0.998 |
| concat | 0.0730 | 0.0731 | 1.001 | 1.60% | 1.10% | 1.005 |
| sort | 0.5509 | 0.5512 | 1.001 | 0.84% | 0.34% | 0.999 |
| binary-trees | 2.1131 | 2.1131 | 1.000 | 1.53% | 1.23% | 1.001 |

`--check-module pkg::vm`: old 7.515 and 7.618 s, new 7.536 and 7.588 s.
Every kernel stays within its ranges and the twin; the upgrade leaves these
kernels' times and the module check unchanged, in line with the Whitefoot
session's measurement of #261 on Halo.

## Constant-step next pc in the dispatch arms

### Criterion, recorded before the change

Since `wf-0b7f5c5b9854`, Whitefoot lowers `run`'s self-tail calls with a code
cursor: an edge whose new `pc` is visibly `pc` plus a constant moves the
received address by that constant, and every other edge forms the address
from `pc` again. Halo's straight-line arms receive `next` from their helpers
(`Ok(next)`), so the cursor cannot see the step. Change: in the arms whose
instruction always continues at the next cell (moves, loads, upvalue reads,
table reads and writes, arithmetic, length, `not`, and the fast table
paths), compute `next = pc + 1` in the arm and check it against the code
length there, the helper reporting only success; arms whose continuation is
a jump target, a call, a return or a callback keep their current form. The
design node `design/halo/dispatch/continuations.md` changes with it, for the
owner's ruling.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of the branch
before the change against after it, with a twin of the before binary: the
loop kernel's median falls at least 5%, by more than both ranges and the
twin's difference; no kernel is slower beyond its larger range and the
twin's; `--check-module pkg::vm` takes at most 1.25 times as long; and `make
check` passes. Otherwise the change is reverted with its measurements kept.

### Result

[Run 37569342705](https://github.com/Ming-Research/Halo-wf/actions/runs/37569342705):
the branch before the change (`bb4ff27cd`) against after it (`1abb228cc`,
whose engine differs only in `dispatch.wf`, `handlers.wf` and
`continuations.wf`), both built with `wf-0b7f5c5b9854`; six interleaved
full-LTO pairs, medians in seconds. `make check` passed on the changed engine
([run 37568872363](https://github.com/Ming-Research/Halo-wf/actions/runs/37568872363)).

| Kernel | Before | After | Ratio | Before range | After range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1048 | 0.1042 | 0.994 | 1.12% | 1.37% | 1.005 |
| loop | 0.4348 | 0.4263 | 0.981 | 0.69% | 0.40% | 1.000 |
| integer-table | 0.5921 | 0.5868 | 0.991 | 1.84% | 2.41% | 1.004 |
| string-key | 0.0335 | 0.0329 | 0.982 | 4.02% | 2.13% | 0.991 |
| concat | 0.0728 | 0.0764 | 1.049 | 1.93% | 3.15% | 0.999 |
| sort | 0.5520 | 0.5377 | 0.974 | 0.36% | 0.68% | 1.001 |
| binary-trees | 2.1265 | 2.0928 | 0.984 | 1.80% | 1.92% | 0.995 |

`--check-module pkg::vm`: before 7.548 and 7.529 s, after 8.384 and 8.417 s
(1.114 times).

**The criterion fails and the change is reverted.** Loop improves only 1.9%
against the required 5%, and concat is 4.9% slower, beyond its 3.15% range
and the twin. Sort improves 2.6% beyond its bounds; the other kernels move
within theirs. The checker also needed the 31 arms that used to reach the
shared epilogue to check the stack window themselves, because their helpers'
postconditions could not carry it, so those arms gained a comparison as
well as the constant step. `dispatch.wf`, `handlers.wf` and
`continuations.wf` return to their bytes at `bb4ff27cd`.

## Synchronous default sort

### Criterion, recorded before the change

`table.sort` runs as a resumable state machine (`lib/halo/vm/library-sort.wf`,
`sort_run` with `SortFrame` phases), so that a Lua comparator can call back
and be suspended by the budget; the default comparison of numbers takes the
same path, storing frames and passing each result through a stack slot
(`sort_run` 55% of the sort kernel's samples). Change: when no comparator is
given and every element `1..n` lies in the table's array part and all are
numbers, or all are strings, sort them synchronously by the same steps as
PUC's `auxsort` (the same pivots, comparisons, swaps, recursion on the
smaller half, and the same "invalid order function for sorting" error at
the same point), reading and writing the array directly; every other case
keeps the state machine.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of the branch
before the change against after it, with a twin of the before binary: the
sort kernel's median falls at least 15%, by more than both ranges and the
twin's difference; no other kernel is slower beyond its larger range and the
twin's; `--check-module pkg::vm` takes at most 1.25 times as long; and `make
check` passes, the sort oracle cases at budgets 1, 7 and 1000 under collector
stress included. Otherwise the change is reverted with its measurements
kept.

### Result

[Run 37572825175](https://github.com/Ming-Research/Halo-wf/actions/runs/37572825175):
main `734eceebf` against the branch at `8f5c60013`, whose engine differs from
main only in `lib/halo/vm/library-sort.wf` (the run's own `git diff --stat`);
six interleaved full-LTO pairs with `wf-0b7f5c5b9854`, medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1046 | 0.1051 | 1.005 | 2.88% | 2.37% | 0.998 |
| loop | 0.4345 | 0.4360 | 1.004 | 0.72% | 1.08% | 0.999 |
| integer-table | 0.5974 | 0.5985 | 1.002 | 1.54% | 1.36% | 0.998 |
| string-key | 0.0335 | 0.0336 | 1.003 | 2.38% | 0.81% | 1.013 |
| concat | 0.0730 | 0.0730 | 1.000 | 1.44% | 6.19% | 0.991 |
| sort | 0.5515 | 0.1936 | 0.351 | 0.66% | 1.33% | 1.001 |
| binary-trees | 2.1252 | 2.1433 | 1.009 | 2.13% | 0.53% | 0.998 |

`--check-module pkg::vm`: main 7.602 and 7.691 s, branch 7.677 and 7.683 s
(1.005 times). `make check` passed at `3dffe7c2a`, the same engine
([run 37572112536](https://github.com/Ming-Research/Halo-wf/actions/runs/37572112536)),
with the new `table-sort-order` script's permutations, signed zeros and NaN
included, equal to Redis's at budgets 1, 7 and 1000, ordinary and under
collector stress.

**The criterion passes and the change is kept.** The sort kernel takes 0.351
times as long, far beyond both ranges and the twin, and no other kernel is
slower beyond its bounds. Against PUC's 0.2580 s in the P1 run above, the
kernel's 0.1936 s is about 0.75 times PUC's; the paired run below settles it.

## P1 after the batched concatenation and the synchronous sort

[Run 37575858701](https://github.com/Ming-Research/Halo-wf/actions/runs/37575858701),
from a measurement-only branch since deleted: Halo-wf#9's head `4d8015ed9`
(engine and pin; `wf-8b647edbbc95`) against Redis 7.0.15's bundled PUC Lua on
the 14900K, six alternating pairs as in the first P1 run on this host
(medians in seconds):

| Kernel | PUC | Halo | Halo / PUC | Earlier ratio | PUC range | Halo range |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.0410 | 0.1049 | 2.557 | 2.584 | 3.71% | 3.08% |
| loop | 0.2813 | 0.4353 | 1.548 | 1.544 | 1.69% | 1.92% |
| integer-table | 0.2235 | 0.5959 | 2.666 | 2.688 | 4.22% | 1.94% |
| string-key | 0.0198 | 0.0335 | 1.689 | 1.678 | 3.60% | 2.93% |
| concat | 0.0415 | 0.0729 | 1.756 | 2.418 | 2.08% | 1.22% |
| sort | 0.2574 | 0.1928 | 0.749 | 2.148 | 1.11% | 2.60% |
| binary-trees | 0.8866 | 2.1496 | 2.424 | 2.434 | 3.17% | 1.19% |

Sort meets P1 (0.749, measured in one paired run); concat moves from 2.42 to
1.76; the other kernels are where the first run left them. P1 still fails on
six kernels: integer-table, fib, binary-trees, concat, string-key and loop.

## Table stores without the slow executor

### Criterion, recorded before the change

A table store whose old value is nil leaves the fast handler
(`fast_instruction_set_table_*` in `lib/halo/vm/handlers.wf`): the slow
executor looks the key up again, checks `__newindex` and read-only refusal,
and `raw_assign` and `table_set` validate the table and key once more before
inserting. PUC's `luaV_settable` takes one writable slot from `luaH_set`
and, with no `__newindex` to consult, writes through it. The integer-table
kernel's fill loop stores ten million new keys this way. Change: when the
table has no metatable and is not read-only, the fast handler inserts the
new key itself through the table's own insertion path (growth and rehash as
now), refusing a nil or NaN key with the same errors as now; a metatable,
a read-only table or any other case keeps the slow executor.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of main
before the change against the branch after it, with a twin of the before
binary: the integer-table kernel's median falls at least 8%, by more than
both ranges and the twin's difference; no other kernel is slower beyond its
larger range and the twin's; `--check-module pkg::vm` takes at most 1.25
times as long; and `make check` passes. Otherwise the change is reverted
with its measurements kept.

### Result

[Run 37579185722](https://github.com/Ming-Research/Halo-wf/actions/runs/37579185722):
main `bc4e2db17` against the branch at `049e11968`, whose engine differs from
main only in `lib/halo/vm/handlers.wf` (the run's own `git diff --stat`); six
interleaved full-LTO pairs with `wf-8b647edbbc95`, medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1042 | 0.1041 | 0.999 | 2.61% | 1.69% | 0.997 |
| loop | 0.4353 | 0.4361 | 1.002 | 0.67% | 0.70% | 1.000 |
| integer-table | 0.6020 | 0.5205 | 0.865 | 2.08% | 1.41% | 1.002 |
| string-key | 0.0336 | 0.0338 | 1.007 | 0.81% | 3.64% | 1.012 |
| concat | 0.0731 | 0.0733 | 1.002 | 1.05% | 2.97% | 1.002 |
| sort | 0.1934 | 0.1834 | 0.949 | 2.55% | 3.71% | 0.999 |
| binary-trees | 2.1565 | 1.9574 | 0.908 | 1.14% | 1.75% | 1.000 |

`--check-module pkg::vm`: main 7.554 and 7.623 s, branch 7.563 and 7.603 s
(0.999 times). `make check` passed at `7088d4b84`, the same engine
([run 37578460931](https://github.com/Ming-Research/Halo-wf/actions/runs/37578460931)).

**The criterion passes and the change is kept.** Integer-table takes 0.865
times as long, beyond both ranges and the twin; binary-trees, whose
constructors store new keys into fresh tables, takes 0.908 times as long, and
sort's fill loop 0.949; no kernel is slower beyond its bounds.

### Remeasured at the final engine

The located-error fix (review finding F1) also made the fast store refuse nil
and NaN keys before inserting. [Run 37582240053](https://github.com/Ming-Research/Halo-wf/actions/runs/37582240053),
from a measurement-only branch since deleted, repeats the comparison at the
final engine (`380b624f0`), main `bc4e2db17` against it with a twin:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1043 | 0.1047 | 1.004 | 2.62% | 2.65% | 1.008 |
| loop | 0.4340 | 0.4343 | 1.001 | 0.48% | 0.65% | 0.997 |
| integer-table | 0.5988 | 0.5277 | 0.881 | 0.90% | 1.39% | 0.996 |
| string-key | 0.0336 | 0.0336 | 0.999 | 1.31% | 1.60% | 0.994 |
| concat | 0.0730 | 0.0730 | 1.000 | 2.50% | 1.12% | 0.999 |
| sort | 0.1934 | 0.1845 | 0.954 | 1.62% | 1.92% | 1.002 |
| binary-trees | 2.1354 | 1.9396 | 0.908 | 1.76% | 1.81% | 0.992 |

`--check-module pkg::vm`: main 7.568 and 7.610 s, branch 7.573 and 7.609 s
(1.000 times). The criterion still passes: integer-table takes 0.881 times
as long, and no kernel is slower beyond its bounds.

## The call path

### Call-path attribution, recorded before it runs

Fib spends 42% of its samples in the call path's four functions, `prepare`,
`enter_lua`, `push_frame` and the return's `finish`
([profile](#profile-result)), and is 2.56 times PUC. Where does that time go,
instruction by instruction, against PUC's `luaD_precall` and `luaD_poscall`?
This run tests no proposal: it chooses the call-path change and the criterion
recorded before it. Each cost it finds is one of two kinds. Work that Halo's
source asks for and PUC does not do, such as a second closure lookup, a
frame-limit test or a copied prototype, is a candidate change in Halo. Code
the compiler emits beyond what the source asks for is a Whitefoot gap: it is
stated as a minimal witness and brought to the owner, not worked around in
Halo's source.

Run: on a GitHub-hosted ubuntu-24.04 x86-64 runner, since the 14900K's
runner was offline and this run reads shares of samples, not times; Halo at
main `99936d6e6` built with full LTO as `run.py` builds it, and Redis 7.0.15's bundled PUC Lua built from source, each running
the fib kernel at N = 30; `perf record` of each, three launches, reported by
symbol; `perf annotate` of Halo's sampled symbols; and the disassembly of the
call-path functions with their instruction counts.

### Call-path attribution result

[Run 37601651300](https://github.com/Ming-Research/Halo-wf/actions/runs/37601651300),
artifact `halo-call-profile`: an AMD EPYC 7763 guest with 4 vCPUs, Linux
6.17, perf 6.17.13 sampling `task-clock` (the guest has no hardware
counters), `wf-8b647edbbc95` with clang 22.1.8; both engines print
832040 in every launch. Shares of samples, three launches:

| Halo symbol | Share | PUC symbol | Share |
|---|---:|---|---:|
| `enter_lua` | 14.5–25.4% | `luaV_execute` | 58.0–62.0% |
| arm 63 (`Call`, calls `prepare`) | 13.1–20.3% | `luaD_precall` | 19.4–23.7% |
| `push_frame` | 12.1–19.9% | `luaV_lessthan` | 7.1–9.4% |
| arm 65 (`Return`, calls `finish`) | 9.5–13.5% | `luaD_poscall` | 5.1–7.1% |
| arm 5 | 10.5–13.2% | `luaF_close` | 3.1–3.8% |
| `prepare` | 6.7–8.0% | | |
| arm 54 | 5.6–8.0% | | |
| `finish` | 4.5–5.8% | | |

Sizes: `enter_lua` 452 instructions, `prepare` 1382, `finish` 149,
`push_frame` 91; `luaD_precall` 437, `luaD_poscall` 95.

The hottest instructions, from launch 1's annotation (a `task-clock` sample
lands on or just after the instruction that waited), are each a 16-byte
load of memory that narrower stores wrote just before, which x86 cannot
forward from store to load:

- `push_frame`: 47.9% of its samples follow the first 16-byte load of its
  by-value `Frame` (80 bytes, passed as a pointer to the caller's copy),
  which `enter_lua` built field by field. That load starts the entry copy
  every definition makes of a by-value aggregate parameter; the frame is
  then copied a second time into the frames vector.
- Arm 63: 23.5% of its samples follow the second of two 16-byte loads that
  copy the 32-byte `Step` result from the call's destination into a slot of
  the dispatch loop's frame, where `enter_lua` had stored it as four 8-byte
  words (tag, `pc`, `base`, `kbase`); the slot is then reloaded field by
  field and its tag dispatched a second time.
- `prepare`: 29.6% of its samples follow the 4-byte reload of the called
  value's handle, which the code had read from the Lua stack as one 16-byte
  load and stored to its own frame, and 26.1% fall on the closure-slab test
  that depends on it.
- `enter_lua`'s samples spread more evenly; its largest points copy the
  40-byte prototype into its frame (8.3%, 4.7% and 3.6%) and reload a byte
  of it (11.2%).

The costs fall into three kinds:

- Code the compiler emits beyond the source: the entry copy of a by-value
  aggregate parameter, a result returned through memory and copied whole
  into another slot before its fields are read, and a matched value copied
  into a slot before its fields are read. The source asks for none of these
  copies, and each turns field-sized stores followed by a field read into a
  16-byte reload. These are a Whitefoot question for the owner. Whitefoot's
  `compiler/storage-placement` keeps the entry copy and reopens it "when a
  measured program shows the entry copy surviving inlining at a cost".
- Halo-side work PUC does not do: the closure slab is looked up twice per
  call (`prepare`'s `native_binding` and `enter_lua`), the prototype is
  copied whole, `push_frame` tests the frame limit and the capacity
  separately, and the nil fill tests each slot's bound.
- The dispatch form: the `Step` result crosses from each arm into the
  shared epilogue through the loop's frame, part of the self-tail-call form
  that `loop { match }` dispatch replaces.

Not established: what each kind costs in time (the guest has no counters
and the 14900K was offline), and that the loads stall (inferred from the
store and load widths in the disassembly, not counted). The call-path change
waits for `loop { match }` dispatch, since the arms and the epilogue it would
change are being rewritten, and the compiler-side copies go to the owner.

### The entry copy of a by-value parameter, measured

The owner chose (Q90) to measure each compiler-side copy before bringing it
to Whitefoot. The first is the entry copy: every Whitefoot definition copies
a by-value aggregate parameter into a slot of its own at entry, which
`push_frame`'s 80-byte `Frame` shows above. Whitefoot's
`compiler/storage-placement` keeps that copy and reopens the question "when
a measured program shows the entry copy surviving inlining at a cost"; the
implementation that reads such a parameter in place is on Whitefoot's branch
`research/in-place-parameters`.

Question: what does the entry copy cost Halo? Comparison: this branch's
source built twice with full LTO, once with `wf-8b647edbbc95` (the pin) and
once with `wf-exp-5a3c70fc3351`, which is Whitefoot `8b647edbb` with that
branch's two commits (`0db7321fc` and `e35cc5f95`) cherry-picked onto it,
its gate passed; six interleaved pairs over the seven kernels on the 14900K
with a twin of the pinned build, and both builds' disassembly of
`push_frame`. The comparison tests the hypothesis only if `push_frame` loses
its entry copy in the experiment build; the stall may remain without it,
since the frames vector is still filled by wide loads of the caller's
field-by-field stores. A fib median below the pinned build's by more than
both ranges and the twin's difference is a measured cost of the entry copy;
anything else is no evidence of one. The result goes to the owner either
way; no Halo source changes.

The 14900K went out of service before this ran. By the owner's direction
(Q93 and the rule that the M5 Air only times), the two binaries are built by
a hosted arm64 macOS runner and timed on the M5 Air under Whitefoot's
`run-check.pl` lock, with the same pairs, twin and reading, recorded here
before it runs; its result is an M5 result.

Result: [run 37709134977](https://github.com/Ming-Research/Halo-wf/actions/runs/37709134977)
built both binaries on a hosted arm64 macOS runner (macOS 15.7.9, Apple
clang 17.0.0; artifact `halo-inplace-binaries`). The experiment build keeps
`push_frame`'s entry copy: its 81 instructions equal the pinned build's
apart from addresses, both starting by loading the 80-byte `Frame` through
the incoming pointer and storing it to the stack with 128-bit pairs. Across
the whole binary the two builds differ by one 128-bit load or store pair
(1,315 against 1,314). The research branch's rule therefore does not reach
`push_frame`'s parameter, and as recorded above, the comparison cannot test
the hypothesis; it was not timed. Which of that rule's conditions
`push_frame` fails (no result destination, no wait, no overlap group or
split part, and a parameter slot that is a complete allocation nothing else
writes) is not determined here. Measuring the entry copy needs either that
rule widened to this case in Whitefoot or a Halo experiment that keeps the
`Frame` from crossing the call as an aggregate.

### Which condition the in-place rule refuses (Q94)

The owner chose (Q94) to find which of the rule's conditions `push_frame`
fails before deciding anything. Both compilers emitted the IR of Halo's
bench program and of a minimal witness on a hosted runner
([run 37711158274](https://github.com/Ming-Research/Halo-wf/actions/runs/37711158274),
artifact `halo-inplace-ir`). `push_frame`'s IR is the same under both: at
entry it copies the incoming `Frame` with `llvm.memmove` into a slot of its
own, and that slot's only use is the pointer it hands to `place_back`, so
its address is not exposed (the storage plan exposes a slot only through
`AddressOf` and `SliceFromRun`).

The witness takes one 80-byte struct by value in six functions, counting
each definition's `llvm.memmove` and `llvm.memcpy`:

| Function | Use of the parameter | Branch | Pinned | Experiment |
|---|---|---|---:|---:|
| `rec_first` | reads a field | no | 1 | 0 |
| `rec_forward` | passes it to `rec_first` | no | 1 | 0 |
| `rec_push_via` | passes it to `rec_push` | no | 1 | 0 |
| `rec_pick` | reads one of two fields | yes | 1 | 1 |
| `rec_push` | hands it to `place_back` | yes | 1 | 1 |
| `rec_set` | assigns it into a container slot | yes | 2 | 2 |

`rec_set`'s second copy is the assignment's own. The experiment's rule
reads the parameter in place in every function without a branch and in no
function with one, whatever the parameter's use, so the branch decides it:
of the rule's conditions only `holds_only` can depend on a branch, and the
likely cause is that a value carried across blocks becomes a block
parameter sharing the parameter's slot, so the slot holds more than one
value. That last step is an inference from the rule's code, not observed in
Whitefoot's IR. Halo's functions nearly all branch, which is why the
experiment build differed by one copy in the whole binary.

```wf
alias ExitStatus = std::process::ExitStatus;
alias exit_status = std::process::exit_status;

struct Rec {
  a: u64;
  b: u64;
  c: u64;
  d: u64;
  e: u64;
  f: u64;
  g: u64;
  h: u64;
  i: u64;
  j: u64;
}

fn rec_first(r: Rec) -> s: u64 pure {
  return r.a;
}

fn rec_forward(r: Rec) -> s: u64 pure {
  return rec_first(r: r);
}

fn rec_push(v: &Box<Slots<Rec>>, r: Rec) -> ok: Bool writes(v) {
  if v^.inner.len < v^.inner.cap {
    place_back(window: &v^.inner, value: r);
    return True();
  }
  return False();
}

fn rec_push_via(v: &Box<Slots<Rec>>, r: Rec) -> ok: Bool writes(v) {
  return rec_push(v: v, r: r);
}

fn rec_set(v: &Box<Slots<Rec>>, r: Rec) -> ok: Bool writes(v) {
  if 0_u64 < v^.inner.len {
    set v^.inner[0_u64] = r;
    return True();
  }
  return False();
}

fn rec_pick(r: Rec, c: Bool) -> s: u64 pure {
  if c {
    return r.a;
  }
  return r.b;
}

fn main() -> status: ExitStatus pure {
  let v = box_slots_new::<Rec>(capacity: 4_u64);
  let r = Rec(a: 1_u64, b: 2_u64, c: 3_u64, d: 4_u64, e: 5_u64, f: 6_u64, g: 7_u64, h: 8_u64, i: 9_u64, j: 10_u64);
  let first = rec_first(r: r);
  let forwarded = rec_forward(r: r);
  let pushed = rec_push(v: &v, r: r);
  let via = rec_push_via(v: &v, r: r);
  let stored = rec_set(v: &v, r: r);
  let picked = rec_pick(r: r, c: via);
  if pushed {
    if stored {
      if first == forwarded {
        if picked == 1_u64 {
          return exit_status(code: 0_u8);
        }
      }
    }
  }
  return exit_status(code: 1_u8);
}
```

## String-key lookup

### Criterion, recorded before the change

A table read with a string key goes through `table_get`
(`lib/halo/heap/tables.wf`): `integer_key` classification, `node_find`,
`main_position` with the generic `key_hash` and a modulus, and the generic
`equal`, which matches every value kind (`node_find` 19% of the string-key
kernel's samples, 14% of binary-trees'). PUC's `luaH_getstr` takes the
string's cached hash, masks it to the node vector, and compares string
pointers along the chain. Change: a string-key read takes a lookup
specialised for strings, the cached hash masked by the power-of-two node
count and handle comparison along the chain, with the same result as
`table_get` for every table (integer-keyed parts are never reached by a
string key); every other key keeps `table_get`.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of main
before the change against the branch after it, with a twin of the before
binary: the string-key kernel's median falls at least 5%, by more than
both ranges and the twin's difference; no kernel is slower beyond its
larger range and the twin's; `--check-module pkg::vm` takes at most 1.25
times as long; and `make check` passes. Otherwise the change is reverted
with its measurements kept.

### Result

[Run 37595142933](https://github.com/Ming-Research/Halo-wf/actions/runs/37595142933):
main `99936d6e6` against the branch at `b37e0dbba`, whose engine differs from
main only in `lib/halo/heap/tables.wf`, its module interface and
`lib/halo/vm/handlers.wf` (the run's own `git diff --stat`); six interleaved
full-LTO pairs with `wf-8b647edbbc95`, medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1043 | 0.1042 | 0.999 | 1.74% | 0.38% | 0.996 |
| loop | 0.4338 | 0.4347 | 1.002 | 1.37% | 1.23% | 1.002 |
| integer-table | 0.5344 | 0.5134 | 0.961 | 2.93% | 1.77% | 0.996 |
| string-key | 0.0337 | 0.0259 | 0.769 | 2.69% | 0.49% | 1.013 |
| concat | 0.0731 | 0.0742 | 1.015 | 1.93% | 2.98% | 1.005 |
| sort | 0.1852 | 0.1766 | 0.954 | 0.92% | 0.77% | 0.996 |
| binary-trees | 1.9550 | 1.9413 | 0.993 | 1.85% | 1.33% | 1.000 |

`--check-module pkg::vm`: main 7.564 and 7.599 s, branch 7.544 and 7.639 s
(1.001 times). `make check` passed at `c87aec0be`, the same engine
([run 37594106496](https://github.com/Ming-Research/Halo-wf/actions/runs/37594106496)).

**The criterion passes and the change is kept.** String-key takes 0.769
times as long, beyond both ranges and the twin; integer-table (0.961) and
sort (0.954) also move beyond their bounds, and no kernel is slower beyond
its bounds. Against PUC's median in the paired P1 run above (0.0198 s),
string-key's 0.0259 s is about 1.31 times PUC's (not measured in one
session).

### Remeasured at the final engine

The power-of-two guard (review finding F1) adds a length test to every
string lookup after the measurement above. [Run 37601538830](https://github.com/Ming-Research/Halo-wf/actions/runs/37601538830),
from a measurement-only branch, repeats the comparison at the final engine
(`448c217a2`, the run's own `git diff --stat` naming only
`lib/halo/heap/tables.wf`, its module interface and
`lib/halo/vm/handlers.wf`): main `99936d6e6` against it, six interleaved
full-LTO pairs with a twin.

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1117 | 0.1103 | 0.987 | 4.57% | 1.78% | 1.004 |
| loop | 0.4539 | 0.4557 | 1.004 | 1.45% | 2.90% | 1.007 |
| integer-table | 0.5539 | 0.5333 | 0.963 | 2.72% | 4.24% | 0.999 |
| string-key | 0.0355 | 0.0273 | 0.770 | 26.17% | 4.31% | 1.008 |
| concat | 0.0759 | 0.0760 | 1.001 | 9.25% | 5.15% | 0.999 |
| sort | 0.1848 | 0.1782 | 0.964 | 1.95% | 1.84% | 1.001 |
| binary-trees | 2.0444 | 2.0338 | 0.995 | 5.26% | 5.81% | 1.000 |

`--check-module pkg::vm`: main 8.098 and 8.170 s, branch 8.236 and 8.096 s.

String-key again takes 0.770 times as long, and every main launch
(0.0352–0.0445 s) is slower than every branch launch (0.0268–0.0279 s), but
main's range is 26.17%, all of it one launch of 0.0445 s against 0.0352–0.0359
s for the other five, so the fall of 23.0% is not beyond both ranges as the
criterion requires. This comparison's main medians are 3.6–7.1% above the
first run's for six kernels (sort's is unchanged), while the twin comparison just before it in
the same job is within 2% of the first run; the runner had just come back
online.
The spread is too large to decide, so the comparison is repeated once, six
pairs on the same branch, and that repeat decides; both runs stay recorded.

The repeat ([run 37601538830, attempt 2](https://github.com/Ming-Research/Halo-wf/actions/runs/37601538830/attempts/2)),
the same three binaries by hash:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1043 | 0.1050 | 1.006 | 0.54% | 1.07% | 1.000 |
| loop | 0.4332 | 0.4330 | 0.999 | 0.85% | 1.02% | 0.995 |
| integer-table | 0.5277 | 0.5098 | 0.966 | 2.36% | 2.88% | 0.995 |
| string-key | 0.0336 | 0.0259 | 0.771 | 1.50% | 1.21% | 0.997 |
| concat | 0.0729 | 0.0740 | 1.016 | 2.77% | 1.02% | 1.006 |
| sort | 0.1845 | 0.1754 | 0.951 | 0.78% | 2.96% | 1.008 |
| binary-trees | 1.9616 | 1.9592 | 0.999 | 1.98% | 1.22% | 1.000 |

`--check-module pkg::vm`: main 7.610 and 7.619 s, branch 7.603 and 7.586 s
(0.997 times).

**The criterion passes at the final engine.** String-key takes 0.771 times
as long, beyond both ranges and the twin; no kernel is slower beyond its
larger range and the twin's (concat's 1.016 is inside its 2.77% range).

## Table construction and growth

### Attribution, recorded before it runs

Binary-trees is about 2.2 times PUC and integer-table about 2.35 times
([P1 on the 14900K](#p1-on-the-14900k-with-wf-e1708490c384), with the
changes since). Their profiles there put `heap.node_find` (13.8%), the
collector's `collect_if_due` (5.5%) and libc's allocator (13.4%) in
binary-trees, and `heap.rehash` (9.3%) beside the table arms in
integer-table. Where does the time of table construction, insertion and
growth go, instruction by instruction, against PUC's `luaH_new`,
`luaH_set`/`newkey` and `luaH_resize`? This run tests no proposal: it
chooses the next change and its criterion. As for the call path, each cost
is classed as work Halo's source asks for that PUC does not do, a Halo-side
candidate, or code the compiler emits beyond what the source asks for, a
Whitefoot question for the owner. Costs inside the dispatch arms are noted
but not acted on, since `loop { match }` dispatch is rewriting them.

Run: on a GitHub-hosted ubuntu-24.04 x86-64 runner, which reads shares of
samples, not times; Halo at main built with full LTO as `run.py` builds it,
and Redis 7.0.15's bundled PUC Lua built from source, each running
binary-trees at depth 14 (`run.py`'s scale) and integer-table; `perf record`
of each, three launches, reported by symbol; `perf annotate` of Halo's
sampled symbols; and the disassembly of the table functions with their
instruction counts.

### Attribution result

[Run 37639344751](https://github.com/Ming-Research/Halo-wf/actions/runs/37639344751),
artifact `halo-tables-profile`: an AMD EPYC 7763 guest sampling `task-clock`,
Halo at main `99936d6e6` (before the string-key lookup), `wf-8b647edbbc95`
with clang 22.1.8; both engines print the same sums. Shares of samples,
three launches:

- Binary-trees, Halo: `node_find` 12.2–12.5%, the `Call` arm 5.3–5.6%,
  `enter_lua` 5.4–5.6%, `push_frame` 3.3–3.6%, `calloc` 3.6–3.7%,
  `gc_mark` 2.8–2.9%, page faults 2.4–2.5%, `collect_if_due` 2.3–2.4%,
  `malloc` 2.2–2.3%, the rest in dispatch arms. PUC: `luaV_execute`
  18.9–19.3%, `luaH_get` 12.0–13.1%, `sweeplist` 8.0–8.7%, `propagatemark`
  5.7–6.1%, `free` 5.2–6.2%, `luaD_precall` 3.5–4.0%, `malloc` 2.7–3.8%.
  Launch 1's annotation holds about 13,100 Halo samples against about 7,300
  of PUC's, `node_find` 2,352 of them against 1,131 in `luaH_get`.
- Integer-table, Halo: arms 13 and 11 (the table store and load) 27.7–28.0%
  and 25.2–26.1%, two more arms 17.8–19.1% together, `rehash` 7.0–10.1%,
  `table_set` 6.0–6.7%, `gc_mark` 5.6–5.9%. PUC: `luaV_execute` 38.7–40.0%,
  `luaH_get` 33.7–34.2%, `luaV_settable` 7.2–8.2%, `newkey` 3.3–3.5%.

In binary-trees, every table constructor stores `item`, `left` and `right`
through `table_set`, which looks the key up with `node_find` before
inserting. Launch 1's annotation of `node_find`:

- 19.7% of its samples follow the `div` that computes `hash % n` for a
  string key in `main_position`. PUC's `hashstr` masks the hash instead
  (`lmod`, with node counts always powers of two), and `main_position`'s own
  doc names that rule, but its code divides by the node count.
- 36.9% fall on loading each visited node's key and the indirect jump on its
  kind in `equal`, which compares every kind. PUC's `luaH_get` sends a string
  key to `luaH_getstr`, a loop that compares string pointers only. Since the
  string-key lookup, Halo's reads do the same, but its writes do not.

Both are work Halo's source asks for; no code the compiler adds beyond the
source shows in these functions. The dispatch arms that carry most of
integer-table's time are left to `loop { match }` dispatch; integer-table's
`rehash` and `gc_mark` remain for a later candidate.

### String keys in table writes: criterion, recorded before the change

Change: string and boolean keys take their main position by masking the
hash with the node count less one, as PUC's `hashpow2` does, which equals
the present modulus for every power-of-two node count, the only counts Lua
creates, and keeps insertion and lookup consistent for any count; a table
write finds an existing string key by its cached hash and handle comparison,
as reads have since the string-key lookup; and `table_get_str` drops its
power-of-two guard, since the specialised and generic lookups then mask
alike for every node count.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of the
branch before the change (the string-key lookup's final engine,
`448c217a2`) against the branch after it, with a twin of the before binary:
the binary-trees kernel's median falls at least 3%, by more than both ranges
and the twin's difference; no kernel is slower beyond its larger range and
the twin's; `--check-module pkg::vm` takes at most 1.25 times as long; and
`make check` passes. Otherwise the change is reverted with its measurements
kept.

The 14900K went out of service before this ran. By the owner's direction
(Q93), the comparison runs instead on the M5 Air (Apple M5, 10 cores, 24 GB,
macOS, arm64), under Whitefoot's `run-check.pl` lock, with the same pairs,
twin and thresholds, recorded here before it runs; its result is an M5
result.

### String keys in table writes: result on the M5 Air

On the M5 Air (Apple M5, macOS 27.0.1, arm64), under `run-check.pl`'s lock:
the string-key lookup's final engine (`448c217a2`) against this branch's
engine (`a5962bf8b`), both built with full LTO by `wf-8b647edbbc95`'s
macOS compiler (base and twin identical by hash, `a89a07cd432d`, branch
`715d76e285c3`), six interleaved pairs, binary-trees at depth 14, with
Redis 7.0.15's Lua built from source as the independent reference. One
sample pair per kernel took 7.2 s. Medians in seconds:

| Kernel | Before | After | Ratio | Before range | After range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1053 | 0.1097 | 1.041 | 3.66% | 2.51% | 1.012 |
| loop | 0.3564 | 0.3576 | 1.003 | 0.80% | 4.87% | 0.997 |
| integer-table | 0.2568 | 0.2531 | 0.986 | 3.11% | 2.62% | 1.002 |
| string-key | 0.0188 | 0.0188 | 1.002 | 2.18% | 2.72% | 0.994 |
| concat | 0.0699 | 0.0747 | 1.068 | 10.18% | 7.41% | 1.014 |
| sort | 0.1574 | 0.1574 | 1.000 | 5.37% | 2.20% | 0.996 |
| binary-trees | 1.3417 | 1.2864 | 0.959 | 3.00% | 0.64% | 0.999 |

`--check-module pkg::vm`: before 5.95 and 5.91 s, after 5.93 and 5.83 s.

**The criterion is not met, and the change is reverted with its
measurements kept.** Binary-trees falls 4.1%, beyond both ranges and the
twin, but fib is 4.1% slower, beyond its larger range (3.66%) and the
twin's difference (1.2%); fib's hot path reads no table, so a layout change
in the rebuilt binary is the likely cause, which the criterion does not
excuse. Both results lie within about a point of their bounds, so the
comparison is repeated on the 14900K when it returns before the change is
given up (Q93).

### String keys in table writes: retried on the 14900K

The M5 result lay within about a point of the criterion's bounds, so, as the
owner chose (Q93), the comparison was repeated on the 14900K once it was
back, against the criterion as first recorded and recorded before it ran (on
the measurement-only branch `claude/halo-strwrite-retry`, `f24cf32b5`):
main `2945f3b99`, which holds the string-key lookup, against the same change
applied on it (the write change `a5962bf8b`, cherry-picked), six interleaved
full-LTO pairs with a twin.
[Run 37726526163](https://github.com/Ming-Research/Halo-wf/actions/runs/37726526163),
medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1055 | 0.1062 | 1.007 | 0.55% | 1.80% | 0.996 |
| loop | 0.4326 | 0.4318 | 0.998 | 0.69% | 0.88% | 1.001 |
| integer-table | 0.4995 | 0.4975 | 0.996 | 3.27% | 9.08% | 1.003 |
| string-key | 0.0259 | 0.0258 | 0.997 | 39.82% | 0.95% | 1.002 |
| concat | 0.0734 | 0.0734 | 1.001 | 0.51% | 0.85% | 1.003 |
| sort | 0.1760 | 0.1729 | 0.982 | 1.60% | 2.10% | 1.002 |
| binary-trees | 1.9083 | 1.8711 | 0.981 | 1.99% | 1.62% | 1.009 |

`--check-module pkg::vm`: main 7.798 and 7.577 s, branch 7.539 and 7.614 s.

**The criterion is not met; the change stays reverted.** Binary-trees falls
1.9%, short of the 3% required; no kernel is slower beyond its bounds, so the
M5 run's slower fib does not recur here.

## Marking only collectable values

### Criterion, recorded before the change

The collector marks a table's contents by calling `gc_mark` for every array
slot and for every node's key and value (`mark_table_contents`,
`lib/halo/heap/gc.wf`), and `gc_mark` dispatches on the value's kind. In
integer-table, whose ten-million-slot array holds only numbers, `gc_mark`
takes 5.6–5.9% of Halo's samples and half of its own samples fall on that
dispatch ([run 37639344751](https://github.com/Ming-Research/Halo-wf/actions/runs/37639344751),
a hosted EPYC guest reading shares of samples, artifact `halo-tables-profile`).
PUC's `traversetable` marks each value through `markvalue`, which tests in
line that the value is collectable before calling `reallymarkobject`.
Change: `mark_table_contents` calls `gc_mark` only for a string, table or
closure value; numbers, nil, booleans and builtins, which name no object,
are skipped in line.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of main before
the change against the branch after it, with a twin of the before binary:
the integer-table kernel's median falls at least 3%, by more than both
ranges and the twin's difference; no kernel is slower beyond its larger
range and the twin's; `--check-module pkg::vm` takes at most 1.25 times as
long; and `make check` passes, the collector's root controls and the oracle
under collector stress included. Otherwise the change is reverted with its
measurements kept.

The 14900K went out of service before this ran. By the owner's direction
(Q93), the comparison runs instead on the M5 Air (Apple M5, 10 cores, 24 GB,
macOS, arm64), under Whitefoot's `run-check.pl` lock, with the same pairs,
twin and thresholds, recorded here before it runs; its result is an M5
result.

### Result on the M5 Air

On the M5 Air (macOS 27.0.1, arm64), under `run-check.pl`'s lock: main
`89a9ce23a` against this branch's engine (`82d43d67e`), both built with
full LTO by `wf-8b647edbbc95`'s macOS compiler (base and twin identical by
hash, `492f8b78456f`, branch `cea6b1399c62`), six interleaved pairs,
binary-trees at depth 14. Medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1137 | 0.1110 | 0.976 | 4.23% | 527.47% | 0.989 |
| loop | 0.3734 | 0.3702 | 0.991 | 2.49% | 4.87% | 1.003 |
| integer-table | 0.2540 | 0.2507 | 0.987 | 3.80% | 18.98% | 1.022 |
| string-key | 0.0207 | 0.0199 | 0.961 | 6.01% | 8.70% | 1.010 |
| concat | 0.0848 | 0.0739 | 0.872 | 30.72% | 10.96% | 1.018 |
| sort | 0.1601 | 0.1580 | 0.987 | 2.33% | 7.84% | 0.994 |
| binary-trees | 1.3712 | 1.3759 | 1.003 | 7.08% | 6.15% | 1.006 |

`--check-module pkg::vm`: main 6.03 and 6.14 s, branch 6.03 and 6.16 s.

Single launches far from the rest (fib 0.6941 s against 0.108–0.114 s,
concat 0.0993 s, integer-table 0.2907 s) put the ranges well beyond any
effect the criterion asks for; a code review ran on the machine at the same
time. The spread is too large to decide, so the comparison is repeated once
with nothing else running, and that repeat decides; both runs stay recorded.

The repeat, the same three binaries, run after the review had finished
(another session's process still ran; load average 2.8 rising to 3.9):

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1178 | 0.1164 | 0.988 | 10.48% | 9.21% | 1.002 |
| loop | 0.3900 | 0.3908 | 1.002 | 35.88% | 70.90% | 1.012 |
| integer-table | 0.2681 | 0.2692 | 1.004 | 9.59% | 15.78% | 1.014 |
| string-key | 0.0223 | 0.0216 | 0.969 | 4.04% | 3.20% | 0.998 |
| concat | 0.0748 | 0.0733 | 0.980 | 8.48% | 7.60% | 0.990 |
| sort | 0.1608 | 0.1601 | 0.996 | 4.87% | 11.31% | 0.995 |
| binary-trees | 1.5027 | 1.4685 | 0.977 | 56.66% | 27.50% | 1.013 |

**The criterion is not met, and the change is reverted with its
measurements kept.** Integer-table's median is 1.004 times main's in the
repeat and 0.987 in the first run, neither the 3% fall the criterion asks
for. The M5's spread in both runs (single launches up to 6.3 times their
kernel's median in the first run and 1.7 times in the repeat, which a
fanless machine under sustained load and other processes on it can
produce) is larger than the effect sought, so these
runs cannot show a gain of a few percent either; the candidate can be tried
again on the 14900K.

### Retried on the 14900K

The M5 runs' spread exceeded the effect sought, so, as the owner chose
(Q93), the comparison is repeated on the 14900K now that it is back, against
the criterion as first recorded: main `2945f3b99` against this branch with
the change applied again on it, six interleaved full-LTO pairs with a twin.
Kept only if integer-table falls at least 3%, by more than both ranges and
the twin's difference, no kernel is slower beyond its larger range and the
twin's, `--check-module pkg::vm` takes at most 1.25 times as long, and
`make check` passes, the collector's root controls and the oracle under
collector stress included; otherwise the change is reverted again.

Result: [run 37726529192](https://github.com/Ming-Research/Halo-wf/actions/runs/37726529192),
main `2945f3b99` against the branch at `f2d9ac43d`, whose engine differs only
in `lib/halo/heap/gc.wf` (the run's own `git diff --stat`); medians in
seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1060 | 0.1056 | 0.996 | 2.33% | 1.77% | 0.996 |
| loop | 0.4327 | 0.4334 | 1.002 | 1.04% | 1.22% | 0.999 |
| integer-table | 0.4924 | 0.4847 | 0.984 | 3.01% | 1.41% | 1.006 |
| string-key | 0.0259 | 0.0257 | 0.994 | 1.87% | 1.81% | 1.000 |
| concat | 0.0737 | 0.0737 | 1.000 | 34.65% | 0.87% | 0.999 |
| sort | 0.1740 | 0.1732 | 0.995 | 2.16% | 0.37% | 1.003 |
| binary-trees | 1.9198 | 1.9189 | 1.000 | 2.77% | 4.21% | 1.003 |

`--check-module pkg::vm`: main 7.604 and 7.628 s, branch 7.658 and 7.540 s.
`make check` passed at the branch
([run 37726529195](https://github.com/Ming-Research/Halo-wf/actions/runs/37726529195)).

**The criterion is not met, and the change is reverted again.** Integer-table
falls 1.6%, short of the 3% required; no kernel is slower beyond its bounds.
Integer-table's median was 1.6% lower in this run, within main's 3.01%
range, so these runs do not establish a saving from skipping `gc_mark` for
values that name no object.

## The share of table growth on the 14900K

### Criterion, recorded before it runs

On a GitHub-hosted EPYC guest, `rehash` took 7.0–10.1% of integer-table's
samples ([attribution result](#attribution-result)). Two candidates chosen
from those hosted shares, string-key writes and marking only collectable
values, were each expected near 5% and measured under 2% on the 14900K, so
hosted shares overstate what a change can gain there. `rehash` builds a new
array and copies the old one into it element by element, so that a failed
insertion leaves the table unchanged; replacing that with Whitefoot's
in-place `grow` gives up the guarantee, a design decision for the owner.

Question: how much of integer-table's and binary-trees' time on the 14900K
is table growth? Run: on the 14900K, Halo at this branch's base built with
full LTO as `run.py` builds it, integer-table and binary-trees at depth 14
(`run.py`'s scale), three launches each; `perf record` of `cycles`, reported
by symbol without children for each symbol's own share, and once more with
call graphs (LBR, or DWARF unwinding where LBR is unavailable) reported with
children for `rehash`'s inclusive share, its allocation and copying included.

Reading: a change to `rehash` is prepared, with its own criterion and the
design card for the guarantee, only if `rehash`'s inclusive share is at least
5% of Halo's samples in every launch of integer-table or of binary-trees;
otherwise table growth is not selected and this section records why. The
kernels exercise no string comparison, pattern matching, `table.concat` or
codec, so this run says nothing about the slow-executor split in library
functions (`docs/todo.md`).

### Result

[Run 37752821669](https://github.com/Ming-Research/Halo-wf/actions/runs/37752821669),
artifact `halo-growth-profile`: the 14900K (a Hyper-V guest, 32 CPUs),
Halo at main `5e98dabf5` with `wf-8b647edbbc95` and clang 22.1.8, full LTO;
LBR was unavailable in the guest, so call graphs used DWARF unwinding. Every
launch printed the kernel's checksum. Shares of `cycles` samples:

| Kernel, launch | `rehash` own | `rehash` with children |
|---|---:|---:|
| integer-table 1 | 9.39% | 29.87% |
| integer-table 2 | 12.65% | 29.91% |
| integer-table 3 | 9.02% | 30.16% |
| binary-trees 1–3 | below 0.3% | below 0.3% |

In binary-trees only `insert_parts` appears (1.43–1.67%). Integer-table's
remaining time is the table store and load arms (20.5–25.8% each), arm 66
(8.2–8.6%), `table_set`, `collect_if_due` and `gc_mark`. The reports name no callees
under `rehash`: the guest hides kernel symbols and the call-graph reports were
summarized without their chains. That most of its inclusive share beyond its
own 9–12.6% is allocation, page faults on the new array and freeing the old
one, which each growth performs, is an inference from what `rehash` does,
consistent with launch 1's call-graph report, where an unresolved kernel
entry address carries 18.47% with its children and libc's `free` reaching
`munmap` 3.07%.

**The criterion is met for integer-table**: `rehash` takes about 30% of its
samples in every launch, so a change is prepared. The bounded growth
decision ([growth](../../../design/halo/heap/tables/growth.md)) is reopened
by its own condition, retained-prefix allocation and copying measured as a
bottleneck. The guarantee needs no trade: every way `rehash` can fail, a
size that overflows, an insertion that finds no free node, and a charge
beyond the memory limit, can be decided before the table's array is
touched, so the array can grow in place and still change only on success.

### Growing the array in place: criterion, recorded before the change

Change: `rehash` builds the new node vector from the old array's tail and
the old nodes and charges the size difference first, as now, and only then
resizes the table's array: Whitefoot's `grow` in place when it gets larger,
filling the added slots with nil, instead of allocating a new array and
copying the retained prefix. A shrinking array keeps the current
replacement. Lua's size selection and reinsertion order are unchanged.

Kept only if, in six interleaved full-LTO pairs on the 14900K against main
with a twin, integer-table's median falls at least 5%, by more than both
ranges and the twin's difference; no kernel is slower beyond its larger
range and the twin's; `--check-module pkg::vm` takes at most 1.25 times as
long; and `make check` passes, the oracle under collector stress and the
collector's root controls included. Otherwise the change is reverted and
this section records the result.

### Growing the array in place: result

[Run 37756391939](https://github.com/Ming-Research/Halo-wf/actions/runs/37756391939),
artifact `halo-bench-grow`: main `5e98dabf5` against the branch at `31b92e5`
(the change is `6f49ca6`), whose engine differs only in
`lib/halo/heap/tables.wf`, six interleaved full-LTO pairs on the 14900K with
`wf-8b647edbbc95`; medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1056 | 0.1054 | 0.998 | 1.08% | 2.17% | 1.000 |
| loop | 0.4334 | 0.4333 | 1.000 | 0.55% | 1.23% | 0.997 |
| integer-table | 0.4934 | 0.4933 | 1.000 | 1.63% | 0.52% | 0.997 |
| string-key | 0.0262 | 0.0258 | 0.985 | 4.95% | 2.96% | 0.997 |
| concat | 0.0736 | 0.0734 | 0.998 | 0.32% | 1.74% | 1.003 |
| sort | 0.1762 | 0.1752 | 0.994 | 3.68% | 1.74% | 1.000 |
| binary-trees | 1.9150 | 1.9282 | 1.007 | 4.07% | 2.73% | 0.992 |

`--check-module pkg::vm`: main 7.660 and 7.551 s, branch 7.595 and 7.558 s.
`make check` passed at `5bbaabb3c`, including the unsorted iteration case
`lua-core/table-growth-order` ([run 37754466451](https://github.com/Ming-Research/Halo-wf/actions/runs/37754466451)).

**The criterion is not met, and the change is reverted.** Integer-table's
median is unchanged. The change did not remove the work it targeted:
Whitefoot lowers `grow` as a fresh `malloc`, a `memmove` of the filled slots
and a `free` of the old block (`compiler/src/backend/emitter/runs.rs`,
`emit_window_grow`, at `8b647edbb`), never `realloc`, as its design records
as a provisional choice awaiting performance grounds
(`design/compiler/storage-representation.md`), so the branch still allocates
a new array, copies the retained prefix and frees the old one at each growth.
That this retained work is why the time did not move is the leading
hypothesis, not a measured attribution, and whether in-place reallocation
would save time is untested; both are a Whitefoot question (`docs/todo.md`,
*Whitefoot requirements*).

## Reading by-value parameters in place, measured

### Criterion, recorded before measuring

[The entry copy of a by-value parameter](#the-entry-copy-of-a-by-value-parameter-measured)
(on the call-path branch, pull request 12)
could not be timed because Whitefoot's in-place rule then applied only to
functions without a branch. The loopmatch session widened the rule to
functions with branches (Whitefoot branch `claude/in-place-branches`, release
`wf-exp-8eaba144a41f` on main `c18e6708b`); its gate asserts that every
function of the six-function witness lost its entry copy. Its control is the
release of the same main commit, `wf-c18e6708b6cc`.

Comparison: Halo main built with full LTO by each release, six interleaved
pairs over the seven kernels on the 14900K with a twin of the control build,
and both builds' disassembly of `push_frame`. The comparison tests the
hypothesis only if the experiment build's `push_frame` loses its entry copy.
A fib median below the control build's by more than both ranges and the
twin's difference is a measured cost of the entry copy; anything else is no
evidence of one. No kernel may be slower beyond its larger range and the
twin's difference for the result to count in the rule's favour. The result
goes to the loopmatch session either way; no Halo source changes.

### Result

[Run 37771086458](https://github.com/Ming-Research/Halo-wf/actions/runs/37771086458),
artifact `halo-bench-inplace`: Halo at this branch's base, main `76c3c03f1`
(the run checked out `3def116`, which changes no source), built by `wf-c18e6708b6cc`
(control) and `wf-exp-8eaba144a41f` (experiment) with clang 22.1.8, on the
14900K. The experiment's `push_frame` no longer copies the incoming 80-byte
`Frame` at entry: the control's begins with five 128-bit loads from the
incoming pointer and five stores to its own stack slot, the experiment's
reads through the pointer, 91 against 85 instructions. Medians in seconds,
six interleaved pairs:

| Kernel | Control | Experiment | Ratio | Control range | Experiment range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1055 | 0.1014 | 0.962 | 2.57% | 0.77% | 1.009 |
| loop | 0.4333 | 0.4321 | 0.997 | 0.74% | 0.33% | 0.996 |
| integer-table | 0.4952 | 0.4970 | 1.004 | 1.95% | 3.24% | 0.998 |
| string-key | 0.0257 | 0.0256 | 0.997 | 1.29% | 2.15% | 0.996 |
| concat | 0.0735 | 0.0728 | 0.990 | 0.52% | 1.04% | 0.999 |
| sort | 0.1750 | 0.1762 | 1.007 | 1.68% | 4.04% | 1.007 |
| binary-trees | 1.8924 | 1.8717 | 0.989 | 2.56% | 4.32% | 1.002 |

**The criterion is met.** Fib's median is 3.8% below the control's, beyond
both ranges (2.57% and 0.77%) and the twin's 0.9% difference, and no kernel
is slower beyond its bounds. The widened rule as a whole makes fib about 4%
faster on the 14900K. It applies to every function that takes an aggregate by
value, so the comparison does not isolate `push_frame`'s copy, the one fib's
earlier profile pointed at, from the others it removes. This is the evidence
the loopmatch session takes to the owner for widening Whitefoot's in-place
parameter rule.
Halo's source is unchanged.

## Growing the array in place with a reallocating grow

### Criterion, recorded before measuring

[Growing the array in place](#growing-the-array-in-place-result) left
integer-table unchanged with `wf-8b647edbbc95`, whose `grow` allocates,
copies and frees. The paged session built `wf-exp-4f6a0c240d2c`: the same
compiler with `grow` lowered as `realloc` and nothing else changed. This
branch is main `0def88248` with the reverted in-place change `6f49ca6`
applied again (`lib/halo/heap/tables.wf` only).

Builds, full LTO, on the 14900K: main with the pin (base), this branch with
the pin, and this branch with the experiment release. Six interleaved pairs
over the seven kernels for each of: base against its twin (noise), base
against the branch with the experiment (the change as it would ship), and the
branch with the pin against the branch with the experiment (the compiler's
share).

The change counts as a win, and goes to the paged session for a main-line
`grow` lowering, only if integer-table's median with the experiment falls at
least 5% below the base's, by more than both ranges and the twin's
difference, with no kernel slower beyond its larger range and the twin's
difference. The third comparison attributes the gain; it does not change the
verdict.

### Result

[Run 37773076340](https://github.com/Ming-Research/Halo-wf/actions/runs/37773076340),
artifact `halo-bench-realloc`: base main `0def88248` with `wf-8b647edbbc95`;
the branch (`lib/halo/heap/tables.wf` only differs, per the run's
`git diff --stat`) with the same release and with `wf-exp-4f6a0c240d2c`;
clang 22.1.8, full LTO, the 14900K. The experiment build calls `realloc`
from 430 sites, the pinned build from none. Medians in seconds, six
interleaved pairs; twin ratios are the base against its twin.

The change as it would ship, base against the branch with the experiment:

| Kernel | Base | Branch, experiment | Ratio | Base range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1051 | 0.1064 | 1.012 | 1.04% | 2.07% | 0.998 |
| loop | 0.4325 | 0.4308 | 0.996 | 0.80% | 0.66% | 1.002 |
| integer-table | 0.4963 | 0.4268 | 0.860 | 2.53% | 1.14% | 1.004 |
| string-key | 0.0260 | 0.0258 | 0.993 | 1.19% | 0.49% | 0.997 |
| concat | 0.0740 | 0.0735 | 0.993 | 1.43% | 2.68% | 0.999 |
| sort | 0.1763 | 0.1718 | 0.975 | 2.13% | 0.95% | 1.003 |
| binary-trees | 1.9046 | 1.8931 | 0.994 | 1.78% | 2.06% | 1.005 |

The compiler's share, the branch with the pin against the branch with the
experiment:

| Kernel | Branch, pin | Branch, experiment | Ratio | Pin range | Experiment range |
|---|---:|---:|---:|---:|---:|
| fib | 0.1056 | 0.1065 | 1.008 | 1.61% | 1.26% |
| loop | 0.4319 | 0.4320 | 1.000 | 0.58% | 0.39% |
| integer-table | 0.4916 | 0.4246 | 0.864 | 2.35% | 1.74% |
| string-key | 0.0260 | 0.0259 | 0.998 | 1.16% | 3.53% |
| concat | 0.0735 | 0.0735 | 1.000 | 1.80% | 1.68% |
| sort | 0.1767 | 0.1718 | 0.972 | 1.70% | 1.66% |
| binary-trees | 1.8988 | 1.8761 | 0.988 | 0.74% | 1.45% |

**The criterion is met.** Integer-table's median is 14.0% below the base's,
beyond both ranges (2.53% and 1.14%) and the twin's 0.4% difference; fib's
1.2% is within its larger range plus the twin's difference, and no other
kernel is slower. Nearly all of the gain is the compiler's: the same source
is 13.6% faster on integer-table with the reallocating `grow`, as
[the earlier result](#growing-the-array-in-place-result) found the source
change alone neutral with the copying `grow`. Sort's 2.5–2.8% gain also comes
from the compiler and was not predicted. The in-place source change stays out
of main until Whitefoot's main line lowers `grow` through `realloc`; it is
reverted on this branch, which keeps only this record, and is reapplied with
the Whitefoot release that adopts the lowering (`docs/todo.md`, *Whitefoot
requirements*).

## Whitefoot wf-691ea8106920 upgrade

### Question, recorded before measuring

`whitefoot.pin` moves from `wf-8b647edbbc95` (Whitefoot `8b647edbb`,
specification v0.94) to `wf-691ea8106920` (`691ea8106`, v0.102), the first
main release with `loop { match }` and `continue` (v0.101), which Halo's
dispatch rewrite needs. Between them the specification also adds directory
operations (v0.95, v0.98), closed-term recursion cycles (v0.96), PAR-2
extensions (v0.97, v0.102), reinitializing a dead linear binding (v0.99) and
reference-path identity (v0.100); Halo's source needed no change, and `make
check` passes with the new release. How do the kernels and the vm
module-check time move? Whitefoot-kit's upgrade step 5 asks for this
comparison; it reports the difference and rejects nothing.

Comparison: Halo main built with each release, six interleaved full-LTO
pairs over the seven kernels, a twin of the old build, and two interleaved
module-check samples per compiler, on the 14900K.

### Result

[Run 37791242990](https://github.com/Ming-Research/Halo-wf/actions/runs/37791242990),
artifact `halo-bench-upgrade`: Halo at `f5203e4` (main's engine) built by
`wf-8b647edbbc95` and by `wf-691ea8106920` with clang 22.1.8, on the 14900K;
medians in seconds, six interleaved pairs:

| Kernel | Old | New | Ratio | Old range | New range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1052 | 0.1051 | 1.000 | 0.72% | 1.15% | 1.004 |
| loop | 0.4317 | 0.4325 | 1.002 | 0.59% | 0.50% | 1.000 |
| integer-table | 0.4931 | 0.4937 | 1.001 | 3.11% | 7.88% | 1.008 |
| string-key | 0.0258 | 0.0258 | 1.000 | 2.42% | 1.14% | 0.988 |
| concat | 0.0735 | 0.0747 | 1.015 | 24.18% | 2.37% | 1.001 |
| sort | 0.1760 | 0.1750 | 0.994 | 1.73% | 1.67% | 1.003 |
| binary-trees | 1.9220 | 1.9256 | 1.002 | 1.87% | 0.70% | 0.998 |

`--check-module pkg::vm`: old 7.631 and 7.525 s, new 7.613 and 7.780 s.

No kernel moves beyond its larger range and the twin's difference, a test
chosen after measuring since the question set no criterion. Six kernels show
no difference. Concat passes that test only because one old-side run (pair
2, 0.0911 s) widened the old range to 24%: without it, all six new runs
(0.0741–0.0759 s) are slower than the five other old runs (0.0733–0.0737 s),
by 1.3–3.5% per pair, while the twin's per-pair ratios span 0.972–1.010. A
concat slowdown of about 1.5% with the new release is therefore possible and
unresolved; these seven kernels on the 14900K show nothing else.

## The dispatch as loop { match }

### Question and reading, recorded before measuring

`run` was a guaranteed self-tail call only because Whitefoot's checker
refused the natural `loop { match }` (INV-1); Whitefoot v0.101 (#270) closed
that, and this branch writes `run` as `loop { match }` with the three window
facts as header invariants, the 18 hot arms continuing the loop and the
others reaching the backedge through the shared epilogue. The owner's
direction is the natural form, so the rewrite is kept whatever the timing.
How do the kernels move?

Comparison: the same compiler (`wf-691ea8106920`) building this branch's
base `baa2225` (the self-tail `run`) and this branch, six interleaved
full-LTO pairs over the seven kernels with a twin of the base, and two
module-check samples each, on the 14900K. Reading: a kernel slower beyond its
larger range and the twin's difference is a cost of the compiler's lowering
of the loop form, reported to the loopmatch session as input to its second
phase (lowering the natural form), not a reason to restore the self-tail
call; a kernel faster beyond those bounds is reported the same way.

### Result

[Run 37793482368](https://github.com/Ming-Research/Halo-wf/actions/runs/37793482368),
artifact `halo-bench-loopmatch`: `wf-691ea8106920`, clang 22.1.8, full LTO,
the self-tail base `baa2225` against this branch at `060ea20` (only
`dispatch.wf` and `module.wfm` differ in source, per the run's `git diff
--stat`), on the 14900K; medians in seconds, six interleaved pairs:

| Kernel | Self-tail | Loop | Ratio | Self-tail range | Loop range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1104 | 0.1120 | 1.014 | 4.53% | 5.94% | 1.002 |
| loop | 0.4515 | 0.4535 | 1.005 | 3.31% | 2.05% | 0.999 |
| integer-table | 0.5017 | 0.5076 | 1.012 | 4.86% | 7.07% | 0.993 |
| string-key | 0.0263 | 0.0266 | 1.014 | 5.22% | 5.02% | 1.005 |
| concat | 0.0751 | 0.0755 | 1.006 | 2.13% | 1.43% | 0.995 |
| sort | 0.1883 | 0.1858 | 0.987 | 20.01% | 12.57% | 1.002 |
| binary-trees | 1.9175 | 1.9336 | 1.008 | 5.40% | 7.61% | 0.994 |

**The two builds are byte-identical.** The run's manifest gives the same
SHA-256 (`6761c46c…`) for the self-tail build, its twin and the loop build,
and every launch record names the same binary for both sides. The workflow
built each side from its own source (`git diff --stat` shows `dispatch.wf`
and `module.wfm` differ, and the two module checks took different times),
and the same workflow gave different binaries for different sources in the
table-growth and post-catch runs, so this is not a stale build: Whitefoot
lowers the `loop { match }` dispatch to exactly the machine code of the
guaranteed self-tail call. The loop form costs nothing at run time, and the
table above is a second twin comparison: its differences, such as fib's
0.1104 s here against 0.1050 s for the same binary in this run's twin
comparison, are this run's noise. Every performance measurement made on the
self-tail form therefore holds for the loop form with this compiler.

The vm module check takes 1.17 times as long (7.774 and 7.638 s against
8.997 and 8.970 s), a cost of checking the loop form; proving the header
invariants on every backedge is the likely cause, not measured here.

## pcall's post-catch field lookup

### Criterion, recorded before measuring

The change that makes `pcall` look up its error field through `__index` as a
resumable continuation (owner's choice A) also changes the dispatch epilogue
that instructions without a direct tail call return through: `checked_step`
now receives the VM and the host environment so it can start a scheduled
post-catch lookup, and `Step` gains a `PostCatch` variant. None of the seven
kernels raises an error, so a change in their time is this change's overall
effect on the normal path, through the epilogue or through code layout and
inlining; the comparison does not separate those.

Comparison: main `5885f9ab4`, which this branch has merged, against the
branch with the change, same compiler (`wf-8b647edbbc95`), six interleaved
full-LTO pairs on the 14900K with a twin of main. Kept only if no kernel is
slower beyond its larger range and the twin's difference, and
`--check-module pkg::vm` takes at most 1.25 times as long; otherwise the
epilogue change is reworked before merging.

### Result

[Run 37776993971](https://github.com/Ming-Research/Halo-wf/actions/runs/37776993971),
artifact `halo-bench-postcatch`: main `5885f9ab4` against the branch at
`cdc423c` (ten engine files differ, per the run's `git diff --stat`), six
interleaved full-LTO pairs on the 14900K; medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1052 | 0.1261 | 1.198 | 0.80% | 1.17% | 1.003 |
| loop | 0.4324 | 0.4514 | 1.044 | 0.88% | 0.38% | 0.999 |
| integer-table | 0.4949 | 0.4923 | 0.995 | 1.24% | 2.10% | 0.994 |
| string-key | 0.0260 | 0.0259 | 0.994 | 2.34% | 1.78% | 1.000 |
| concat | 0.0735 | 0.0892 | 1.214 | 3.82% | 4.36% | 1.004 |
| sort | 0.1766 | 0.1988 | 1.126 | 2.56% | 3.82% | 0.999 |
| binary-trees | 1.9052 | 2.1124 | 1.109 | 1.72% | 2.90% | 1.000 |

`--check-module pkg::vm`: main 7.522 and 7.555 s, branch 7.784 and 7.761 s.

**The criterion is not met**: five kernels are slower far beyond their
bounds. The binaries in the artifact show why: every dispatch arm of `run`
grew by 700–950 bytes and its stack frame from 0x30 to 0xa0 bytes, and each
arm now contains an indirect non-tail call; `pcall_lookup_drain`, which runs
Lua through a nested `run`, was inlined into the shared epilogue of every
arm. The epilogue change is reworked so that a `PostCatch` step never reaches
`run`: the cold paths that produce it drain it before returning.

### Rework

The dispatch function and `checked_step` are restored to main. Post-catch
requests now belong to the cold unwind result, which generic failure paths
and resumed library callbacks drain before returning a dispatch step. Call
preparation handles its own failures inside `prepare`; the non-generic fast
stores and collector failures share ordinary catch completion for their
string-only errors.
Inlining, oracle behavior and performance remain to be checked in CI.

The subsequent rework records the post-catch lookup index in the VM and uses
the existing `Budget` exit to reach the generic driver, which clears and
consumes the request before interpreting the exit, leaving the instruction
budget, dispatch, handlers and `Step` unchanged.

### Retried after the rework

[Run 37787718241](https://github.com/Ming-Research/Halo-wf/actions/runs/37787718241),
artifact `halo-bench-postcatch-retry`: main `5885f9ab4` against the branch at
`0f09d8b`, whose `dispatch.wf`, `handlers.wf` and `continuations.wf` equal
main's, the same criterion; medians in seconds:

| Kernel | Main | Branch | Ratio | Main range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1050 | 0.1036 | 0.987 | 0.67% | 1.21% | 1.000 |
| loop | 0.4315 | 0.4315 | 1.000 | 0.38% | 0.38% | 1.002 |
| integer-table | 0.4959 | 0.4949 | 0.998 | 1.95% | 2.32% | 0.991 |
| string-key | 0.0260 | 0.0259 | 0.993 | 3.56% | 2.68% | 1.001 |
| concat | 0.0735 | 0.0739 | 1.005 | 2.25% | 6.05% | 0.999 |
| sort | 0.1771 | 0.1768 | 0.998 | 5.04% | 2.12% | 1.003 |
| binary-trees | 1.9072 | 1.9125 | 1.003 | 2.27% | 0.60% | 1.003 |

`--check-module pkg::vm`: main 7.619 and 7.531 s, branch 7.746 and 7.820 s
(at most 1.04 times).

**The criterion is met**: no kernel is slower beyond its larger range and the
twin's difference, and the module check stays within 1.25 times.

## The handler word in Halo's dispatch

### Criterion, recorded before measuring

The loopmatch session's second phase lowers a `loop { match }` dispatch
through a handler word stored in each matched value (Whitefoot, the two
handler-word commits on `691ea8106`, release `wf-exp-78ff1a001486`): each
`Cell` carries the address of its arm, 4-byte aligned, so Halo's `Cell`
grows from 12 to 20 bytes. The control is `wf-691ea8106920`, the same
commit without them. The loopmatch session asks whether Halo's `run`, now
`loop { match }`, gets slower. A prototype on the former self-tail form
measured fib 2.3% and loop 1.8% faster.

Comparison: main `c78426ef8` (`run` as `loop { match }`) built with each release,
six interleaved full-LTO pairs over the seven kernels with a twin of the
control build, on the 14900K; each build's `--dispatch-ledger` output is
kept, and the experiment's must contain "dispatches through the handler word
in each" for `run`, or the comparison does not test the handler word.

The loopmatch session's criterion: fib's and loop's medians with the
experiment are each no more than 2% above the control's. The other kernels
are reported, slower beyond their larger range and the twin's difference
or not.

### Result

[Run 37837639995](https://github.com/Ming-Research/Halo-wf/actions/runs/37837639995),
artifact `halo-bench-handler-word`: Halo main `c78426ef8` built by
`wf-691ea8106920` (control) and `wf-exp-78ff1a001486` (handler word), clang
22.1.8, full LTO, on the 14900K. The experiment's dispatch ledger contains
"dispatches through the handler word in each Cell" for `run` (and for
`cjson_decode`'s and `library_table`'s loops); the control's does not. The
binaries differ. Medians in seconds, six interleaved pairs:

| Kernel | Control | Handler word | Ratio | Control range | Handler-word range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1030 | 0.1045 | 1.015 | 0.45% | 0.94% | 0.999 |
| loop | 0.4346 | 0.4249 | 0.978 | 1.50% | 0.95% | 1.001 |
| integer-table | 0.4994 | 0.4952 | 0.992 | 2.79% | 3.98% | 1.003 |
| string-key | 0.0258 | 0.0259 | 1.001 | 2.99% | 1.19% | 1.001 |
| concat | 0.0743 | 0.0743 | 1.000 | 1.53% | 2.36% | 1.001 |
| sort | 0.1753 | 0.1751 | 0.999 | 0.86% | 1.66% | 0.992 |
| binary-trees | 1.8996 | 1.9017 | 1.001 | 2.19% | 2.66% | 0.998 |

**The criterion is met**: neither fib (1.015) nor loop (0.978) is more than 2%
slower than the control. Both moves exceed this run's bounds: fib is
slower beyond both ranges and the twin's difference, loop faster beyond them;
the other kernels do not move beyond their bounds. The fib slowdown runs
against the loopmatch session's prototype on the former self-tail form (fib
2.3% faster); a likely cause, not measured here, is the 20-byte `Cell` the
handler word needs on fib's call path, against 12 bytes before.

## Collection statistics

### Criterion, recorded before measuring

The collection statistics (pull request 24) add counter increments to the
collector's mark and sweep loops and to the trigger arithmetic. The kernels
that collect most (binary-trees, integer-table) pay for them. Comparison:
this branch's base `fbd3bb2f1` against this branch, same compiler
(`wf-691ea8106920`), six interleaved full-LTO pairs over the seven kernels
with a twin of the base, on the 14900K. Kept only if no kernel is slower
beyond its larger range and the twin's difference.

### Result

[Run 37835986400](https://github.com/Ming-Research/Halo-wf/actions/runs/37835986400),
artifact `halo-bench-gcstats`: base `fbd3bb2f1` against the branch, the same
compiler, on the 14900K; medians in seconds, six interleaved pairs:

| Kernel | Base | Branch | Ratio | Base range | Branch range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1051 | 0.1044 | 0.993 | 1.04% | 3.25% | 1.000 |
| loop | 0.4323 | 0.4327 | 1.001 | 0.66% | 1.00% | 1.001 |
| integer-table | 0.4921 | 0.4986 | 1.013 | 2.62% | 1.51% | 0.995 |
| string-key | 0.0257 | 0.0255 | 0.989 | 2.42% | 2.90% | 1.001 |
| concat | 0.0743 | 0.0733 | 0.986 | 4.30% | 0.78% | 0.997 |
| sort | 0.1745 | 0.1758 | 1.008 | 1.21% | 1.17% | 1.008 |
| binary-trees | 1.9103 | 1.9433 | 1.017 | 2.80% | 4.13% | 0.995 |

`--check-module pkg::vm`: base 7.706 and 7.731 s, branch 7.697 and 7.809 s.

**The criterion is met**: no kernel is slower beyond its larger range and the
twin's difference. The two kernels that collect most lean the same way,
binary-trees 1.7% and integer-table 1.3% slower, each within its bounds; a
cost of that size from the counters is possible and unresolved by six pairs.

## The call path on the 14900K

### Question, recorded before it runs

[The call path](#the-call-path)'s attribution ran on a hosted EPYC guest
sampling `task-clock`, before `run` became `loop { match }` and with
`wf-8b647edbbc95`. Since then the dispatch is a plain loop compiling to the
same machine code as the self-tail call ([the dispatch as loop { match }](#the-dispatch-as-loop--match-)),
the pin is `wf-691ea8106920`, and Whitefoot's broadened in-place rule, not
yet in a release Halo pins, removed `push_frame`'s entry copy and made fib
3.8% faster ([reading by-value parameters in place, measured](#reading-by-value-parameters-in-place-measured)).

Question: on the 14900K, sampling hardware cycles, what share of fib's
cycles falls in each call-path function (`prepare`, `enter_lua`,
`push_frame`, `finish` and the `Call` and `Return` arms), against PUC's
`luaD_precall` and `luaD_poscall`, and which instructions hold those
cycles? This run tests no proposal; it chooses the next call-path change,
whose criterion is recorded before that change is timed. Each cost found is
classed as before: work Halo's source asks for and PUC does not do is a
candidate change in Halo; code the compiler emits beyond the source is a
Whitefoot gap, stated as a minimal witness and handed to the Whitefoot
session that owns it.

Run: Halo main at this branch's merge of `10a9b02e4`, built with full LTO by
`wf-691ea8106920` as `run.py` builds it, and Redis 7.0.15's bundled PUC Lua
built from source, each running the fib kernel at N = 34 (N = 30 runs about
0.1 s on this host, too few samples per instruction); three launches each
under `perf record -e cycles` (`cpu-clock` if the runner refuses hardware
events), reported by symbol; `perf annotate` of the
first launch; and the instruction counts of the call-path functions.

### Result

[Run 37854794981](https://github.com/Ming-Research/Halo-wf/actions/runs/37854794981),
artifact `halo-call-profile-14900k`: branch `dbfb6fc9c` (main `10a9b02e4`
merged), `wf-691ea8106920`, clang 22.1.8, full LTO, Linux 6.8.0-142,
perf 6.8.12, an i9-14900K under a Microsoft hypervisor. The manifest and the
profiles' recorded command line request `cycles`, but both supplied annotation
files name `task-clock`, and all six supplied `.data` files, as well as the
probe, have one software task-clock event (type 1, config 1). A successful
probe therefore did not establish hardware-cycle recording; why the recorded
event differs is unverified. The shares below are the supplied reports'
self shares, not hardware-cycle shares. Both engines print 5702887 in all
three launches of fib(34). The workflow's elapsed values include `perf record`'s overhead and
are not engine timings.

Shares from `report-{halo,puc}-{1,2,3}.txt`, minimum–maximum over the three
launches, including every listed symbol above 1.5%:

| Halo symbol | Share | PUC symbol | Share |
|---|---:|---|---:|
| arm 63 (`Call`) | 18.73–19.82% | `luaV_execute` | 62.23–64.74% |
| `enter_lua` | 15.33–16.66% | `luaD_precall` | 17.64–20.23% |
| `push_frame` | 14.77–15.62% | `luaV_lessthan` | 7.41–8.20% |
| arm 54 (`LtJmpRK`) | 11.88–12.29% | `luaD_poscall` | 6.69–7.14% |
| arm 5 (`GetUpval`) | 9.93–11.10% | `luaF_close` | 2.71–3.70% |
| arm 65 (`Return`) | 8.23–8.63% | | |
| `finish` | 5.60–6.43% | | |
| arm 20 (`AddRR`) | 3.43–4.51% | | |
| `prepare` | 3.04–4.13% | | |
| arm 25 (`SubRK`) | 2.94–3.81% | | |
| `native_binding` | 1.75–1.89% | | |

The six call-path symbols named in the question sum to 67.68–68.88% per
launch; this includes the arms' dispatch work. Arm numbers are zero-based
positions in `lib/halo/vm/dispatch.wf`'s outer instruction match, not Lua
opcode numbers. Counting those arms gives the names above. The corresponding
`disasm-*.txt` confirms them: arm 5 follows the current frame's closure to
its upvalue and reads the open stack slot or closed value; arm 20 adds two
stack numbers (`addsd`), arm 25 subtracts a constant from a stack number
(`subsd`), and arm 54 compares a stack number with a constant (`ucomisd`)
and selects the jump target. Arm 63 calls `prepare`, and arm 65 calls
`finish`. `R` denotes a register and `K` a constant.

Sizes from `call-sizes.txt` are disassembled instruction counts, including
cold paths and alignment instructions, not instructions executed per call:

| Halo function or arm | Instructions | PUC function | Instructions |
|---|---:|---|---:|
| `enter_lua` | 452 | `luaD_precall` | 437 |
| `prepare` | 1465 | `luaD_poscall` | 95 |
| `push_frame` | 91 | | |
| `finish` | 149 | | |
| `Call` arm | 269 | | |
| `Return` arm | 213 | | |
| `native_binding` | 116 | | |

`enter_lua`, `push_frame`, `finish` and the two PUC functions have the same
counts as the EPYC attribution; `prepare` was 1382 there. A larger function
alone establishes no runtime cost.

Launch 1's `annotate-halo.txt` gives the following points. Percentages here
are local to each symbol, not shares of the whole program. Read each sampled
instruction with its predecessor: a sample can land after the instruction
that waited. With the supplied task-clock event, this is an attribution
hypothesis, not a hardware stall measurement.

- `push_frame`: 64.07% is on the store immediately after the first 16-byte
  load of the incoming `Frame`, at offset 64; another 8.27% is on the next
  load, after that store. The first load reads `varcount` and `frame_top`,
  which `enter_lua` has just stored separately as 8-byte fields. All five
  16-byte loads and five stores of the 80-byte entry copy remain, followed
  by the second copy into the frames vector. The EPYC finding is still
  present, with a different first block and a larger local concentration;
  those percentages are not a before/after cost. This pin predates the
  broadened in-place rule. Its removal and the 3.8% fib gain in
  [reading by-value parameters in place](#reading-by-value-parameters-in-place-measured)
  were a different compiler comparison, affecting more than this function.
- `Call`: 31.40% is on the second 16-byte load of the returned `Step`,
  immediately after the first load (`6c5ac`). The two loads still copy the
  whole 32-byte result to the loop's slot. `enter_lua` writes the successful
  result as four 8-byte words; `instruction_call` matches it to handle
  `Error`, then returns `final_step`, and the shared epilogue matches it
  again. After the copy, 8.04% is on the `pc` reload following the tag
  reload, and another 8.04% follows the second tag-dispatch table load.
  The whole-result copy and repeated tag dispatch found on EPYC remain.
- `enter_lua`: its largest point, 5.46%, follows a 16-byte nil store in the
  `fixed..maxstack` fill; 4.83% follows another such store in the unrolled
  part. Each slot still has its own saturated index calculation and bound
  comparison, even after `ensure_stack` has ensured `base + 256` slots.
  The 40-byte prototype copy also remains: two 16-byte loads and one 8-byte
  load fill the local `p`. A 4.83% point follows the byte reload of
  `p.numparams`; another 4.83% is on the following tail-argument test, after
  storing the widened parameter count. Thus neither the prototype copy nor
  the per-slot tests is gone, but the EPYC prototype-copy concentration is
  not the largest point here. `native_binding` and `enter_lua` still each
  check the closure-slab bound, live bit and callee kind on an ordinary Lua
  call. That double lookup remains in both source and disassembly.
- `Return`: samples are spread across the arm. Its largest points are at
  entry (4.68%) and the stack adjustment immediately after the entry push
  (5.53%); these do not identify a source operation's cost. A 2.98% point
  follows the open-upvalue tag test in the inlined `close_upvalues`, another
  2.98% follows a store in the popped 80-byte frame's copy, and 3.40%
  follows the returned `base` load before the overflow/window checks.
  The source closes upvalues, takes the last frame and calls `finish`;
  the epilogue then checks the new code, stack and constant windows. PUC
  also closes upvalues and moves results; these operations alone are not
  Halo-only costs. The annotation identifies no single return-side copy
  concentration comparable to the call's.
- `finish`: 11.30% is at entry, which cannot be assigned to a preceding
  instruction within this symbol. The largest interior point, 9.60%,
  follows the sign test of `f.nresults`, selecting the wanted result count
  in the inlined `adjust_results`; 7.34% follows the load of `f.func`, the
  result destination. A 6.78% point follows the saturated destination-index
  addition before its slot-bound test. The remaining path tests for a
  protected caller, checks activation, restores the caller's top and emits
  `Step::Jump`. PUC's `luaD_poscall` also selects and copies results, but
  directly restores its caller and has no Halo stack-index or activation
  tests and no `Step` return.
- `prepare`: 18.68% is on the called value's 4-byte handle reload, after
  its 4-byte tag reload. The preceding code still loads the whole 16-byte
  stack `Value` into a temporary before `func_of` reads these fields.
  Entry and the tail-argument load each have 14.29%; argument pushes before
  `enter_lua` have a 12.09% point. The EPYC matched-value materialization
  remains. Its closure-slab test is now in the separately called
  `native_binding`, rather than a hot inlined test in `prepare`; its share
  must be read separately. This annotation has only 91 samples in
  `prepare`, so the individual percentages have little resolution.

The EPYC source findings also remain outside the largest points:
`push_frame` compares depth with 20000, compares depth with capacity to
decide growth, then tests space again before `place_back`. PUC's ordinary
Lua entry checks frame capacity and grows on a miss, without a separate
depth-limit comparison on that path. PUC reads its prototype through a
pointer, and its nil fill tests the loop endpoint, without Halo's separate
per-slot stack-bound tests. None of these findings is removed by writing
`run` as `loop { match }`; the earlier comparison found the loop and
self-tail forms byte-identical.

The classification is unchanged, with the closure-test placement qualified:

- **Halo source work PUC does not do:** two closure-slab lookups, the local
  whole-prototype snapshot, the separate frame-limit and capacity tests,
  per-slot bounds with saturated arithmetic in nil filling and result
  adjustment, and the activation test in `finish`. These are Halo candidates
  only if their required behavior and safety conditions are preserved.
  Nil initialization, closing upvalues and result movement
  themselves are shared work, not reasons to remove them or their safety
  conditions.
- **Compiler work beyond the required value semantics:** the physical entry
  copy and the result and matched-value temporaries. Minimal semantic
  examples are an unchanged copy-struct parameter forwarded to a sink after
  a branch; a producer returning a tagged record whose caller matches its
  tag and reads its scalar fields; and an immutable tagged value matched
  only to read its scalar handle. These require value semantics, not an
  additional whole-value memory slot before the read. `Frame`, `Step` and
  `Value` instantiate those examples. The first has the broadened-rule
  evidence above; the latter two remain Whitefoot lowering questions for
  their owning session, not a reason to replace natural Halo value syntax.
- **Dispatch form:** `Call` and `Return` still use the shared `Step` epilogue,
  its tag dispatch and window tests, while selected hot arms continue
  directly. The source asks for this join; the compiler chooses its memory
  transport. The loop spelling has not made that join disappear. Changing
  the join's interface is a Halo design choice; eliminating unnecessary
  transport while preserving the interface is a compiler question.

Not established: time per copy, lookup or check, a Halo/PUC timing ratio,
or a counted store-forwarding stall. The wide reloads after narrower stores
remain consistent with the earlier attribution, but samples can skid and
the sampled address need not be the cause. The supplied event discrepancy
leaves the hardware-cycle question unverified. Shares have different
denominators in the two engines and change when other work changes; they
cannot be subtracted to predict a gain. This is one kernel on one host under
a hypervisor, without a timing twin or a change that isolates any cost.

Candidates for the owner's choice, ranked by the evidence available here,
not selected by this run:

1. **Broadened in-place parameters in Whitefoot.** The hottest `push_frame`
   point still follows its entry load, and the prior same-source compiler
   comparison removed that copy and improved fib by 3.8%. Repeat against
   the current Halo source with control and broadened-rule compilers based
   on the same Whitefoot revision; require the entry copy to disappear.
   This tests whether the prior gain carries to this engine, without
   attributing the whole gain to `push_frame`.
2. **Scalar use of returned and matched values in Whitefoot.** `Call`'s
   31.40% point follows the result's wide load, and `prepare` still
   materializes `Value` before reading its tag and handle. Measure the two
   minimal semantic examples separately, then identical Halo source with
   one lowering change at a time; inspect that the respective temporary
   disappears. A retained temporary fails to test the proposed explanation.
3. **One closure lookup and only the needed prototype fields in Halo.**
   The duplicate validation and the 40-byte snapshot survive, whereas PUC
   reads through its closure and prototype pointers. Measure each change
   separately with one compiler, preserving native, invalid-callee, tail
   and vararg behavior; inspect that the intended lookup or copy is gone.
4. **Prove call-frame bounds once in Halo.** The separate depth/capacity
   checks and every nil slot's bound test remain. Measure frame-growth
   qualification and nil-fill qualification separately, retaining the
   frame limit, growth errors and all required Whitefoot safety facts;
   inspect that only the redundant hot tests disappear. This has less
   isolated evidence than the copies and no measured gain here.

For each candidate, a proposed runtime criterion for the owner is a
**fib(34) median at least 3% below its control**, also beyond the larger
control/candidate relative min–max range and the control twin's median
difference from 1. Use six interleaved full-LTO pairs of the same benchmark
source on the 14900K, with a twin of the control; compiler trials keep Halo
source identical and Halo trials change only the candidate under study.
No other kernel may regress beyond its larger range and twin difference,
and ordinary and collector-stress oracle comparisons and root controls
must pass on the measured revision. A gain inside those bounds rejects the
runtime case for that candidate on this workload. These are proposed
criteria for a future experiment, not results or an owner choice.

## One closure lookup and the prototype fields a call reads

### Criterion, recorded before the change

The owner chose (status board, card on the call path's next step, option A)
the Halo-side change first: an ordinary Lua call looks its closure up once
and reads only the prototype fields it needs. Today `prepare` checks the
closure slab's bound, live bit and callee kind in `native_binding`, and
`enter_lua` checks them again before copying the whole 40-byte prototype
into a local ([the call path on the 14900K](#the-call-path-on-the-14900k)).
Change: `prepare` resolves the closure once and hands `enter_lua` what that
lookup established; `enter_lua` reads `numparams`, `is_vararg`, `maxstack`
and whatever else it uses through the prototype's slot instead of a local
copy. Native calls, invalid callees, tail calls, varargs and every error
keep their behavior, and the oracle comparisons must not change.

Kept only if, on the 14900K, in six interleaved full-LTO pairs of this
branch's base against the branch with the change, same compiler, with a
twin of the base: fib's median falls at least 3%, by more than both ranges
and the twin's difference; no other kernel is slower beyond its larger range
and the twin's difference; `--check-module pkg::vm` takes at most 1.25 times
as long; and `make check` passes. Otherwise the change is reverted with its
measurements kept. The binaries' disassembly must show the second closure
check and the prototype copy gone; if either remains, the run does not test
the change and is reported as such.

### Result

[Run 37872258846](https://github.com/Ming-Research/Halo-wf/actions/runs/37872258846),
artifact `halo-bench-onelookup`: the criterion's commit `5f8ba808c` against
the change `0b9dc62` (the run's `git diff --stat`: `lib/halo/vm/calls.wf`
only), `wf-691ea8106920`, six interleaved full-LTO pairs with a twin of the
base:

| Kernel | Before | After | Ratio | Before range | After range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1042 | 0.1030 | 0.988 | 2.02% | 5.84% | 0.995 |
| loop | 0.4327 | 0.4341 | 1.003 | 0.99% | 0.77% | 1.001 |
| integer-table | 0.4925 | 0.4903 | 0.996 | 1.11% | 2.91% | 0.988 |
| string-key | 0.0255 | 0.0254 | 0.998 | 2.63% | 4.79% | 0.999 |
| concat | 0.0725 | 0.0726 | 1.001 | 1.45% | 1.49% | 1.001 |
| sort | 0.1746 | 0.1757 | 1.006 | 2.39% | 2.41% | 0.989 |
| binary-trees | 1.8874 | 1.8717 | 0.992 | 1.48% | 1.79% | 1.004 |

The run tests the change: in the after build `enter_lua` no longer checks
the closure slab and reads the prototype's fields in place with byte and
word loads (452 to 409 instructions, stack frame 0x178 to 0xd8 bytes),
while `prepare` gains 15 instructions for the one lookup it now does.
`--check-module pkg::vm`: before 9.079 and 9.169 s, after 9.045 and
9.132 s.

**The criterion fails and the change is reverted.** Fib is 1.2% faster,
below the 3% required and inside its ranges; no kernel is slower beyond its
bounds. Removing the second closure lookup and the prototype copy did not
speed fib up beyond this run's noise. Where the rest of the call path's
cost lies is not established by this run: the compiler-side copies of
`Step` and `Value`, handed to the Whitefoot session, and the frame's own
checks and transport remain candidates, each to be measured on its own.

## Why moving the slow call out made sort faster

### Question, recorded before it runs

The [seventh run](#seventh-run-the-splits-share-and-the-heads-check-time)
attributed a 25% sort speedup to one source change: `sort_compare`'s call to
the slow executor moved into its own function, `sort_compare_slow`. The two
sources (`f70f0a8af` before, `22aadda57` after) differ in
`lib/halo/vm/library-sort.wf` only, and the slow path never ran in that
kernel, which compares numbers. Why did the change speed up the fast path?
Other library functions keep a slow-executor or callback call beside a fast
path (string comparison and pattern matching, `table.concat`, the codecs),
and whether to split them depends on the cause.

Comparison: both sources built alike with full LTO by their pin
(`wf-e1708490c384`) on a hosted x86-64 runner, then the disassembly of every
sort function in each binary, with instruction counts, stack-frame sizes,
callee-saved register saves and what is inlined into what. The run times
nothing. Hypotheses it can separate: (a) inlining `slow` into `sort_compare`
made the fast path's frame larger, with more spills and saves on every call;
(b) the larger function stopped `sort_compare` itself from being inlined into
its caller, adding a call per comparison; (c) block layout or register
allocation of the fast path changed with no size effect. A result naming
none of these is reported as found, not fitted to one. Only a cause found
in the machine code decides whether, and where, splitting is tried in other
library functions; each such split is then timed separately.

### Result

[Run 37856473502](https://github.com/Ming-Research/Halo-wf/actions/runs/37856473502),
artifact `halo-slowsplit-disasm`, on a hosted ubuntu-24.04 x86-64 runner
with `wf-e1708490c384` and clang 22: the two revisions' library sources
(`lib/`, the benchmark's build input) differ in `lib/halo/vm/library-sort.wf`
only (the run's `git diff --stat -- lib`), and
`slow` is a separate function of the same size (0x1fbd bytes) in both
binaries, so neither inlines it. `sort_compare_slow` does not survive as a
symbol after the split: LLVM inlined it back into `sort_compare`.

The difference is in `sort_compare` itself:

| | Before the split | After the split |
|---|---:|---:|
| Code size | 0x44e bytes, 229 instructions | 0x330 bytes, 196 instructions |
| Stack frame | 0x1e8 bytes, six callee-saved registers | 0x60 bytes, five |
| `memcpy` calls | 1, 152 bytes, on entry | none |

Before the split, every call copies the whole 152-byte
`vm^.library_contexts.inner[context]` slot payload to the stack through a
`memcpy` call, and both 16-byte operands `a` and `b` to stack slots, before
the first test of the comparator; the number path then reads the copies.
After the split, the function reads the comparator and the destination
directly from the context's slot and the operands' tags and payloads
directly from their incoming addresses; nothing is copied.

The source asks for the copy: `let local_call_5 =
vm^.library_contexts.inner[context];` binds a `LibraryContext` by value,
and the number path reads only `local_call_5.frame.func` and
`local_call_5.comparator`. Whether the copy is materialized depends on the
rest of the function: with the slow call written inline, the compiler kept
the whole-value copy; with that call moved to another function (even one
LLVM later inlines back), it read the two fields in place. None of the three
hypotheses recorded above names this: the larger frame (a) follows from the
copy, `sort_compare` is a call in both (b does not apply), and the change is
not layout alone (c). The mechanism the disassembly shows is a by-value
binding of a place materialized as a whole copy on the fast path, which is
code the compiler emits beyond what the fields read require. It is the
supported explanation of the seventh run's 25%, not a separately measured
one: the split also changed the frame size, the saved registers and the
spills, and this run times nothing. It is the same kind as `prepare`'s
whole-`Value` read and the `Call` arm's whole-`Step` copy in pull request
12's [call-path profile on the 14900K](#the-call-path-on-the-14900k).

Not established: which property of the inline form made the compiler keep
the copy (the binding is not read after the slow call in either form),
which compiler stage keeps it, and whether the current compiler still does.

### Question, recorded before the second run

Does `wf-691ea8106920` still keep the copy? The same run is repeated with two
more builds: main as it is (the split form) and main with the split undone
(`.github/slowsplit/unsplit.patch`, which writes `sort_compare_slow`'s body
back at its call, as `f70f0a8af` had it). If the unsplit build copies the
context and the split build does not, the effect stands on the current
compiler and goes to Whitefoot as a minimal witness; splitting other library
functions would only route around it, so no other function is split in
Halo. If neither copies, the effect was fixed in Whitefoot since
`wf-e1708490c384`, and the slow-path item closes with this record.

### Second result

[Run 37857130998](https://github.com/Ming-Research/Halo-wf/actions/runs/37857130998),
same runner and artifact name, adds main (`47eb867`, the split form) and
main with the split undone, both with `wf-691ea8106920`; the patch changes
`lib/halo/vm/library-sort.wf` only. The before and after builds repeat the
first run byte for byte (same digests).

| Build | Compiler | `sort_compare` size | Stack frame | `memcpy` |
|---|---|---:|---:|---:|
| `f70f0a8af`, inline | `wf-e1708490c384` | 0x44e | 0x1e8 | 1 |
| `22aadda57`, split | `wf-e1708490c384` | 0x330 | 0x60 | 0 |
| main, split | `wf-691ea8106920` | 0x330 | 0x60 | 0 |
| main, inline | `wf-691ea8106920` | 0x44e | 0x1f8 | 1 |

**The effect stands on the current compiler.** Writing the slow call inline
makes `sort_compare` copy the whole library context (168 bytes in the
current layout: the `imul` stride and the `memcpy` length are both 0xa8),
and the operands, on every call; moving that call into another function removes
the copy. This is a Whitefoot lowering gap and goes to the Whitefoot session
that owns copy elimination with these builds as its witness. No other
library function is split in Halo, since that would route around the gap.
The sort kernel no longer reaches `sort_compare` (homogeneous arrays take
`sort_array_run`), so this costs Halo's kernels nothing today; a sort with
a comparator or mixed operands still runs it.

## The collection floor on Firn's long-lived VM

### What Firn measured with the statistics

Firn-wf [run 37859639750](https://github.com/Ming-Research/Firn-wf/actions/runs/37859639750)
(the firn session's experiment branch at `413b34a`, Halo `10a9b02e4`,
14900K, one core, the rate-limiter script through EVALSHA at 50
connections, two interleaved five-second passes per side), as the firn
session reported it; the numbers below are its, not recomputed here:

- The live heap is small and constant from the first collection on: 134
  strings (4.1 KB), 13 tables (6.1 KB), one closure (24 B), no upvalues;
  marking pops 14 gray values every time.
- Each collection frees about 16,600 objects and 1.05 MB (about 10,190
  tables, 3,220 closures and 3,180 strings) and visits about 17,200 slots;
  pauses average 3.9–4.0 ms, about 240 ns per freed object.
- `set_gc_pause(400)` changed nothing: `next_threshold` stayed 1,048,576
  bytes on both sides, since `live * (pause - 100) / 100` with 10 KB live is
  far below the 1 MiB floor. Collections, pause lengths, p99 (3.4–3.5 ms)
  and p99.9 (6.6–7.0 ms) were unchanged.

So the pause is set by the 1 MiB floor and the per-object cost of sweeping
and freeing, not by the pause multiplier. PUC Lua 5.1 has no such floor; its
threshold is the estimate times the pause.

### Question and criterion, recorded before measuring

This branch makes the floor an embedding setting, `set_gc_floor(engine,
bytes)` (default 1 MiB, applied by the next completed collection, like the
pause), so that one Firn build can run several floors side by side.

Question: does a lower floor shorten pauses in proportion and bring the
rate-limiter script's p99 at 50 connections down, without costing
throughput? Each collection's work should scale with the garbage allocated
since the last one, and the slabs' length with the garbage alive at once, so
a floor of F should give pauses of about 4 ms × F / 1 MiB and about
1 MiB / F times as many collections; a fixed cost per collection would show
as pauses that do not fall in proportion.

Comparison, measured by the firn session on the 14900K with its harness:
floors of 1 MiB (control), 256 KiB and 64 KiB in one interleaved run, the
rate-limiter script at 50 connections, reporting per side collections,
mean and maximum pause, freed objects and slots visited per collection,
p99, p99.9 and throughput, with its pass-to-pass spread.

A floor is a candidate for the default if its p99 is at least 30% below the
1 MiB control and its throughput is not lower than the control's by more
than the run's own pass-to-pass spread. If no floor meets this, a lower
floor is rejected as the remedy and the per-object sweep and free cost is
the next target. The default stays 1 MiB on this branch; changing it, or
keeping `set_gc_floor`, is the owner's decision after the result.

### Result

Firn-wf [run 37862972166](https://github.com/Ming-Research/Firn-wf/actions/runs/37862972166)
(the firn session's experiment branch at `101abee`, Halo `f6b51e4`, pause
200, 14900K, one core, the rate-limiter script at 50 connections, two
interleaved five-second passes per floor), as the firn session reported it;
two values per cell, one per pass:

| Floor | Collections | Mean pause (ms) | Freed per collection | Slots visited | p99 (ms) | p99.9 (ms) | Throughput (k/s) |
|---|---|---|---:|---:|---|---|---|
| 1 MiB | 194, 165 | 3.82, 4.34 | ≈16,600 | ≈17,200 | 3.40, 3.45 | 6.61, 6.71 | 125.4, 106.1 |
| 256 KiB | 750, 720 | 0.68, 0.70 | ≈4,170 | ≈16,000 | 1.51, 1.49 | 2.19, 1.55 | 121.2, 116.2 |
| 64 KiB | 3,019, 3,089 | 0.18, 0.18 | ≈1,050 | ≈16,000 | 0.84, 0.82 | 2.24, 0.93 | 121.8, 124.8 |

Redis 7.0.15 in the same run: p99 0.77 and 0.91 ms, 148k and 142k calls a
second.

**Both lower floors meet the criterion.** Against the 1 MiB control, p99
falls 56% at 256 KiB and 76% at 64 KiB, where it matches Redis's, and
neither floor's throughput is below the control's by more than the
control's own pass-to-pass spread (17%), which is too wide to resolve a
throughput difference of a few percent. Pauses fell in proportion to the
floor, and the cost per freed object fell from about 240 ns to about
165 ns; total collection time over a pass fell too (about 0.55 s of 5 s at
64 KiB against about 0.74 s at 1 MiB, the firn session's figures).

One cost did not scale: every collection visits about 16,000 slots however
few it frees, since the sweep walks each slab's whole length and slabs never
shrink. In this run the slabs reached that length before the first
collection, which happens at the engine's initial 1 MiB threshold in every
variant; `set_gc_floor` applies only from the next collection on. A default
floor that also sets the initial threshold would keep the slabs near the
garbage allocated between collections; a sweep that skips never-used slots,
or slabs that shrink, would remove the cost for any floor.

### A 64 KiB default on Halo's kernels: criterion, recorded before measuring

A lower default floor means more collections wherever the live heap is
small; the kernels with large live heaps already collect at `live` and
should not change. Comparison: main (`872dbf838`, floor and initial
threshold 1 MiB) against the same source with the default floor and the
initial threshold at 64 KiB (measurement-only branch
`claude/halo-gc-floor-64k`, deleted after the run), same compiler
(`wf-691ea8106920`), six interleaved full-LTO pairs over the seven kernels
with a twin of main, on the 14900K. A 64 KiB default is acceptable for
Halo's kernels if no kernel is slower beyond its larger range and the twin's
difference; a kernel slower beyond that is reported with its collection
count, and the default is then the owner's trade-off between Firn's p99 and
that kernel.

### A 64 KiB default on Halo's kernels: result

[Run 37864849133](https://github.com/Ming-Research/Halo-wf/actions/runs/37864849133),
artifact `halo-bench-floor64`: main `872dbf838` against the measurement
branch at `0a3844317` (this branch's floor setting plus the 64 KiB default
and initial threshold; the run's `git diff --stat` lists only the five
library files of the floor change), `wf-691ea8106920`, six interleaved
full-LTO pairs, `run.py --collections-may-change` (the first attempt,
[run 37863440621](https://github.com/Ming-Research/Halo-wf/actions/runs/37863440621),
stopped at integer-table's changed collection count before that option
existed). Medians in seconds, collections per launch:

| Kernel | Main | 64 KiB | Ratio | Main range | 64 KiB range | Twin ratio | Collections |
|---|---:|---:|---:|---:|---:|---:|---|
| fib | 0.1041 | 0.1033 | 0.992 | 0.47% | 0.48% | 1.001 | 0 → 0 |
| loop | 0.4331 | 0.4327 | 0.999 | 1.21% | 0.90% | 0.999 | 0 → 0 |
| integer-table | 0.4970 | 0.5022 | 1.010 | 2.51% | 2.79% | 0.994 | 5 → 7 |
| string-key | 0.0253 | 0.0258 | 1.018 | 1.23% | 0.87% | 1.003 | 0 → 0 |
| concat | 0.0728 | 0.0740 | 1.017 | 2.52% | 3.67% | 0.999 | 0 → 0 |
| sort | 0.1757 | 0.1769 | 1.007 | 1.31% | 1.04% | 0.997 | 3 → 5 |
| binary-trees | 1.9583 | 1.9587 | 1.000 | 1.55% | 1.79% | 1.009 | 177 → 182 |

**The criterion is not met as written:** string-key is 1.8% slower, beyond
its larger range (1.23%) and the twin's difference (0.3%); every other
kernel is within its bounds, the three that collect more included. One and
three pairs gave string-key 0.996 and 1.015. String-key collects in neither
build, so the floor changes nothing it executes; the two binaries also
differ by the floor field in the heap and the setter, so code layout is the
likelier cause, but this run does not separate the two. The default is the
owner's choice between Firn's p99 (3.4 ms at 1 MiB, 0.83 ms at 64 KiB) and
this unexplained 1.8% on string-key.

### The default constant alone: criterion, recorded before measuring

To separate the floor from the layout change, this branch's source with
the 1 MiB default (`f46378c`, setting included) is compared against the
same source with only the default floor and initial threshold changed to
64 KiB, otherwise as above (measurement-only branch, deleted after the
run). If string-key is then within its bounds, its 1.8% above came from the
added field and setter, not from the floor; the 64 KiB default meets the
criterion if no kernel is slower beyond its larger range and the twin's
difference.

### The default constant alone: result

[Run 37865476707](https://github.com/Ming-Research/Halo-wf/actions/runs/37865476707):
this branch at `0ad19cbb2` against the same source with the default floor
and initial threshold at 64 KiB (the run's `git diff --stat`: one line of
`lib/halo/heap/slabs.wf`), otherwise as above:

| Kernel | 1 MiB | 64 KiB | Ratio | 1 MiB range | 64 KiB range | Twin ratio | Collections |
|---|---:|---:|---:|---:|---:|---:|---|
| fib | 0.1030 | 0.1035 | 1.005 | 1.67% | 0.99% | 1.000 | 0 → 0 |
| loop | 0.4325 | 0.4326 | 1.000 | 0.82% | 0.36% | 0.998 | 0 → 0 |
| integer-table | 0.5042 | 0.5022 | 0.996 | 2.07% | 2.32% | 0.997 | 5 → 7 |
| string-key | 0.0260 | 0.0259 | 0.998 | 1.26% | 0.69% | 0.995 | 0 → 0 |
| concat | 0.0736 | 0.0736 | 1.000 | 2.22% | 1.99% | 0.997 | 0 → 0 |
| sort | 0.1749 | 0.1750 | 1.000 | 1.29% | 1.89% | 0.994 | 3 → 5 |
| binary-trees | 1.9340 | 1.9214 | 0.994 | 5.11% | 1.56% | 1.003 | 177 → 182 |

**The 64 KiB default meets the criterion:** no kernel is slower beyond its
bounds, the three that collect more included. String-key's 1.8% in the
previous run therefore did not come from the floor; that it came from the
added field and setter, through code layout or otherwise, is a hypothesis:
both sides of this run have them, so this run does not measure their cost.
This run's 1 MiB build ran string-key at 0.0260 s against main's 0.0253 s
in the previous run, a comparison across runs that neither run tests.

### Outcome

The owner chose a 64 KiB default floor and initial threshold without the
`set_gc_floor` setting, which this branch then removed; the floor is the
heap's `collection_floor` constant.

### The final revision against main: criterion, recorded before measuring

The comparisons above measured the floor with the experimental setting in
both builds; the final revision has no setting. Main (`872dbf838`) against
this branch's final source, whose library differs from main only in the
`collection_floor` constant and its two uses, otherwise as above. Kept if no
kernel is slower beyond its larger range and the twin's difference.

### The final revision against main: result

[Run 37872228924](https://github.com/Ming-Research/Halo-wf/actions/runs/37872228924):
main `872dbf838` against this branch's final source (`60385dc`; the run's
`git diff --stat` lists the four library files of the constant), six
interleaved full-LTO pairs with a twin of main:

| Kernel | Main | Final | Ratio | Main range | Final range | Twin ratio | Collections |
|---|---:|---:|---:|---:|---:|---:|---|
| fib | 0.1042 | 0.1045 | 1.003 | 1.12% | 3.41% | 1.005 | 0 → 0 |
| loop | 0.4329 | 0.4330 | 1.000 | 0.64% | 0.75% | 1.002 | 0 → 0 |
| integer-table | 0.4881 | 0.4835 | 0.991 | 3.90% | 2.80% | 1.013 | 5 → 7 |
| string-key | 0.0255 | 0.0255 | 1.002 | 1.77% | 6.52% | 1.002 | 0 → 0 |
| concat | 0.0726 | 0.0727 | 1.001 | 1.64% | 1.12% | 1.000 | 0 → 0 |
| sort | 0.1747 | 0.1751 | 1.002 | 1.01% | 2.13% | 0.990 | 3 → 5 |
| binary-trees | 1.8915 | 1.8888 | 0.999 | 2.07% | 1.23% | 1.001 | 177 → 182 |

**The criterion is met:** no kernel is slower beyond its bounds, string-key
included, so the final revision without the setting shows none of the
earlier 1.8%.

## Whitefoot wf-b2209fd31035 upgrade

### Question, recorded before it runs

The pin moves from `wf-691ea8106920` (Whitefoot main `691ea8106`,
specification v0.102) to `wf-b2209fd31035` (main `b2209fd31`, v0.105). Among
the changes between them, two touch Halo's generated code: Whitefoot#279
reads a by-value parameter in place in branched functions too, which on an
experiment release removed `push_frame`'s entry copy and made fib 3.8%
faster ([reading by-value parameters in place, measured](#reading-by-value-parameters-in-place-measured));
and Whitefoot#280 lowers `grow` through a counted reallocation, which Halo's
current source does not call on its hot paths (reapplying `6f49ca6`, which
does, is a separate change measured after this one). The specification
changes add standard-library inputs Halo does not use and narrow when a
saved Bool comparison holds; Halo's source needed no change beyond naming
`Inputs`' new fields with a rest pattern, which both releases accept.

Comparison: this branch's source built with both releases, six interleaved
full-LTO pairs over the seven kernels on the 14900K with a twin of the old
build, `push_frame`'s disassembly from both, and two `--check-module pkg::vm`
samples each. Expected: `push_frame` loses its entry copy, fib is faster by
more than both ranges and the twin's difference, and no kernel is slower
beyond its bounds; a kernel that is slower is reported with the upgrade.

### Result

[Run 37877260152](https://github.com/Ming-Research/Halo-wf/actions/runs/37877260152),
artifact `halo-bench-upgrade`: this branch's source built by both releases,
six interleaved full-LTO pairs with a twin of the old build:

| Kernel | `wf-691ea8106920` | `wf-b2209fd31035` | Ratio | Old range | New range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1040 | 0.1034 | 0.994 | 1.19% | 1.66% | 0.993 |
| loop | 0.4328 | 0.4334 | 1.001 | 0.62% | 0.90% | 1.002 |
| integer-table | 0.4896 | 0.4773 | 0.975 | 2.55% | 2.17% | 1.005 |
| string-key | 0.0264 | 0.0263 | 0.998 | 6.65% | 5.25% | 1.000 |
| concat | 0.0727 | 0.0731 | 1.005 | 2.43% | 1.53% | 1.002 |
| sort | 0.1753 | 0.1768 | 1.008 | 2.22% | 1.37% | 1.001 |
| binary-trees | 1.8992 | 1.9008 | 1.001 | 7.89% | 2.08% | 1.000 |

`push_frame` loses its entry copy: the old build copies the 80-byte `Frame`
into a 0x60-byte frame with five 16-byte loads and stores before its first
test, the new one starts with the frame-limit test in a 0x10-byte frame
(96 instructions against 91, the rest being the copy into the frames
vector and the error path). `--check-module pkg::vm`: old 9.136 and 9.044 s,
new 9.185 and 9.151 s.

**No kernel is slower beyond its bounds; the upgrade stands.** Fib is 0.6%
faster, within its ranges, not the 3.8% the experiment release gave in
[reading by-value parameters in place, measured](#reading-by-value-parameters-in-place-measured);
that comparison differed from this one in base compiler and Halo source
(before `loop { match }`), and this run does not explain the difference.
Integer-table's 2.5% is also within its ranges.

## Growing the array in place on the main release

### Criterion, recorded before measuring

Whitefoot main now lowers `grow` through a counted reallocation
(Whitefoot#280, release `wf-b2209fd31035`), the reopening condition of the
rejected in-place growth. This branch reapplies `6f49ca6` on the pinned main
release. On the experiment release the change made integer-table 14.0%
faster ([reallocating grow](#growing-the-array-in-place-with-a-reallocating-grow)).
Comparison: the upgrade branch (pin `wf-b2209fd31035`) against this branch,
same compiler, six interleaved full-LTO pairs over the seven kernels with a
twin of the base, on the 14900K. Kept if integer-table's median falls at
least 5%, by more than both ranges and the twin's difference, no other
kernel is slower beyond its larger range and the twin's difference, and
`make check` passes, including the table-growth oracle cases; otherwise
reverted with its measurements kept.

### Result

[Run 37880509263](https://github.com/Ming-Research/Halo-wf/actions/runs/37880509263),
artifact `halo-bench-grow`: the upgrade branch `eb4d2f2f4` against this
branch (the run's `git diff --stat`: `lib/halo/heap/tables.wf` only),
`wf-b2209fd31035`, six interleaved full-LTO pairs with a twin of the base:

| Kernel | Base | In place | Ratio | Base range | In-place range | Twin ratio |
|---|---:|---:|---:|---:|---:|---:|
| fib | 0.1037 | 0.1033 | 0.996 | 1.12% | 0.76% | 1.010 |
| loop | 0.4347 | 0.4340 | 0.998 | 1.03% | 1.34% | 1.001 |
| integer-table | 0.4794 | 0.4218 | 0.880 | 2.80% | 1.93% | 1.009 |
| string-key | 0.0259 | 0.0259 | 1.000 | 7.82% | 3.60% | 0.999 |
| concat | 0.0776 | 0.0741 | 0.956 | 12.04% | 8.60% | 1.003 |
| sort | 0.1782 | 0.1746 | 0.980 | 12.50% | 5.91% | 0.991 |
| binary-trees | 1.9030 | 1.9059 | 1.002 | 0.85% | 2.48% | 0.995 |

**The runtime part of the criterion passes:** integer-table takes 0.880
times as long, beyond both ranges and the twin's difference, close to the
experiment release's 14.0%; no kernel is slower beyond its bounds. The
change is kept if `make check` passes on the final revision.
