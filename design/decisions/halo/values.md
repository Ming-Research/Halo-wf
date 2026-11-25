# Values

What a Lua value is in Halo, and how it names the object it refers to.

### decision a-value-is-a-16-byte-tagged-enum
A Lua value is a 16-byte tagged enum: nil, a boolean, an `f64` number, a builtin ID, or a `u32` index into the slab of its kind (string, table, closure or thread).
- rejected: an agent proposed NaN boxing; the owner rejected it, because it would decode every tag by hand with `reinterpret`, outside the enum's own types that `match` lowering and the collector work on, while the enum moves the same 16 bytes as PUC's `TValue`.

### decision a-slab-index-carries-no-generation
A slab index carries no generation; each cell keeps a checked `live` flag instead.
- rejected: an agent proposed generational handles, as the E1 heap experiment used; the owner rejected it, because a precise collector never leaves an index to a freed cell reachable, and a generation adds a load and a compare to every table and string access.
