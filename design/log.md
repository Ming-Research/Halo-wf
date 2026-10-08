# Design tree change log

Newest first. One entry per approved change of the tree: a dated title,
`Nodes:` naming every node changed, `Owner-approved:` and `Summary:`; the
owner-wide instructions' *Log format* owns the form.

## 2026-10-08 Halo names argument errors from the call site

Nodes: halo/operand-names

Owner-approved: 2026-10-08 on the WF status board, item "argument errors name the called function as Redis does": approved, in the owner's words, "the decision added to the design tree's operand-names.md: argument errors are named from the call site, and names and locations share the rule that looks only at the immediate caller, instead of a fixed name per builtin".

Summary: A library function's argument error names the called function as Lua 5.1's `getfuncname` does, through the same `getobjname` walk at the caller's CALL, TAILCALL or TFORLOOP cell, with `luaL_argerror`'s method adjustment and its `?` fallback, and errors raised by a native function are located only at an immediate Lua caller, as `luaL_where(L, 1)` does. Fixed names per builtin differed from Redis 7.0.15 for local aliases, fields, methods and shared builtins such as `math.mod`, and native callbacks took the outer Lua line; the oracle case `lua-core/argument-error-names` records Redis's replies for 34 such calls and Halo matches them all.

## 2026-10-08 Halo keeps replacing table arrays: in-place growth through grow rejected

Nodes: halo/heap/tables/growth

