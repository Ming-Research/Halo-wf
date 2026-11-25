# The Lua library

Which parts of Lua 5.1's library Halo provides to scripts, and how `table.sort` runs.

### decision the-library-follows-what-redis-scripts-call
Halo provides the Lua 5.1 library of Redis 7.2.16's sandbox but `loadstring`, `load`, `collectgarbage`, `gcinfo`, weak tables, `string.dump`, `string.gfind`, `table.foreachi` and `table.setn`.
- rejected: an agent proposed the whole library of Redis's sandbox; the owner rejected it, because in 2,700 files of 2,168 repositories that call `redis.call`, scripts call `math.mod` and `table.foreach` and none the others (data: `research/investigations/halo/SCRIPTS.md`).

### decision halo-provides-coroutines
Halo provides Lua 5.1's coroutine library (`create`, `resume`, `yield`, `status`, `wrap` and `running`) with Redis 7.2.16's replies and error texts.
- replaced: Leaving out coroutines, which no surveyed script calls, was on main; the owner changed it, because they test what Whitefoot gives and lacks for stacks swapped through one interpreter and traced by the collector, and Firn wants them (data: `research/investigations/halo/COROUTINES.md`).

### decision the-default-sort-runs-synchronously
`table.sort` with no comparator, on a live writable table whose 1..n are all in the array part and all numbers or all strings, sorts in place by PUC's `auxsort`; others run the state machine.
- replaced: Running every sort as the resumable state machine was on main; the owner changed it, because the default comparison of such values calls no Lua and cannot suspend, and the machine's frames and result slots made sort 2.8 times slower (data: `research/experiments/halo-bench/RESULTS.md`).
