Decision: Halo keeps its own slab per object kind, each a `Box<Slots<Cell>>` with a free list, instead of `std::collections::slab`, because the standard slab reaches a payload through members returning `Result` with a window check on every access, acceptable for allocation but not inside a table read ([VM design, heap](../../research/investigations/halo/VM.md#2-heap)).

Decision: Every string is interned, as in Lua 5.1, so string equality is index equality, and the intern table holds its strings weakly, because table keys and comparisons are on the interpreter's hot paths and the reference interns every string the same way, instead of comparing bytes.

Decision: The collector is a stop-the-world mark and sweep that runs at the budget's safepoints, a loop back edge or a call, where every live value is in a stack slot or another root, and the byte limit applies to the logical live bytes that per-object accounting estimates after such a collection, not to temporary allocation inside library calls, slab and intern reserve or process memory, because collecting inside allocation would make every allocating helper keep its live values as arguments, instead of collecting at allocation.

Decision: The allocation threshold is max(64 KiB, live bytes times (pause - 100) percent), the 64 KiB floor also being a new engine's initial threshold, because on Firn's long-lived VM with about 10 KB live the 1 MiB floor made every collection free about 16,600 objects in a 4 ms pause that set the rate-limiter script's p99 at 50 connections (3.4 ms), while 64 KiB brought p99 to 0.83 ms, level with Redis, and left Halo's seven kernels within their noise bounds ([result](../../research/experiments/halo-bench/RESULTS.md#the-collection-floor-on-firns-long-lived-vm)), instead of a 1 MiB floor.

Rejected:
- A 1 MiB floor kept as the default with an embedding setting for hosts: rejected because a host with a small live heap would by default free a whole 1 MiB of garbage per pause, which took 4 ms on Firn's rate-limiter script, while PUC Lua has no floor.
- A 256 KiB floor: rejected because its p99 (1.5 ms) stays about twice Redis's.
- An embedding setting for the floor beside the 64 KiB default: rejected because no host needs another value yet, and the build adding the setting and its heap field ran string-key 1.8% slower than main, which the floor constant alone did not cause; the setting's own cost was not measured.

