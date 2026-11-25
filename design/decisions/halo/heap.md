# The heap

Where Halo keeps its objects and its strings.

### decision each-object-kind-has-its-own-slab
Halo keeps its own slab for each object kind, each a `Box<Slots<Cell>>` with a free list.
- rejected: an agent proposed the standard library's `std::collections::slab`; the owner rejected it, because it reaches a payload through members that return `Result` with a window check on every access, which is acceptable for allocation but not inside a table read.

### decision every-string-is-interned
Every string is interned, as in Lua 5.1, so string equality is index equality, and the intern table holds its strings weakly.
- rejected: an agent proposed comparing strings by their bytes; the owner rejected it, because table keys and comparisons are on the interpreter's hot paths, and the reference interns every string the same way.
