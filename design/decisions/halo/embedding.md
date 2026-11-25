# The embedding

How a host drives Halo: the interface its functions use, how runs stop and resume, what errors it learns, how it protects tables, and how its roots reach the collector.

### decision a-host-extends-halo-through-one-interface
A host extends Halo through one `Host<E>` interface whose call gets the host's environment, the VM, the stack and its arguments' place, and returns, raises, stops the run or leaves the call pending.
- rejected: an agent proposed registering closures over host state inside the engine; the owner rejected it, because a host's functions need the host's own state, and a host must be able to stop a script at a clean point and restart it.

### decision a-budget-stop-resumes-and-a-host-stop-ends
A run that uses up its budget is suspended and resumes where it stopped, inside nested callbacks too, while a run a host function stops stays ended until the host resets or starts a script.
- rejected: an agent proposed a budget that ends the run; the owner rejected it, because the host's slice protocol either continues a budgeted run or abandons it and restarts the script.
- rejected: an agent proposed a stop the host could resume; the owner rejected it, because a host treats a stop from its own function, such as an undeclared key, as the end of that attempt.

### decision a-host-call-may-stay-pending
A host function may leave its call pending: the run suspends at the call, the host reads the arguments, then completes the call with results or fails it with an error an enclosing `pcall` catches.
- rejected: an agent proposed passing the host's references as parameters through `start`, `resume` and `run` to each host call; the owner rejected it, because `run` already carries eight values from arm to arm, the arm64 argument-register count, and a ninth made a measured dispatch 8% slower.
- rejected: an agent proposed running a script's commands outside the host's `atomic` statement, with only owned data in the environment; the owner rejected it, because the commands would then no longer run atomically, as Redis scripts require.

### decision the-error-line-is-recorded-at-the-raise
The engine reports the source line where the error that ended a run was raised, recorded at the raise, kept while it leaves callbacks, and dropped when `pcall` or `xpcall` catches it.
- rejected: an agent proposed a host message handler run at each raise; the owner rejected it, because it would run host code in the middle of unwinding.

### decision pcall-looks-up-a-named-field-through-index
An embedding may name a field that `pcall` looks up in a caught table through the full get with `__index`, run as a resumable continuation after the protected frame is removed.
- rejected: an agent proposed moving `pcall` onto `xpcall`'s callback path; the owner rejected it, because every protected call would then be a nested activation, against decision lua-calls-use-no-machine-stack, even when no lookup after the catch calls Lua.
- rejected: an agent proposed following only `__index` tables, without calling an `__index` function; the owner rejected it, because that leaves a known difference from Redis that shows nothing at run time.

### decision hosts-protect-tables-through-three-functions
The embedding gives a host three general functions: set or clear a table's metatable, read a value's metatable, and mark a table read-only for good; host writes still reach such a table.
- rejected: an agent proposed one embedding function that applies Redis's protection to the globals and the string metatable; the owner rejected it, because it puts Redis's sandbox rules into Halo, and it would change whenever Redis changes the protected set, as 7.2.16 did.
- replaced: Letting hosts write a table's metatable and read-only fields directly was on main; the owner changed it, because every host would then depend on Halo's table layout, which no interface contract covers.
- rejected: an agent proposed a function that lifts the read-only mark, called around a host's own writes as Redis 7.2.16 does; the owner rejected it, because host writes already reach a read-only table, so the pair adds two calls to each `EVAL`, and a host missing the second leaves it writable.

### decision embedding-roots-cross-through-a-persistent-bridge
Each cached script keeps its embedding root bridge in its constant-pool tail; compile, pin and unpin invalidate every bridge, and a rebuild reads only original constants and current pins.
- replaced: Copying the embedding's roots again on every resume was on main; the owner changed it, because a persistent bridge cut the budgeted loop's time by 55.39% in same-source pairs, with the same replies, collections and root controls (data: `research/experiments/halo-bench/RESULTS.md`).
- rejected: an agent proposed a separate root registry passed to the collector as its own argument; the owner rejected it, because it would change the collector's boundary without improving what the experiment had to show.
