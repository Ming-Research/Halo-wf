# Halo embedding comparison

Compiler builds and checks have a persistent cache at
`${WHITEFOOT_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/whitefoot}/halo-e2e`.
`--cache DIR` overrides it; `--no-cache` disables caching. Cache paths must be
outside the repository and survive scratch-executable cleanup.
This runner reports program execution times, so native builds default to
`--full-lto`. The compiler rejects combining `--full-lto` with `--cache`;
`--incremental` selects the persistent cache instead. Cached runtime timings
have unvalidated differences from full LTO and are only sizing observations.
Use the default or explicit `--full-lto` for runtime performance measurements.
Reused binaries must have been built with the corresponding mode.

This explicitly invoked experiment runs the unchanged Halo oracle scripts through
`pkg::embed` and an in-memory Whitefoot Redis test host. It compares typed RESP2
JSON with the existing Redis 7.0.15 observations; it never regenerates them.
The runner owns fixture transport, JSON formatting and comparison, not Lua
execution. The Whitefoot host owns commands and both reply conversions.

The embedding module, test program, runner and result record serve VM.md section
6 and its first end-to-end comparison. They live in the existing Halo library
and experiment homes, and are removed or superseded when the production firn
binding replaces this test host or Halo is retired.

The runner never changes compiler, VM, heap or oracle files. Unsupported
commands and library functions are reported as failures rather than silently
removed from the corpus. See RESULTS.md for the measured coverage and gaps.

Run from the repository root, using an existing compiler (no Cargo):

```sh
python3 -B research/experiments/halo-e2e/run.py --compiler /path/to/whitefootc --incremental --filter lua-core/assert --budgets 1,7,1000 --report /private/tmp/halo-e2e-sample.md
python3 -B research/experiments/halo-e2e/run.py --compiler /path/to/whitefootc --full-lto --budgets 1,7,1000 --report /private/tmp/halo-e2e-results.md --actual /private/tmp/halo-e2e-replies
```

On 2026-10-05, macOS 26.6.2 arm64, the supplied gate compiler (SHA-256
`8d391bd75e31dbd2068f30e586c22cea59f10ef16b21b3f587d4364fec2beeb2`) built this worktree over parent
`4fcb0b289e8b5c76fcbb2f44031e29b6bf0f8acf` with `--incremental --budgets 1,7,1000`:
**480.935 s cold, 0.124 s unchanged, 233.842 s after a one-line body edit**.
Every run passed **240/240** comparisons. The default `halo-e2e` cache was
initially absent and retained between runs. The edit swapped `used + 1_u64`
for `1_u64 + used` in `lib/halo/embed/sha1.wf` and was reverted afterward.
These are compiler-invocation times, excluding oracle execution; cached runtime
speed relative to full LTO was not measured.

The module-fragment trial required an unchanged-build improvement before
adoption: ordinary cached linking took 0.133 s;
`--fragments module` took 9.573 s to populate and
0.221 s warm, and its binary passed 240/240. These single
trials did not show an improvement, so runners retain ordinary cached linking.
A separate relative-graph-path trial missed the absolute-path entry cache and
repeated front-end work; keep graph spelling consistent across measurements.

The runner builds the Whitefoot test executable once and runs every script with a
fresh engine/store. `--filter GROUP/NAME` selects a small sample. `--binary PATH`
reuses an executable; the caller must ensure it was built from the identified
source bytes. Both sides are parsed as typed reply objects, validated, and
rendered to the oracle's exact indented ASCII JSON before byte comparison; no
payload, integer, order, error location or nil kind is normalized. The runner
exits one for a mismatch and two for a build failure. Expected files remain
read-only. Python is used for binary transport and JSON comparison independently
of the Whitefoot implementation, not as a compiler or Lua interpreter.

The preparation chunk installs KEYS/ARGV from the JSON header and executes setup
commands through the same test host. A NUL separates it from the unchanged script
bytes on stdin. Global protection is applied afterward: raw host assignment
bypasses readonly, while script writes raise and absent reads call a rejecting
`__index`. The VM installs its slice-1 library; this host adds Redis members.

The `smoke` entry and `test` executable with three arguments run the embedding
probe (stdin is unused): cache, flush, reset, budget resumption, host outcomes,
and forced collection of pins and cached constants, including pin/compile/unpin
changes between suspended budget checkpoints, the chunk name runtime errors
are located in, and host calls left pending: completed, failed into a `pcall`
inside a library callback, and refused by `resume`. A nonzero exit is the
probe's numbered failed observation; `make check` runs it before the oracle
comparison. Its cjson lifecycle observations (exits 120–145) keep an extracted
encoder in a global table while discarded instances lose their buffers, slots
are reused in index order, and 32 runs of eight new/encode operations stay
bounded on one VM in both ordinary and stress collection. They also check
module settings at permanent index zero, default settings after a host rewrites
a free slot, and allocation after the host truncates trailing slots without an
intervening collection. Before reclamation, exit 126 detects a discarded
instance's retained buffer. These are resource-lifetime assertions of the
embedding contract; the unchanged cjson oracle scripts still compare replies
with Redis. [GAPS.md](GAPS.md) names limits and concrete reopening
conditions.