Owner-approved: 2026-10-08 on the Halo-wf status board, item "table growth": approved, in the owner's words, "the Rejected item added to the design tree's heap/tables/growth.md (growing in place with Whitefoot's grow rejected, with its reasons)".

Summary: Table growth takes about 30% of the integer-table kernel's samples on the 14900K, but growing a nonshrinking array in place with Whitefoot's `grow`, after every failure point so the table still changes only on success, left the kernel's median unchanged (1.000 times main in six interleaved pairs). Whitefoot lowers `grow` as allocation, copy and free, so the change kept the work it targeted; the alternative is reconsidered when `grow` reallocates in place (`research/experiments/halo-bench/RESULTS.md`, "Growing the array in place: result").

## 2026-10-07 Halo reads string keys by cached hash and handle

Nodes: halo/heap/tables

Owner-approved: 2026-10-07 in the Halo session: "all agreed" (Q85 option A: a table read with a string key takes the lookup specialised for strings).

Summary: A table read with a string key masks the string's cached hash by the power-of-two node count and compares interned handles along the chain, as PUC's `luaH_getstr` does, keeping the generic lookup for every other key and for any node vector whose length is not a power of two, so its result equals the generic lookup's for every table. The generic lookup's key classification, modulus and kind-matching equality made the string-key kernel about 1.3 times slower; the specialised read takes 0.771 times its time at the final engine on the 14900K with no kernel slower beyond its bounds (`research/experiments/halo-bench/RESULTS.md`, "String-key lookup").

## 2026-10-07 Halo's library follows what real Redis scripts call

Nodes: halo

Owner-approved: 2026-10-07 in the Halo session: "all agreed" (Q89 option A: the library scope from the script survey).

Summary: Halo provides the Lua 5.1 library that Redis 7.0.15's sandbox exposes except coroutines, `loadstring` and `load`, `getfenv` and `setfenv`, `collectgarbage`, `gcinfo`, `newproxy` with `__gc`, weak tables, `string.dump`, `string.gfind`, `table.foreachi` and `table.setn`, and gains `math.mod` and `table.foreach`. A survey of 2,700 files in 2,168 repositories that GitHub's code search found calling `redis.call`, with its corpus and criterion fixed before any script was read, found scripts calling `math.mod` (Ohm's save script) and `table.foreach` (Discourse's presence scripts) and none calling the others (`research/investigations/halo/SCRIPTS.md`); an excluded function is reconsidered when a host reports a script that calls it.

## 2026-10-07 Halo's self-tail dispatch is provisional

Nodes: halo/dispatch, halo/dispatch/continuations

Owner-approved: 2026-10-07 in the Halo session: "all agreed" (Q87: withdraw the approval the 2026-10-06 batch gave the self-tail dispatch form, whose card did not say it replaced `loop { match }`), with the direction "when it is done, come back and update the code" (Q86: Halo's dispatch becomes `loop { match }` once Whitefoot accepts it).

Summary: The interpreter stays the guaranteed self-tail call `run` only until Whitefoot accepts the same interpreter as a plain `loop { match }`, the form an interpreter is to take with the compiler emitting its tail calls; the checker's loss of the window facts where the loop's arms join is Whitefoot's gap to close, and a loop that re-checks the windows at run time on every dispatch is refused, since it would hide that gap. The per-arm continuation decision is replaced with the dispatch. The self-tail form had been recorded as a design choice and approved in a batch whose one-line card did not show that it replaced the loop form or why.

## 2026-10-07 Halo's fast store inserts missing keys into plain tables

Nodes: halo/dispatch

Owner-approved: 2026-10-07 in the Halo session: "Q84 approved" (a table store's common case includes a missing key in a live table with no metatable that is not read-only).

Summary: The fast table store inserts a missing key itself through the table's own insertion path when the table is live, has no metatable and is not read-only and the key is neither nil nor NaN, leaving tables with a metatable, read-only tables, invalid tables and invalid keys to the slow executor; this narrows the rule that hash misses go to the slow executor. Sending every new key to the slow executor repeated its lookup and validation; the change makes the integer-table kernel 11.9% faster and binary-trees 9.2% faster on the 14900K with no kernel slower (`research/experiments/halo-bench/RESULTS.md`, "Table stores without the slow executor").

## 2026-10-07 Halo sorts plain arrays synchronously

Nodes: halo/calls

Owner-approved: 2026-10-07 in the Halo session: "Q83 A" (the synchronous default sort, option A).

Summary: `table.sort` without a comparator, over elements `1..n` that all lie in the array part and are all numbers or all strings, sorts them in place synchronously by the steps of PUC's `auxsort`, so the permutation and errors are PUC's, while a comparator or any other case keeps the resumable state machine whose comparisons can call back and be suspended. The default comparison of such values calls no Lua and cannot suspend; the state machine's frames and result slots had made the sort kernel 2.8 times slower, and a paired run now measures it at 0.75 times PUC's time (`research/experiments/halo-bench/RESULTS.md`, "Synchronous default sort").

## 2026-10-07 Halo's concatenation joins each run of operands once

Nodes: halo/dispatch

Owner-approved: 2026-10-07 in the Halo session: "81 82 agreed" (Q82: concatenation's common case is every run of adjacent string or number operands, joined and converted in its handler; Q81, the performance candidates' order, changes no node).

Summary: Concatenation's handler joins each run of adjacent string or number operands into one buffer, converting numbers in place, and interns the result once, as `luaV_concat` does, leaving `__concat` and errors to the slow executor; this narrows the rule that the slow executor performs coercion. Joining one pair at a time through the slow executor had allocated and interned every intermediate string, and the batch made the concat kernel 27% faster on the 14900K with no other kernel slower (`research/experiments/halo-bench/RESULTS.md`, "Batched concatenation").

## 2026-10-07 Halo's runtime type errors name their operand

Nodes: halo/operand-names

Owner-approved: 2026-10-07 in the Halo session: "Q80 agreed" (the operand-name design: descriptions found when the error is raised, by walking Halo's cells, with names kept as bytes outside the Lua heap).

Summary: A runtime type error names its operand as Lua 5.1's `getobjname` does (`local`, `global`, `field`, `upvalue`, `method`), so error replies match Redis 7.0.15's. The description is found only when the error is raised, by walking the faulting prototype's cells with `symbexec`'s rules, instead of precomputing one per faultable instruction at compile time; the walk reads Halo's own cells rather than a second copy of PUC's instruction words; and the compiler's local-variable ranges and upvalue names are kept per prototype as bytes outside the Lua heap, so the collector and its roots are unchanged. The oracle corpus gained nine scripts recorded from Redis, and the 14900K measurements of its cost are in `research/experiments/halo-bench/RESULTS.md` ("Operand descriptions' cost").

## 2026-10-06 Halo's engine tree, host calls, error lines and pcall's error field

Nodes: halo, halo/values, halo/heap, halo/heap/closures, halo/heap/collector-validation, halo/heap/tables, halo/heap/tables/growth, halo/calls, halo/instructions, halo/dispatch, halo/dispatch/continuations, halo/compiler, halo/embedding, halo/embedding/root-bridge

Owner-approved: 2026-10-06 in the Halo session: "57, 60, 75, 76, 77 all agreed" (Q57, Q60, Q75, Q76, Q77), then "all agreed" (Q61-Q74: the guidance change and the thirteen slice-1 nodes), with "fold them into one" (Q78) merging the four pull requests into this one.

Summary: The Halo engine's tree arrives with the engine's move from Whitefoot. Halo is a Lua 5.1 engine package that never names Redis: the host owns `redis.call`, the reply conversions, the `EVAL` error reply and the chunk name its errors are located in, and a Redis adapter module inside Halo is refused (Q60). Replies are judged on Redis 7.0.15 on x86-64 Linux with glibc. Values are 16-byte tagged enums; the heap is Halo's own slab with interned strings and a mark-sweep collector at safepoints, tables port `ltable.c` with single-pass growth, and a native closure names its builtin through an explicit callee kind (Q57). Calls use no machine stack, library callbacks nest to 200, instructions are enum cells, dispatch is a self-tail call whose measured hot arms tail-call directly, and the compiler is a one-pass port of PUC's. The embedding interface is one `Host<E>` whose functions may return, raise, stop or leave the call pending for the host to complete or fail at the call (Q75); the engine reports the line where the error that ended a run was raised (Q77) and lets the host name the field `pcall` unwraps from an error table (Q76); roots cross the embedding through a persistent bridge. Evidence is in `research/investigations/halo/VM.md`, `research/experiments/halo-oracle` and `research/experiments/halo-bench/RESULTS.md`.
