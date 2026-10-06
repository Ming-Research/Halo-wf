# Design tree change log

Newest first. One entry per approved change of the tree: a dated title,
`Nodes:` naming every node changed, `Owner-approved:` and `Summary:`; the
owner-wide instructions' *Log format* owns the form.

## 2026-10-06 Halo's engine tree, host calls, error lines and pcall's error field

Nodes: halo, halo/values, halo/heap, halo/heap/closures, halo/heap/collector-validation, halo/heap/tables, halo/heap/tables/growth, halo/calls, halo/instructions, halo/dispatch, halo/dispatch/continuations, halo/compiler, halo/embedding, halo/embedding/root-bridge

Owner-approved: 2026-10-06 in the Halo session: "57, 60, 75, 76, 77 all agreed" (Q57, Q60, Q75, Q76, Q77), then "all agreed" (Q61-Q74: the guidance change and the thirteen slice-1 nodes), with "fold them into one" (Q78) merging the four pull requests into this one.

Summary: The Halo engine's tree arrives with the engine's move from Whitefoot. Halo is a Lua 5.1 engine package that never names Redis: the host owns `redis.call`, the reply conversions, the `EVAL` error reply and the chunk name its errors are located in, and a Redis adapter module inside Halo is refused (Q60). Replies are judged on Redis 7.0.15 on x86-64 Linux with glibc. Values are 16-byte tagged enums; the heap is Halo's own slab with interned strings and a mark-sweep collector at safepoints, tables port `ltable.c` with single-pass growth, and a native closure names its builtin through an explicit callee kind (Q57). Calls use no machine stack, library callbacks nest to 200, instructions are enum cells, dispatch is a self-tail call whose measured hot arms tail-call directly, and the compiler is a one-pass port of PUC's. The embedding interface is one `Host<E>` whose functions may return, raise, stop or leave the call pending for the host to complete or fail at the call (Q75); the engine reports the line where the error that ended a run was raised (Q77) and lets the host name the field `pcall` unwraps from an error table (Q76); roots cross the embedding through a persistent bridge. Evidence is in `research/investigations/halo/VM.md`, `research/experiments/halo-oracle` and `research/experiments/halo-bench/RESULTS.md`.
