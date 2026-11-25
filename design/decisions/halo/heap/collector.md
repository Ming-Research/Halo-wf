# The collector

When Halo's collector runs, what it counts toward the byte limit, how it finds every execution, and how hosts and checks drive and observe it.

### decision the-collector-runs-at-safepoints
The collector is a stop-the-world mark and sweep that runs at safepoints (a backward `Jmp`, a loop or a call) and at a run's start and exit, where every live value is in a stack slot or a root.
- rejected: an agent proposed collecting at allocation; the owner rejected it, because every allocating helper would then have to keep its live values as arguments.

### decision safepoints-test-the-triggers-inline
At loop and call safepoints, Halo reads the stress, nonzero-limit and allocation-threshold conditions directly, and calls the collector only when one of them holds.
- replaced: Calling the full collector helper at every safepoint was on main; the owner changed it, because testing the triggers inline made the unlimited loop 10.28% faster in same-source pairs, with the same collector observations (data: `research/experiments/halo-bench/RESULTS.md`).
- rejected: an agent proposed one counter for both allocation and scheduling; the owner rejected it, because it would couple the heap's state with the budget's.

### decision a-run-exit-collects-past-the-limit
While a coroutine is installed, the driver also collects at each exit from the dispatch loop when, after the coroutine's buffer charges are reconciled, the logical bytes exceed the limit.
- rejected: an agent proposed leaving an excess above the limit until the next safepoint; the owner rejected it, because an excess reached late in a run meets no safepoint before the run exits, and the next safepoint comes only if the host continues the run.

### decision execution-buffers-count-toward-the-limit
A thread cell's execution buffers count by capacity toward the logical bytes, the limit and the trigger; main's installed buffers are charged only while main waits in its cell.
- replaced: Leaving execution buffers outside the accounting was on main; the owner changed it, because a script could otherwise hold memory in coroutines that the host's limit never counts.
- rejected: an agent proposed also charging main's installed buffers; the owner rejected it, because that would change when every script collects, those without coroutines too.

### decision the-collection-floor-is-64-kib
The allocation threshold is max(64 KiB, live bytes times (pause - 100) percent), and 64 KiB is also a new engine's first threshold.
- replaced: A 1 MiB floor was on main; the owner changed it, because with about 10 KB live on Firn's VM each collection freed about 16,600 objects in a 4 ms pause that set the p99 at 3.4 ms, while 64 KiB brought it to 0.83 ms, as Redis (data: `research/experiments/halo-bench/RESULTS.md`).
- rejected: an agent proposed a 256 KiB floor; the owner rejected it, because its p99 of 1.5 ms stays about twice Redis's (data: `research/experiments/halo-bench/RESULTS.md`).
- rejected: an agent proposed keeping the 1 MiB default and letting a host set its own floor; the owner rejected it, because every other host would still pause about 4 ms by default, unlike PUC Lua, which has no floor.
- rejected: an agent proposed a floor setting in the embedding beside the 64 KiB default; the owner rejected it, because no host needs another value yet.

### decision the-collector-traces-every-execution-through-its-cell
The collector traces every execution through its thread cell: a collection parks the running execution's buffers in its cell, and the roots name the main and the current thread.
- replaced: Marking the running execution's stack, frames, open upvalues and library records as separate roots was on main; the owner changed it, because beside a marker for suspended coroutines each field would be marked in two routines, and one a routine left out would go unmarked in that state.

### decision the-collector-is-driven-only-through-the-embedding
A host or a probe forces or observes the collector only through the embedding: opt-in stress, a one-shot due trigger, the completed-collection count and the heap's logical bytes.
- replaced: The embedding probe writing the allocation trigger's two heap fields was on main; the owner changed it, because the probe would break on any change of the collector's storage, which no API contract covers.
- rejected: an agent proposed letting embedding clients read and write the collector's heap fields directly, without the stress and count functions; the owner rejected it, because each client would then depend on the collector's storage and interpret its lifecycle itself.

### decision the-embedding-reports-collections-and-takes-a-pause
The embedding reports the last collection's statistics by object kind and takes a Lua 5.1 pause, 200 percent by default and at least 100, applied after the next collection and kept across reset.
- replaced: Keeping Lua's fixed defaults, with no observation, was on main; the owner changed it, because a host running one long-lived VM must see what a pause costs and tune how often it comes, without reading heap fields.
- rejected: an agent proposed incremental collection, as Lua 5.1 and Redis do; the owner rejected it, because it needs write barriers on table and upvalue writes that slow the hot paths, and measuring what a pause is made of first was cheaper.
- rejected: an agent proposed leaving read-only tables, and what they reach, out of each mark and sweep; the owner rejected it, because it helps no host that marks nothing read-only, and measuring what a pause is made of first was cheaper.

### decision each-coroutine-collector-edge-has-a-missing-edge-control
Each collector edge coroutines add has a missing-edge control, a copy of the source without that line, which under collector stress must change a recorded coroutine reply, crash, or stop at setup.
- rejected: an agent proposed first building a complete reachability verifier; the owner rejected it, because it is much more work and coroutines would wait for it, while a control for each new edge already gives that edge a check that can fail.

### decision an-edge-no-reply-shows-is-checked-by-its-probe
An edge whose control changes no reply gets a script that shows it, loses a duplicate holder that hides it, or is deleted if it marks nothing; otherwise its isolated probe checks it.
- rejected: an agent proposed accepting isolated probes for all nine edges whose controls changed no reply; the owner rejected it, because three of them could get replies recorded on Redis, and dead code and duplicate holders would stay in the collector.
- rejected: an agent proposed deleting as redundant every such edge that no script can show; the owner rejected it, because their redundancy rests on conventions across modules, such as copying the whole stack at a pause, which no check would then guard.
