# Dispatch

How the interpreter loop runs instructions: its form, where values live between instructions, when a run stops, and which cases each handler takes itself.

### decision the-interpreter-is-a-loop-match
The interpreter `run` is a plain `loop { match }` on the instruction at `pc`, whose `pc`, `base` and `kbase` carry the window facts every arm needs as invariants the checker proves.
- replaced: A guaranteed self-tail call `run` was on main; the owner changed it, because it worked around a checker gap that Whitefoot v0.101 closed, and the owner's intent is that `loop { match }` itself compiles to tail jumps.
- rejected: an agent proposed a `loop { match }` that re-checks the windows at run time before every dispatch; the owner rejected it, because it hides the checker gap behind run-time comparisons instead of closing it in Whitefoot.

### decision hot-arms-continue-the-loop-themselves
The measured hot instructions continue the dispatch loop from their own arms with the next `pc`, while frame-changing and callback paths go through the shared epilogue that checks the windows.
- replaced: Joining every handler's continuation in the shared epilogue was on main; the owner changed it, because same-source full-LTO pairs made the numeric loop 54.32% and fib 12.37% faster on an M1 Pro, at 1.147 times the check cost (data: `research/experiments/halo-bench/RESULTS.md`).

### decision stack-slots-are-authoritative
No Lua value lives only in a machine register across a dispatch: the stack slots are authoritative.
- rejected: an agent proposed caching values in machine registers; the owner rejected it, because the collector then finds every root in the stack, the frames and the other root sets, while a register cache would have to be written back before every safepoint.

### decision execution-is-budgeted-at-loops-and-calls
A budget counter decreases only at `ForLoop`, `TForLoop`, a backward `Jmp`, `Call` and `TailCall`, and at zero the run saves its position and returns `Budget`.
- rejected: an agent proposed testing a counter or a clock at every instruction; the owner rejected it, because loops and calls already bound every path between those points, and the host needs only to stop a script between slices and restart it.

### decision handlers-take-only-the-common-case
Each instruction handler takes only the common case and leaves the rest to one shared slow executor, which does coercion, metamethods, hash misses, `__index` chains and the read-only refusal.
- rejected: an agent proposed complete semantics in each handler; the owner rejected it, because in Lua the slow path usually succeeds, and one executor keeps rare cases out of every handler.

### decision concatenation-joins-each-run-once
Concatenation's handler joins each run of adjacent string or number operands into one buffer, converting numbers as `luaV_concat` does, and interns the result once.
- replaced: Sending every pair, and its number conversion, to the slow executor was on main; the owner changed it, because that allocated and interned every intermediate string and made the concat kernel 27% slower on the 14900K (data: `research/experiments/halo-bench/RESULTS.md`).

### decision the-fast-store-inserts-into-plain-tables
The `SetTableRR` and `SetTableKR` arms insert a missing key, not nil or NaN, themselves when the table is live, has no metatable and is not read-only; other stores go to the slow executor.
- replaced: Sending every missing key to the slow executor as a hash miss was on main; the owner changed it, because that repeated the lookup and validation and made the integer-table kernel 1.16 times slower on the 14900K (data: `research/experiments/halo-bench/RESULTS.md`).
