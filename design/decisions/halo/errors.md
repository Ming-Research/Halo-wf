# Errors

What a Lua error message says and where it is located: the names of operands, the levels of `error`, and the location of library errors.

### decision error-levels-count-call-records
`error(message, level)` counts levels as Lua 5.1's `lua_getstack` does: a library function that calls Lua back and each call a tail call replaced count as one level with no location.
- rejected: an agent proposed pushing a frame record for every library callback; the owner rejected it, because it adds work to every comparator call only to serve the error path, while the callback record already marks each such boundary.
- replaced: A one-bit tail-call flag in the frame record was on main; the owner changed it, because one bit counts two tail calls in a row into one frame as one lost level, where PUC counts two.

### decision type-errors-name-their-operand-when-raised
A runtime type error names its operand as Lua 5.1's `getobjname` does, found only when the error is raised, by walking the faulting prototype's cells with `symbexec`'s rules.
- rejected: an agent proposed computing each description when the script is compiled; the owner rejected it, because the walk would repeat for each instruction that can fail, since the jump rule depends on the faulting position, and it stores text almost no run reads.

### decision the-name-walk-reads-halos-own-cells
The walk that names an operand reads Halo's own cells, a fused compare or test applying its absorbed jump and a closure skipping its capture cells.
- rejected: an agent proposed keeping a second copy of Lua's 32-bit instruction words for the error path; the owner rejected it, because the cells carry every operand the walk reads, and the cell map keeps the order that `symbexec`'s forward-jump rule compares.

### decision local-names-are-kept-outside-the-lua-heap
Each prototype's local-variable ranges, as `lparser.c` records them, and its upvalue names are kept in the script as bytes outside the Lua heap.
- rejected: an agent proposed keeping them as heap string handles; the owner rejected it, because they would add roots that the removed-root controls would also have to cover, while bytes leave the collector, its roots and its accounting as they are.

### decision only-lual-error-raises-take-the-callers-line
Only an error a native function raises as `luaL_error` takes its Lua caller's location; one raised the way Lua raises runtime errors, while the native function is current, stays bare.
- rejected: an agent proposed a separate unlocated variant of the raised outcome that native and host functions return; the owner rejected it, because that type is public and the variant would mean nothing to hosts, and the table library's success flags would need a third state.
