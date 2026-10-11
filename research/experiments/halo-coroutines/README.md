# Coroutine mechanism-A witnesses

These independent Whitefoot programs ask the language and lowering questions
in [the coroutine study](../../investigations/halo/COROUTINES.md), board item
`halo-coroutines`. They import no Halo code. They are evidence for the
experiment, not coroutine support or performance results. Keep the witnesses
while the study or a filed Whitefoot gap needs reproduction; remove this
directory when both no longer need it. Remove the temporary
`.github/workflows/coroutine-witnesses.yml` before the work branch is ready;
keep any still-needed reproduction commands here.

## Questions and expected outcomes

Each entry in `witnesses/modules.wfg` compiles independently with the compiler
named by `whitefoot.pin`; one refusal cannot hide the other entries.

| Entry | Question and expected outcome | Meaning of a refusal or poor lowering |
| --- | --- | --- |
| `length_transport` | Does `swap` transport the saved box's known length to the active box? `exchange` requires `saved^.inner.len >= 256` and ensures `active^.inner.len >= 256`, with only the whole-box swap in its body. The postcondition is semantically true; the plan predicts proof refusal at this pin. | A postcondition refusal isolates the missing exchange-image relation. An unrelated diagnostic does not establish that gap. Acceptance overturns the prediction and needs its compiler evidence retained. Never insert a length test to make this witness pass. |
| `box_exchange` | Can `box_exchange` exchange two `Box<Slots<u64>>` owners? Expected: successful compilation and exit zero; only owner/descriptor loads and stores in the studied function. | Refusal prevents the natural ownership transfer. Element-copy loops, allocation, release, or `memcpy` proportional to stack length would be poor lowering; setup and teardown in `main` are outside the studied function. |
| `owner_branch` | Can `read_open` and `write_open` select the active stack when an Open capture's owner equals the current thread, and the saved stack otherwise, with Closed captures independent of either? Expected: compilation and exit zero. | Refusal isolates a type/effect/proof issue before VM integration. On the active path expect a tag test, owner comparison, existing slot check, and direct stack load/store; an inactive descriptor load, allocation or content copy on that path needs investigation. |
| `dispatch_exchange` | Can an eight-parameter dispatch-style loop exchange its active/saved stack and resume a saved cursor while unrelated arms preserve their window facts? Expected: compilation and exit zero. | Refusal identifies a continuation/proof issue. Inspect per-arm transfers, register spills and window checks: exchange work should stay on the switch arm, and unrelated hot arms should not acquire full-window rechecks or stack copies. ABI-required argument stack slots alone are not a regression. |

The dispatch probe uses the existing checked-cursor protocol after selecting
a continuation. This is an independent VM requirement, not evidence that the
`length_transport` contract is proved. These small probes cannot establish
comparison 2's runtime-cost criterion or guarantee Halo's eventual lowering.

## CI and inspection

The temporary workflow uses `make toolchain`, as `check.yml` does: the pinned
Whitefoot-kit downloads and verifies the release and installs the LLVM major
its manifest names. CI also installs that major's `llvm-objdump`.
`inspect.py`, called only by this workflow or an explicit reproduction, runs
every ordinary compile, prints diagnostics and the command's own exit code,
and retains per-stage exit codes, command lines and elapsed times in
`results.json`. A refusal makes the job fail **after** the other witnesses
have been attempted. A timeout is recorded as 124 and a launch failure as
127. Compiler, execution and inspection failures are never treated as a pass.
Successful binaries must exit zero. All output is uploaded even on failure.

There is no source-level `noinline` in the pinned language. For inspection,
the script also uses the compiler's supported `--emit-llvm` path and follows
the retained-function technique in the pinned compiler's
`compiler/src/backend/tests/owned_places.rs` and
`research/experiments/container-representation/foundation/Makefile`:
make the studied definitions externally visible and add LLVM `noinline`,
without changing instructions or source acceptance. External visibility also
prevents internal constant-argument specialization. All other functions keep
their optimization permissions. CI exercises missing/duplicate-symbol
controls before using this transformation and refuses missing machine-code
symbols after disassembly.

The ordinary binaries use `--full-lto` and run their small semantic checks in
CI. The inspection compiles the complete retained module to `retained.o`
with Clang `-O2 -c -x ir`, then disassembles it with `llvm-objdump -d`;
`--full-lto` cannot be combined with `--emit-llvm`. Emitted IR needs the
Whitefoot runtime to link, so retained inspection stops at the object and
does not run a retained binary. These objects expose helper boundaries,
not production timing. No Whitefoot source or runtime is vendored here.

Reproduce on a CI runner from the repository root:

```sh
make toolchain
release=$(sed -n 's/^release = //p' whitefoot.pin)
major=$(/usr/bin/clang -dumpversion | cut -d. -f1)
sudo apt-get install -y "llvm-$major"
python3 -B research/experiments/halo-coroutines/inspect.py \
  --compiler "build/whitefoot/$release/whitefootc" \
  --objdump "/usr/bin/llvm-objdump-$major" --out build/coroutine-witnesses
```

The artifact keeps `ordinary`, `raw.ll`, `retained.ll`, `retained.o`, compiler
diagnostics and `disassemble.stdout` under each codegen entry. `results.json`
maps the studied names to their actual symbols. Inspect a retained object
again with:

```sh
llvm-objdump -d path/to/retained.o
```

Read the named function and any dispatch-arm functions it transfers to. The
script retains full disassembly, the complete object and raw IR to follow
those arm transfers. Record
actual instructions and diagnostics before filing a Whitefoot gap; none is
demonstrated merely by this setup.

## Captured-assignment baseline

The eighth [halo-bench kernel](../halo-bench/README.md) writes and reads an
open capture without coroutines. The workflow's separate job builds the
unchanged Halo engine and PUC reference, then uses the existing benchmark
runner for one small checksum comparison at `N = 1000` (expected `500500`).
This job remains independent of the expected length-transport refusal.
Its hosted-runner duration is only a correctness sample, not a performance
comparison. Comparison 2 still requires eight kernels, interleaved full-LTO
pairs and the baseline twin on the 14900K.
