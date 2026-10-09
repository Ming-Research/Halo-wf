# Temporary Halo embedding memory diagnostic

## Question and rejection criterion

Does process memory continue to grow per script after a complete Lua collection,
and which public API step or Whitefoot replacement shape reproduces that growth?
Firn reported about 160 B/call for `return 1` and about 380 B/call for its rate
limiter despite a constant live Lua heap. Its copied probe is the starting point
for [probe/probe.wf](probe/probe.wf), adapted from Firn-wf
`exp/halo-gc-stats` at `60a3030`.

The hypothesis is unreclaimed storage outside the live Lua object graph.
Flat counted heap after warm-up and collection rejects reproduction in that
variant. Similar positive growth in both intervals with stable last-collection
live objects/bytes supports the hypothesis, but does not by itself distinguish
a missing release from incorrect memory-meter accounting or retained reserve.

This diagnostic and [.github/workflows/halo-leak.yml](../../../.github/workflows/halo-leak.yml)
are temporary. Remove both after the leak is fixed; retain any regression case
that identifies the fault in the component that owns it. This is an investigation,
not a new engine design or a replacement for `make check`.

## Compiler prerequisite and current limits

No local compilation, checks or measurements have been run. At preparation,
Halo's `whitefoot.pin` names `wf-691ea8106920`. Its `std::process` interface,
and the requested language-reference revision `8b647edbb`, have neither
`MemoryMeter`, `Inputs.memory_meter` nor `heap_in_use`. Firn's source revision
pins `wf-631d3ffbe928`, whose standard-library interface provides all three.
The sources below require that memory-statistics API. The primary agent must
settle the compiler pin before these diagnostics can build; this change does
not move the pin, substitute an unpinned compiler, or replace the meter with RSS.
With the existing pin the expected failure is the missing process-memory API,
not a measured leak result.

Grammar, ownership, effects and storage forms were read from
`8b647edbb:spec/kernel-spec.md`; the additional process-memory interface was
read from `631d3ffbe928:lib/std/process/module.wfm`. The six metadata records
and slab layouts mirror the current Halo interfaces. This establishes source
intent only: CI must settle acceptance and runtime observations.

## Method and output

Each entry runs in a separate fresh process. An engine uses its default
collection pause and 1 MiB threshold, a zero logical heap limit, and stress off
during workload intervals. Each variant warms up for 1,000 calls, captures
`heap0`, runs 10,000 calls, captures `heap1`, runs 10,000 calls, and captures
`heap2`. CSV output happens after all samples to keep output allocations out of
the measured intervals.

Immediately before each Halo heap sample, the probe enables stress, starts an
already cached idle `return 1` chunk, verifies its result and exactly one new
completed collection, then restores stress off. It reads `last_collection` and
`heap_in_use` with no intervening workload or output. The idle entry safepoint
collects the preceding workload's garbage, including an earlier returned table.
It also retains its own entry closure. All three samples use this same convention.
This follows halo-e2e's `gc_probe_collect_cached`; the sampler itself runs
`start`, so `sample_only` measures its fixed per-sample contribution.

Each successful entry prints one row:

```text
variant,heap0,heap1,heap2,collections0,collections1,collections2,live_objects0,live_objects1,live_objects2,live_bytes0,live_bytes1,live_bytes2
```

Object/byte totals sum strings, tables, closures and upvalues from the last
completed sweep. They are logical payload counts, excluding slab/intern reserve
and compiler/VM metadata. The three collector groups are zero for Halo-free
witnesses, meaning **not applicable**, not that a collection was performed.
All witness-owned buffers are replaced or released before each reading; they
have no garbage collector to force.

The two interval readings are `(heap1 - heap0) / 10000` and
`(heap2 - heap1) / 10000` B/call, using signed differences. A failure to compile,
run, force exactly one collection, check the result/host count or print the row
is a failed diagnostic, never a zero-growth reading.

## Public embedding variants

| Entry | What one call isolates |
| --- | --- |
| `a` | Start and run cached `return 1`; verify and discard its numeric result. |
| `b` | `a` plus install new empty KEYS/ARGV tables before each start. |
| `c` | `b` plus explicit embedding reset after each completed run. |
| `d` | Flush the script cache, compile `return 1` fresh and start/run it each call. |
| `e` | Cached `local t = {1,2,3} return t`; read the result, check table kind/border, discard it. |
| `f` | Cached `local n = host_call() return n`; an installed counting host returns one. Exactly one host call is required per workload call. |
| `compile_only` | Flush and compile fresh each call, without workload execution. |
| `reset_only` | Embedding reset with no workload start/run. |
| `args_only` | Empty-table creation and KEYS/ARGV replacement with no workload execution. |
| `table_only` | Allocate and discard one empty table through the embedding API. |
| `sample_only` | Empty workload intervals; only the three sampling starts/collections execute. |

`compile` caches every script by contract. Literal compile-without-flush would
measure deliberate script retention, and each new active script's root bridge
would copy all cached constant prefixes. That adds increasing work and retained
tails rather than a bounded per-call leak experiment. Therefore `d` explicitly
includes `forget_all` before compiling. The newly compiled `return 1` script
also becomes the cached idle script for the next sample; no compilation occurs
inside the sampler. `compile_only` separates this bounded compile/flush lifecycle
from execution. These two variants cannot distinguish compiler allocation from
cache flushing without a further witness. This is a stated lifecycle choice,
not a change to the engine or a fallback for a missing language feature.

