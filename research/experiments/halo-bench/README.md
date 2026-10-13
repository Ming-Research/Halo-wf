# Halo P1 performance baseline

Question: does the current Halo match dispatch meet the P1 median thresholds
in [VM.md sections 4, 5, 10 and 11](../../investigations/halo/VM.md)?
Criterion fixed before measurement: each Halo median must be at most Redis
7.0.15's bundled PUC Lua 5.1.5 median. A ratio above 1.5 on fib or the
numeric loop triggers attribution, inspecting value width and handle checks
first. Profile every measured kernel above 1.5; report sampled work in
value/handle access, dispatch, slow execution, GC and budget handling. Sampling
cannot establish the causal speedup of removing that work. The initial
baseline selected no C1–C6 candidate; subsequent bounded same-source trials
are recorded in [RESULTS.md](RESULTS.md). The later cost-repair experiment
below evaluates embedding roots
and the collector predicate separately from those candidates.

The nine `kernels/*.lua` are standalone Lua 5.1 scripts printing one numeric
checksum. Integer-table fills and then reads every entry. String-key rotates
four present keys; concat rotates four short interned results. Sort uses the
Park–Miller generator (seed 42, multiplier 48271, modulus 2147483647), whose
integer products remain exact in binary64, and checks order before summing.
Binary-trees uses item/left/right tables, a stretch tree, a retained tree,
and paired trees at each even depth. Captured-assignment calls a closure on
every iteration to assign its captured variable to `i` and read it back. The
owning chunk remains live throughout the loop, so both accesses use an open
upvalue. Its checksum is independently `sum(i, i=1..N) = N*(N+1)/2`, or
`500000500000` at the default `N = 1000000`. It adds the open read/write workload
for [the coroutine study's comparison 2](../../investigations/halo/COROUTINES.md#comparison-recorded-before-measuring);
the existing seven contain no captured assignment.

Producer-consumer creates one coroutine that yields each integer from 1 to
`N`; its consumer resumes it `N` times and sums the received values. A final
resume checks successful termination with no result and status `dead`, so the
workload contains `N` yields and `N+1` resumes. Its independent checksum is
`N*(N+1)/2`, or `5000050000` at the default `N = 100000`. This is
[the coroutine study's comparison 3](../../investigations/halo/COROUTINES.md#comparison-recorded-before-measuring):
an exploratory switch-cost comparison against PUC under the same full-LTO
conditions, reported with a profile and no performance threshold. No P1
performance threshold is applied to producer-consumer.
These files and the host serve P1 and the coroutine comparisons; remove them
when those experiments are superseded without needing reproduction.

The native `host/` installs only numeric `print`, uses `pkg::embed` with a
2 GiB logical live-heap limit, normal GC, and budget 2^64−1 (the VM’s unlimited sentinel, which skips decrements).
The budget-1000 comparison includes counter updates and embedding resume work;
it does not isolate decrement cost. Its stderr is
two numeric lines: suspension count and collection count. Any positional
argument selects budget 1000 (the oracle corpus default). `run.py` drives
existing native tools and validates their independently printed outputs;
Python does not implement compiler or VM semantics. This runner stays while
P1 is reproducible and is removed with the experiment if retired.

Build with the pinned compiler (`make compiler` downloads it; the Makefile's
`WHITEFOOTC` names its path) and full runtime LTO; `make reference-lua` builds
the PUC reference under `build/redis`:

```sh
make compiler reference-lua
wfc=build/whitefoot/$(sed -n 's/^release = //p' whitefoot.pin)/whitefootc
"$wfc" --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o research/experiments/halo-bench/target/halo
```

Use `target/` for regenerable logs and profiler reports. Run the smallest
sample first (`--kernels fib --runs 1`), then three interleaved pairs; inspect
spread before choosing repetitions. The runner never launches a full matrix
by default. Repeat the one/three calibration for each workload before a
selected batch. `--reference-only` sizes a PUC workload before risking a long
Halo launch; those timings are calibration, not a checksum-verified baseline. If PUC is far above roughly two seconds, lower its `N` with
`--scale`; the replacement applies to identical bytes on both engines and is
recorded. `--budget realistic` measures Halo at 1000 instead of 2^64−1.

```sh
python3 -B research/experiments/halo-bench/run.py --lua build/redis/redis-7.0.15/deps/lua/src/lua --compiler "$wfc" --kernels fib --runs 1 --out research/experiments/halo-bench/target/fib-one.json
```

Select `--kernels captured-assignment --runs 1` for its initial CI sample;
`--scale captured-assignment=N` changes the same source on both engines.
Its output follows the ordinary PUC checksum validation below, including the
independent PUC launch with `--before-binary` for comparison 2.

For comparison 3, begin in CI with
`--kernels producer-consumer --runs 1 --scale producer-consumer=1000`
(checksum `500500`), then inspect its duration
before selecting a larger scale or more interleaved pairs. Omit `--scale` for
the default workload. The producer-consumer checksum uses the same validation
against PUC as the other kernels; no threshold is applied to its reported
ratio. Measure and profile it on the 14900K through CI as the study requires.

Wall time surrounds each process launch through exit (source reading, engine
creation/compilation, execution, collection and teardown included). PUC reads
the same stdin bytes with `loadstring` and executes them; alternate PUC/Halo
and Halo/PUC pair order to balance drift. Checksum disagreement, nonzero exit,
missing/extra output, malformed stats, or any suspension in the large-budget
mode fails the run before its timing is admitted. Store raw observations in
JSON, including launch order, outputs, exit codes, source/binary/compiler
hashes, source revision, host and scales. Spread means min–max, with relative
range `(max−min)/median` also reported. Six pairs are the minimum selected
baseline; lengthen only if spread affects a threshold conclusion.

For attribution on macOS, `run.py --profile` samples each individual Halo
launch at 1 ms with `/usr/bin/sample`; its result JSON records the profiler's
exit and report. Use the same workload and budget as the baseline, and
exclude profiled timings from baseline medians. The runner requires one
nonzero sampled execution worker, including when
`sample` itself exits 0. Short processes may finish before attachment;
report this limitation or choose a longer recorded profiling workload. Raw
data and supported attribution are in [RESULTS.md](RESULTS.md).

## Same-source Halo cost pairs

`--before-binary PATH` alternates Before/Halo then Halo/Before launches,
feeding identical source bytes to both. A separate PUC launch supplies the
independent checksum; both native outputs and stats must validate, and their
collection counts must agree unless `--collections-may-change` says the
change under test alters collection timing, when both counts are recorded per
pair instead. `--before-budget large|realistic` selects the
first binary's budget independently of `--budget` for the second. Before/after
pairs cannot be profiled or reference-only. `before` replaces `puc` in this
mode's timing summaries; the PUC check is not a timed pair member.

```sh
python3 -B research/experiments/halo-bench/run.py --lua build/redis/redis-7.0.15/deps/lua/src/lua --compiler "$wfc" --before-binary research/experiments/halo-bench/target/halo-before --binary research/experiments/halo-bench/target/halo-roots --before-budget realistic --budget realistic --kernels loop --runs 1 --out research/experiments/halo-bench/target/roots-one.json
```

The runner and retained cost observations serve the P1 cost-repair criteria in
RESULTS.md and are removed when those comparisons no longer need reproduction.

## Fastest-interpreter baseline

The question, method and result are in
[RESULTS.md](RESULTS.md#fastest-interpreter-baseline). Four files serve it
beside the P1 runner, and are removed with it when that yardstick is no
longer repeated:

- `fastest-baseline-2026-10-12.json` is the recorded run: every launch,
  the engines' digests, the manifests and CPU 2's state, kept while later
  comparisons repeat this run against it. Its AWFY bundle digests are of
  the bundles as generated at `9bff3d9`; `awfy.py` later changed only a
  header comment, so bundles generated since differ in those digests while
  the upstream per-file digests still match.

- `awfy.py` fetches are-we-fast-yet's Lua port at its pinned commit (MIT,
  the notice in each file; NBody from the Computer Language Benchmarks Game
  under the revised BSD license of upstream's `LICENSE.md`, which it copies
  beside the bundles) and writes one self-contained
  script per benchmark that plain Lua 5.1 runs, plus `manifest.json` with
  the inner iterations, per-file digests and the excluded benchmarks with
  their reasons. The bundles are generated in CI from the pinned upstream
  rather than vendored: the upstream files stay byte-identical and their
  digests are recorded, and nothing derived from them needs review here.
- `interpreters.sh` fetches and builds PUC Lua 5.4.9 (pinned SHA-256),
  LuaJIT 2.1 and Luau (pinned commits) with each project's default release
  build, and writes their versions, digests, compilers and a compile line
  to `manifest.txt`. PUC Lua 5.1.5 is Redis 7.0.15's bundled Lua, built by
  `fetch-redis.sh <directory> 7.0.15`; the oracle reference moved to 7.2.16,
  and the baseline stays until a measurement decides it (`halo-bench-baseline-72`,
  [RESULTS.md](RESULTS.md#puc-515-from-redis-7015-against-redis-7216s)).
- `fastest.py` times Halo's bench host and any number of other
  interpreters (`--engine ID=COMMAND`, the workload path appended) round-robin
  on the kernels and the bundles, validates every result against PUC 5.1.5
  (`--reference`), marks an interpreter whose result differs n/a for that
  workload, and writes the raw launches as JSON and the medians with Halo's
  ratio as a markdown table beside it. It is a sibling of `run.py` rather
  than an extension, since it rotates N interpreters and excludes a
  disagreeing cell instead of failing the run; it reuses `run.py`'s Halo
  checks. `--sample` runs one round to time the run before `--rounds N`.
  Without `--halo` it times only the `--engine` interpreters and reports
  each one's median over `--reference`'s, to three decimals, as the
  comparison of two PUC 5.1.5 builds does; `--expect RUN.json` requires
  the reference to print the checksums a recorded run holds, and `--strict`
  fails the run on any disagreement instead of marking the cell n/a.

The recorded run came from a temporary workflow, kept at
[`9bff3d9`](https://github.com/Ming-Research/Halo-wf/blob/9bff3d991b4aee1327f720e03d55bc0c366f82b5/.github/workflows/fastest-baseline.yml): it built Halo's bench host with
full LTO, ran `fetch-redis.sh`, `interpreters.sh` and `awfy.py`, then the
sample and six rounds on the 14900K's CPU 2. A repetition runs the same
steps; for example, the sample with two interpreters:

```sh
python3 -B research/experiments/halo-bench/fastest.py --halo build/fastest/halo \
  --engine puc-5.1.5=build/redis/redis-7.0.15/deps/lua/src/lua \
  --engine "luajit-2.1-joff=build/fastest/interpreters/luajit/src/luajit -joff" \
  --reference puc-5.1.5 --kernels fib,loop,integer-table,string-key,concat,sort,binary-trees \
  --scale binary-trees=14 --awfy build/fastest/awfy --sample --out build/fastest/sample.json
```

The kernels are named because `--kernels all` now also selects
captured-assignment and producer-consumer, which the recorded run did not
time.
