# Calls

How Lua calls, library callbacks and returns run, and what they cost.

### decision lua-calls-use-no-machine-stack
Lua-to-Lua calls, `__call`, `pcall`, `error` and host calls use the VM's own value stack and frame records; Lua code a library calls back runs as a nested activation, refused past 200.
- rejected: an agent proposed recursing on the machine stack for every Lua call; the owner rejected it, because a script's call depth should cost no machine stack, and a script that reaches the callback limit must get Redis's "C stack overflow" error.

### decision a-return-tests-an-open-upvalue-bound
Each execution state keeps an exclusive upper bound on its open upvalues' stack positions, so a Lua return or tail call skips closing with one comparison when its frame base is at or above it.
- replaced: Inspecting the open-upvalue list on every return was on main; the owner changed it, because that takes checked cell loads even when nothing needs closing, and with the return reading only the fields it needs, fib ran 6.34% faster (data: `research/experiments/halo-bench/RESULTS.md`).
- rejected: an agent proposed a parallel buffer of open stack positions; the owner rejected it, because it must keep the list's order and length, which Whitefoot does not keep across a buffer swap, while one scalar bound needs no paired indexes.
- rejected: an agent proposed list entries of a stack position and a handle; the owner rejected it, because the test needs only a one-sided bound, and exact positions make each entry and each coroutine's buffer charge larger.
