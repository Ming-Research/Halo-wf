# Nil-fill instruction attribution

Source audit complete; compilation and machine-code attribution **await CI**.
No local build, disassembly, test or timing was run. Remove the temporary
workflow before the branch is ready; retire this record, its witnesses and
the wired extraction helper when this investigation is superseded. Halo's
implementation, pin and submodules are unchanged.

## Question and falsifier

The task reports 65M Callgrind instructions over 2.84M nil-fill iterations
in List and 90M over 3.93M in Towers: about 23 instructions per slot.
These are supplied rounded observations, without a binary revision or raw
profile; they cannot establish this CI binary's count.

Compare unchanged Halo and two standalone forms under the same pin, Linux
x86-64 and full LTO. Suspect saturation, metadata/address work and the
explicit bounds branch. Reject that explanation if the selected Halo loop
lacks this work; reject a source-only repair if the proved witness retains
comparable overhead. Disassembly does not establish a speedup.

## The source already guarantees the bound

[enter_lua](../../../lib/halo/vm/calls.wf) computes `room = b +sat 256_u64`,
rejects `room == unlimited` (the largest u64), then calls
[ensure_stack](../../../lib/halo/vm/state.wf), whose contract guarantees
`stack.len >= room`. Intervening loops only replace existing slots.
[Proto.maxstack](../../../lib/halo/value/module.wfm) is u8, hence at most 255.
Reaching nil-fill proves mathematical `b + 256 < U64_MAX` and
`b + maxstack < room <= stack.len`. Each executed iteration has
`i < maxstack`, so `b + i` cannot overflow and is in bounds. Empty ranges
need no assumption that `fixed <= maxstack`. Earlier saturation to the
largest u64 is caught by the existing room check too.

`enter_lua` has no precondition; normal calls and coroutine startup rely on
its internal growth. Do not add a caller requirement there. Existing register
helpers already use `base + 256 <= stack.len` with plain addition/indexing;
[VM.md](VM.md#3-calls) describes this frame bound. Relevant design owners are
[Halo](../../../design/halo.md), [calls](../../../design/halo/calls.md),
[values](../../../design/halo/values.md) and
[dispatch](../../../design/halo/dispatch.md). None requires these per-slot
guards. Checker acceptance of carrying the bound from sentinel exclusion
through preceding loops remains unverified.

## Witnesses and instruction attribution

[Checked](witnesses/nilfill-checked.wf) reproduces saturation and the per-slot
guard. [Proved](witnesses/nilfill-proved.wf) states
`requires b + maxstack <= stack^.inner.len` and preserves it in the header:

```whitefoot
for (
  i in fixed..maxstack,
  invariant frame: b + maxstack <= stack^.inner.len
) {
  let j = b + i;
  set stack^.inner[j] = SlotValue::Nil();
}
```

Both complete programs initialize boxed slots with numbers and observe all
resulting tags in an exit-status checksum. Runtime argument count is mixed
by modular multiplication to generate b; only the proved caller reduces b
to a valid extent, since its API requires that bound. Giving both callers
bounded offsets would let LTO erase the checked variant's checks too.
This harness arithmetic generates inputs, not a repair to the fill algorithm.
Confirm the Nil/f64 enum's intended 16-byte stride and actual store width;
unused Nil payload bytes need not necessarily be written.

Syntax follows the kit's main-line `origin/main` writing guide (local
`main` lacks it); prelude/host interfaces were read at the pinned Whitefoot
commit. Acceptance is pending; preserve any rejection rather than hide it
with a runtime guard.

These mappings are **hypotheses, not observed assembly**:

