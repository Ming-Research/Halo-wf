# Nil-fill instruction attribution

Source audit complete; CI built and disassembled all three programs (results
below, CI run 38388718672 on revision 1501f54e). No local build, disassembly,
test or timing was run. Remove the temporary
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
| CI run/revision; versions; binary digests | Run 38388718672, revision `1501f54ee241d2569db8bd0385d5548a7041d98a`; clang/LLD 22.1.8, GNU objdump 2.42, x86-64. sha256: halo `17f37369...`, checked `34ec28ea...`, proved `e57aab23...`. **Measured.** |
| Pin | `wf-d837678c6905`, unchanged. |
| Builds | All exit codes 0 (halo, checked, proved, toolchain, extraction, parser self-check); compiler log empty. The proved witness's `requires`/`invariant` were accepted. The only non-zero code is the witnesses' symbol grep for `nilfill_` (1 = no match: both functions were inlined into `wf_main.resume`). **Measured.** |
| Halo nil-fill loop | Two copies in `wf_package.halo.vm.enter_lua`: header 0x33770 / latch 0x337b4 (with the odd-slot peel at 0x33582) and header 0x337f0 / latch 0x33834 (peel at 0x33654). Identical shape. 2x unrolled; 23 instructions per 2 slots = **11.5 per slot**. **Measured.** |
| Checked witness loop | In `wf_main.resume`, header 0xd860, latch 0xd8b0, peel at 0xd52d. 2x unrolled; 25 instructions per 2 slots = **12.5 per slot**. **Measured.** |
| Proved witness loop | In `wf_main.resume`, 4x unrolled body 0xd590..0xd5c7: 11 instructions per 4 slots = **2.75 per slot**; scalar remainder loop 0xd550..0xd566: 6 per slot (runs 0-3 times). **Measured.** |
| Oracle comparison on this revision | **NOT RUN**; diagnostic workflow runs no gate. |

## Observed loops

How the Halo loop was identified: it is the only loop whose body stores a
zeroed 16-byte register (`xorps %xmm0,%xmm0` before the loop, `movups
%xmm0,(base+idx*16)` in it, `shl $4` for the stride) behind a bounds compare
and a saturating-add pattern. The other `xorps`/`movups` sites in the function
are the argument shift loop (load, store, then zero the source; 0x335d0) and a
copy; they also load slots, which the nil fill does not.

### Halo (2x unrolled, copy at 0x33770)

```
33770: add $0x2,%rdx            ; i += 2
33774: add $-2,%r9              ; ~i-style counter 1 (for the saturating add)
33778: add $0x2,%r10            ; i+1 counter
3377c: add $-2,%r11             ; ~i-style counter 2
33780: add $-2,%r8              ; trip count
33784: je  33599                ; exit
3378a: cmp %r13,%r9 ; mov %r13,%r15 ; cmovb %r9,%r15   ; min(b, ~i)
33794: cmp %r13,%r11; mov %r13,%rax ; cmovb %r11,%rax  ; min(b, ~(i+1))
3379e: add %rdx,%rax            ; j = min(...) + i : saturating b + i
337a1: cmp %rdi,%rax            ; j < len (len already in a register)
337a4: jae 337ae                ; skip store if out of bounds
337a6: shl $4,%rax              ; j * 16
337aa: movups %xmm0,(%rsi,%rax,1)  ; the 16-byte nil store
337ae: add %r10,%r15            ; second slot's j
337b1: cmp %rdi,%r15 ; jae 33770   ; its bounds check
337b6: shl $4,%r15
337ba: movups %xmm0,(%rsi,%r15,1)  ; second 16-byte nil store
337bf: jmp 33770
```

Per slot: saturating add 4 (cmp, mov, cmovb, add), bounds check 2, address and
store 2; per pair: induction 6 plus one jmp. 8 + 8 + 6 + 1 = 23.

### Checked witness (2x unrolled, 0xd860)

Same structure as Halo's loop: 5 induction updates, two cmp/mov/cmovb
saturating-min sequences, add, `cmp $0x5f` against the constant length (not
removed even though the length is a compile-time 96), `ja`, `shl $4`, and the
nil written as two stores (`movb $0,(..)` tag, `movq $0,8(..)` payload).
25 per pair: Halo's 23 plus one extra store per slot.

### Proved witness (4x unrolled, 0xd590)

```
d590: movb $0x0,-0x38(%rdx) ; movq $0x0,-0x30(%rdx)
d59c: movb $0x0,-0x28(%rdx) ; movq $0x0,-0x20(%rdx)
d5a8: movb $0x0,-0x18(%rdx) ; movq $0x0,-0x10(%rdx)
d5b4: movb $0x0,-0x8(%rdx)  ; movq $0x0,(%rdx)
d5bf: add $0x40,%rdx            ; pointer
d5c3: add $-4,%rcx              ; count
d5c7: jne d590
```

No saturation, no bounds compare, no length load, no per-slot shift: 8 stores
and 3 loop instructions for 4 slots. The remainder loop (0-3 slots) is 6 per
slot (two stores, `dec`, `add`, `cmp`, `jne`).

## Findings

1. **Measured.** Halo's loop costs 11.5 instructions per slot and the checked
   witness 12.5, so the checked witness reproduces Halo's loop (Halo's is one
   instruction cheaper per slot because it stores 16 bytes at once). The
   saturating add is 4 of the 11.5, the bounds check 2, and the induction
   bookkeeping 3.5; only 2 do the store.
2. **Measured.** The proved witness drops all of that: 2.75 per slot, 4.5x
   fewer than checked (12.5) and 4.2x fewer than Halo (11.5), with its
   2-store nil. Neither loop is vectorized; both Halo and checked are only
   unrolled 2x with branchy bodies, and proved is unrolled 4x without
   vectors.
3. **Inferred.** The earlier "about 23 instructions per slot" matches the 23
   instructions of one 2-slot unrolled iteration, so the Callgrind iteration
   count probably counted unrolled iterations; per slot the cost is about
   half. This cannot be confirmed without the raw profile.
4. **Inferred.** The two Halo copies come from LTO duplicating the fill after
   the vararg branch; not traced.

## Conditional disposition

**Outcome (measured, then inferred).** The proved witness is accepted and
reaches 2.75 instructions per slot (6 in the remainder), within the six-per-
slot criterion and 4.5x below the checked form. So the cost is in Halo's
source, not in Whitefoot code generation: state the bound once before the
loop and drop the saturating add and the per-slot check. Not established:
that Halo's loop accepts the same invariant with a dynamic stack length (the
witnesses use a constant length of 96, which may help unrolling), and any
speedup; both need the gate and a same-source timing run. Halo's real
loop and the checked witness agree in shape, so the witness is a fair model.

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
checker gap. **No Whitefoot gap is filed: the proved witness is not bloated.**

Board MCP tools are unavailable here, so no board update/request was made.

Static review: a separate read-only gpt-6.1-sol agent reviewed the five new
files against origin/main, the project checklist, design correspondence and
evidence rules. No outstanding findings within scope. Fixed incomplete-path
accounting and the initially bounded checked harness; executable validation,
witness acceptance, loop identity and instruction counts remain unverified.