Every other variant compiles one idle chunk and one workload chunk before
warm-up. No result is pinned, and the probes do not reproduce Firn's pool,
registry, protocol conversion or rate-limiter workload.

## Start-step witnesses without Halo

`vm::start` first resets, then copies/replaces six metadata boxes, creates an
entry closure, ensures stack reserve, prepares a frame and drives execution.
Embedding reset, table allocation and host calls have the public controls above.
There is no embedding operation that replaces just one metadata box or frees
just an entry closure. [witness/witness.wf](witness/witness.wf) uses independent
Whitefoot structs and an environment-counting interface instead of adding
diagnostic entry points to Halo.

| Entry | Whitefoot shape and isolated step |
| --- | --- |
| `metadata_protos` | Copy one Halo-shaped Proto record and replace `vm^.protos` through a reference in an interface-generic function. |
| `metadata_lineinfo` | Copy 16 u32 line records and replace the boxed line buffer. |
| `metadata_source` | Copy 64 u8 source bytes and replace the source box. |
| `metadata_debug_names` | Copy 64 u8 name bytes and replace the debug-name box. |
| `metadata_local_variables` | Copy two nested LocalVariable/DebugName records and replace that box. |
| `metadata_upvalue_names` | Copy four DebugName records and replace the upvalue-name box. |
| `metadata_empty` | Replace all six boxes at zero capacity, covering empty metadata's allocation/release. |
| `reset_box` | Replace zero-capacity `stopped_stack`, as VM reset does. |
| `slot_field` / `slot_field_empty` | Replace only `vm^.heap.closures.inner[0].payload.upvals`: a Box inside a payload inside a slab slot, through a generic reference function. |
| `slab_payload` / `slab_payload_empty` | Replace the complete closure-shaped payload (callee enum plus upvalue Box), as `free_closure` does. |
| `slab_cell` / `slab_cell_empty` | Replace the whole cell (live/mark/free-list fields plus payload), as reuse in `alloc_closure` does. |
| `scope_boxes` | Allocate one empty Box and one 64-byte buffer, releasing both at function return; a control for scope release and meter accounting. |
| `stack_reserve` | Ensure 256 entry slots and 257 callee slots, then reuse that boxed reserve and copy/clear result slots; growth occurs during warm-up only. |
| `frame_cycle` | Append and remove a Halo-shaped frame with a retained 32-slot reserve; covers prepare/return frame storage without metadata copying or Lua execution. |
| `budget_only` | Assign the scalar budget through the generic VM reference without allocating or replacing a Box. |

The three slab pairs use 16 u32 elements (64 bytes) or zero capacity. Each
operation performs one replacement; these are storage-shape witnesses, not
Halo's full free-list or collector algorithm. Fixed source buffers and one slab
cell exist before warm-up. The metadata witnesses preserve the actual record
field order and types; they do not claim every record buffer is exactly 64 bytes.
Unlike Firn's earlier plain local/field/slot tests, the replacement goes through
`&WitnessVm` in a function generic over an interface and reaches a nested
`Box<Slots<...>>`.

The actual minimal dispatch workload is `a`; its stack and frame storage
shapes are isolated by `stack_reserve` and `frame_cycle`. There is no embedding
operation that dispatches without start setup, and a toy dispatch loop would
not reproduce Halo's execution. The embedding root bridge, collector scratch
storage and the full allocation/release interactions during dispatch remain
unlocalized if all individual storage witnesses stay flat. A flat witness
rejects only that particular shape, not every release performed by Halo. No
fixture or branch is inserted into production engine code.

## Expected interpretation and CI handoff

- **No reproduction:** heap is flat after warm-up; small fixed per-sample changes
  agree with `sample_only`; Halo live objects/bytes are stable.
- **Reproduction outside the Lua graph:** similar positive B/call in both
  intervals with stable live totals. Compare `b-a`, `c-b`, `e-a`, `f-a`
  and the isolated controls to choose the next component to inspect.
- **Garbage/retention still visible:** live objects or bytes increase too; do
  not label the entire process-memory delta a leak outside the Lua graph.
- **Reserve or transient effect:** growth confined to the first interval or
  unequal slopes needs capacity/accounting inspection before a linear claim.
- **Whitefoot release-shape lead:** one standalone replacement witness grows
  while `scope_boxes` stays flat. A zero-capacity failure can identify unreleased
  box storage independently of payload bytes. Growth in `scope_boxes` leaves
  scope release or meter accounting open.

The temporary workflow checks out submodules, runs `make toolchain` and
`make compiler`, builds every graph entry using that pinned release and runs
each executable directly, reading exit status outside a pipe. It prints the
raw rows and signed interval rates, and uploads samples, rates, build/run logs,
the exact revision, pin and compiler manifest. It continues after individual
entry failures so other available evidence and diagnostics are retained.
The existing gate workflow still runs independently on the primary agent's push.

The primary agent must inspect missing-API/compiler diagnostics first, then
collection validity, result/host failures, both interval rates and live-heap
stability. Compiler refusal of a natural storage form is a Whitefoot finding:
keep its diagnostic and minimal witness; do not silently change its spelling
to make this experiment green. CI acceptance, the oracle gate, measurements and
completion review with validation evidence remain unverified.
