# Coroutines

How a coroutine keeps its execution, how a switch runs, and what happens to coroutines when the engine starts again.

### decision a-coroutine-swaps-its-execution-into-the-loop
Each coroutine owns its stack, frames, open upvalues and library records in a thread cell, and `resume` and `yield` swap them into the one dispatch loop, using no machine stack.
- rejected: an agent proposed running each resume as a nested activation of the interpreter, as PUC's `lua_resume` does; the owner rejected it, because every resume would take one of the 200 native levels and machine stack of unmeasured size, and every yield would copy the whole value stack.

### decision a-start-ends-every-coroutine-of-the-last-run
Starting or resetting the engine ends every coroutine of the previous run and frees its buffers; a thread value still reachable stays a dead cell until ordinary collection.
- rejected: an agent proposed keeping a reachable coroutine resumable across runs; the owner rejected it, because its saved frames and program counters refer to the script of the run that made it, which the next start may replace with another.

### decision the-stack-swap-restates-the-length-the-checker-loses
The code restates stack lengths the Whitefoot checker loses through `swap`: a `resize_stack` to the same length after the collector unparks, and index tests that never fail after a switch.
- rejected: an agent proposed merging coroutines only once Whitefoot keeps a box's length through `swap`; the owner rejected it, because Firn's coroutine scripts would wait on that for an unknown time, and made this an exception to the rule against working around a Whitefoot gap.
