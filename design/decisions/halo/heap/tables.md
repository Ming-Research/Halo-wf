# Tables

How a table's string reads run and how its array part grows.

### decision string-keys-take-a-specialised-lookup
A table read with a string key masks the string's cached hash by the power-of-two node count and compares interned handles along the chain, as PUC's `luaH_getstr` does.
- replaced: One generic lookup for every key was on main; the owner changed it, because its key classification, modulus and kind-matching equality made the string-key kernel 1.3 times slower on the 14900K (data: `research/experiments/halo-bench/RESULTS.md`).

### decision a-growing-array-grows-in-place
A table array that does not shrink grows in place, only after every step that can fail, so the table still changes only on success; a shrinking array is still replaced.
- replaced: Allocating a replacement array and copying the kept prefix was on main; the owner changed it, because once Whitefoot's `grow` reallocates, growing in place made integer-table 12.0% faster on the 14900K with no kernel slower (data: `research/experiments/halo-bench/RESULTS.md`).

### decision array-growth-initializes-only-the-added-suffix
Table growth counts array occupancy by powers of two and fills only the added part of the array with nil.
- replaced: Reinserting the whole array through general insertion, each index as a numeric key, was on main; the owner changed it, because six full-LTO pairs made integer-table 25.70% faster with the same replies, borders and iteration order (data: `research/experiments/halo-bench/RESULTS.md`).