| Source | Work to identify in CI |
| --- | --- |
| `b +sat i` | Add and carry/overflow selection, perhaps conditional move; trace b/i operands. |
| `j < stack.len` | Length load, compare and branch, distinct from the loop-exit comparison. |
| `stack[j]` | Box/data-pointer loads, stride scaling and address addition; distinguish hoisted from repeated work. |
| `Nil()` | Tag/payload stores, SIMD store or temporary copies; record offsets and widths. |
| Counted loop | Induction update, endpoint comparison and back-edge; identify rotation/unrolling and scalar tail. |
| Lowering overhead | Spills/reloads and temporaries; trace rather than assume their cause. |

Repeated metadata loads establish work, not why it exists. Slot stores cannot
semantically change metadata; lost alias information, poor promotion/address
lowering and register pressure remain competing causes. Distinguishing them
may need emitted LLVM and another controlled comparison.

## CI evidence to fill in

The workflow matches [check.yml](../../../.github/workflows/check.yml):
Ubuntu 24.04, checkout/submodules and `make toolchain`; `make compiler`
fetches/verifies the unchanged pin. Its command matches
[halo-bench](../../experiments/halo-bench/README.md), changing only the output:

```sh
"$wfc" --graph research/experiments/halo-bench/modules.wfg --entry bench --full-lto -o build/nilfill-disasm/halo
```

Witnesses also use `--full-lto`; binaries never run. Artifacts retain
diagnostics/exit codes, manifest, versions, digests, nm output, whole functions
and separate innermost backward-edge intervals. The Python helper adds CFG
counts that native nm/objdump lack; its synthetic checks run only in CI.

Halo has several copy/clear loops. The first artifact enumerates candidates;
identify `fixed..maxstack` by tracing its fields and b in the whole function
before recording addresses. Static interval size differs from executed
store-path size because branches skip blocks; padding, calls and paths laid
out outside the interval need separate accounting. The audited Halo bound
selects the in-bounds path. LTO may inline, specialize, vectorize, unroll,
use memset or remove a fill. Missing evidence remains unresolved, not zero.

| Evidence | Result |
| --- | --- |
| CI run/revision; manifest, LLVM/binutils versions and binary digests | **PENDING** |
| Pin | `wf-d837678c6905`, unchanged |
| Halo nil-fill symbol/header/latch; store-path count per slot | **PENDING** |
| Checked acceptance/symbol/loop; store/skip counts and stride | **PENDING** |
| Proved acceptance/symbol/loop; count, stride and store widths | **PENDING** |
| Instruction-by-instruction attribution with addresses | **PENDING** |
| Oracle comparison on this revision | **NOT RUN**; diagnostic workflow runs no gate |

## Conditional disposition

A compact scalar reference uses two 8-byte stores, one induction/pointer
update, one compare and one back-edge: five instructions per slot, or six
with an extra index/pointer update. SIMD or tag-only stores may need fewer.
This is a proposed criterion, not observed output or a universal target rule.

If the proved witness accepts and reaches at most six scalar instructions
per slot, propose Halo's plain addition/unconditional store with header
invariant `b + 256_u64 <= stack^.inner.len`, retaining growth and sentinel
errors. Verify acceptance, full gate/oracle and same-source performance
before claiming a repair or speedup.

If it remains bloated, file the complete proved witness plus compiler,
binary and selected-loop evidence into Whitefoot. Proposed acceptance:
the valid static bound is accepted without extra runtime guards; an
unspecialized Linux x86-64 full-LTO scalar loop executes at most six
instructions per stored 16-byte slot, prepares invariant metadata outside
the loop, and has no saturation or bounds branch. Normalize any vector,
unrolled or library replacement by slots stored, including its scalar tail;
missing loops alone do not pass. A rejected legitimate bound is a separate
checker gap. **Disposition awaits CI; no gap has been filed.**

Board MCP tools are unavailable here, so no board update/request was made.

Static review: a separate read-only gpt-6.1-sol agent reviewed the five new
files against origin/main, the project checklist, design correspondence and
evidence rules. No outstanding findings within scope. Fixed incomplete-path
accounting and the initially bounded checked harness; executable validation,
witness acceptance, loop identity and instruction counts remain unverified.