Collector statistics and pause observations (exits 146–176) control and observe
collections through the embedding API. Statistics checks run in ordinary and
stress modes, check the zero snapshot before collection, reclaim three empty
tables and a captured upvalue, and pin a returned closure with two distinct
captures to check live upvalues. All statistics chunks compile before the
baseline collection, so compiler and library interning are already included in
its live totals. Each following collection checks per-kind conservation using
the allocation formulas in
[`heap/slabs.wf`](../../../lib/halo/heap/slabs.wf), plus exact expected live
deltas and freed totals. The workload entry replaces one 24-byte entry closure
with another; its snapshot precedes the Lua allocations. The next idle sweep
reclaims three empty tables (144 bytes), one 10-byte concatenated string
(34 bytes), the workload entry and its one-capture closure (52 bytes), and one
upvalue (32 bytes). The pinned two-capture closure adds exactly one live closure
(32 bytes) and two live upvalues (64 bytes) to the baseline.
Observation 150 checks live totals relative to that baseline without reading
heap storage. After the allocation-free sweeps, the public `intern` and `pin`
calls create and retain the fresh 14-byte `gc-live-string` (38 logical bytes).
A forced cached idle sweep must gain exactly one live string and 38 bytes with
zero string reclamation; after public `unpin`, the next sweep must free exactly
one string and 38 bytes and return live strings to their previous totals.
A constant live-string count fails observation 150. Observation 151 checks exact
reclamation and conservation; counting a freed closure twice fails it.
Observation 155 checks that visited slots cover live plus freed objects, a
lower bound that does not establish visits to already free slots. It then uses
budget/resume on a cached allocation-free loop to require equal visits, equal
live totals and zero reclamation in two consecutive forced collections.
Compared with the reclamation sweep, string visits must not decrease and
upvalue and table visits must remain equal: no strings, upvalues or tables are
allocated between these snapshots, and the slots freed by that sweep must still
be visited. Counting only occupied string or upvalue slots fails observation
155. Table visits must also exceed live tables; the public API does not
independently expose absolute slab lengths. The checks also account for
gray-stack pops and preserve every snapshot field across reset.
Pause checks cover clamping below
100, the 1 MiB floor, fractional percentages, saturation without premature
product overflow, reset persistence, stress overriding the
threshold, and exact restoration of the 200 percent threshold. Fresh engines
with an equally sized pinned table run the same allocation loop with stress
disabled to distinguish collection frequency at 200 and 400 percent; stress
would otherwise override that comparison. Byte expectations use the heap's
specified logical accounting, not process memory or slab reserve.
Ordinary-mode observations 171–176 cache an idle chunk and pin a 2 MiB table,
collect with the default pause, then set 400 percent without forcing collection.
A discarded 4 MiB table must still trigger one collection at the old threshold.
The completed snapshot must then report the 400 percent threshold: one more
4 MiB allocation stays below it, while two cross it. Each cached idle start
adds one 24-byte entry closure. This catches a setter that immediately rewrites
the current threshold, and a collector that reports the new threshold but keeps
using the old one or never schedules another collection.

The Redis error/SHA-1 comparison uses Redis 7.0.15's local `script_lua.c`
and `eval.c` as the formatting reference: command errors are tables, Lua
errors are strings, and the EVAL wrapper adds source/line and the SHA-1 of
the unchanged script body. SHA-1 is checked independently against Python's
`hashlib` on binary inputs, including block and padding boundaries. These
checks belong to this explicitly invoked experiment and leave oracle files
unchanged.

Add `--verify-sha1` to check three fixed and 1,000 seeded random binary
inputs against `hashlib` before the selected corpus. Add `--verify-errors`
to check command/global error locations, SHA-1 arity errors and protected
error values against Redis-source-grounded expectations. It exercises the same
Whitefoot `redis.sha1hex` used by scripts. `lib/halo/embed/sha1.wf` serves
digest generation and the test host's `test/redis-error.wf` the EVAL reply
formatter; they are superseded with the embedding if Halo is retired or its
production binding replaces these responsibilities.

Add `--gc-stress` to enable the engine's collector stress switch. Budget
arguments still use the existing positional protocol; `--gc-stress` is an
explicit flag received by the test executable and excluded from that count.
Completed collections during the tested script (excluding preparation) are
reported on stderr as JSON and included in each comparison row. The reply on
stdout keeps the original typed RESP2 schema. The switch defaults off.
See [the F4 experiment](../halo-gc/README.md#vm-stress-experiment-f4) for
missing-root mutation and memory-limit evidence.

`--cases PATH` runs paired local `scripts/GROUP/*.lua` and
`expected/GROUP/*.txt` files with the same comparator. `--verify-memory`
adds F4's unbounded allocator and then a recovery script in the same engine
and store; a second NUL separates that following script. `--collect-suspended`
adds one synthetic collector back-edge while a callback stack is parked,
before resume. `--isolate-frames` clears dead function-slot aliases at budget
checkpoints, leaving frame records to root executing closures. These last two
are explicit root-isolation probes; both default off. Their use and limits
are recorded in the F4 experiment.

`--omit-suspended-root --collect-suspended --gc-stress` selects the parked-root
negative control at budget 1: the harness hides the snapshot during collection
and restores it before resume. The suspended-stack comparison is expected to
fail with the original expected reply unchanged. Ordinary runs omit this flag.

`--scratch-root DIR` keeps temporary build and fixture files under an existing
chosen directory. The cost-repair runs use the benchmark's `target/` so all
new artifacts stay in the requested worktree; the default remains `/private/tmp`.

The lifecycle probe separates pin, compile and unpin with a forced collection
and its own survival/release observation after each edit. For discriminating
controls, the executable's `--omit-pin-refresh`, `--omit-compile-refresh` and
`--omit-unpin-refresh` modes bypass the embedding refresh at exactly that
checkpoint through the existing VM resume. They must fail with probe exits
59 (pin lost), 69 (cached literal lost) and 62 (released pin retained), while
ordinary `a b c` smoke mode exits 0. These modes serve the root-invalidation
observations and are retired with the research probe or replaced by a
maintained embedding test; they do not change GC or oracle expectations.
