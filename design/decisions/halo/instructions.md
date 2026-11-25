# Instructions

What one of Halo's instructions is, and why reading its operands needs no run-time check.

### decision an-instruction-is-an-enum-cell
An instruction is one variant of a cell enum with its operands as fields, Lua's register-or-constant operands split into separate variants, and each compare or test fused with its jump.
- rejected: an agent proposed Lua 5.1's packed 32-bit instruction words; the owner rejected it, because they are decoded by shifts and masks on every access, while a cell's operand is one load and a fused branch costs one dispatch, and dispatch count dominates an interpreter's time.

### decision a-u8-operand-needs-no-comparison
A `u8` operand needs no run-time comparison: the stack keeps 256 slots above every frame's `base`, and each constant pool is padded with 256 nils past every prototype's `kbase`.
- rejected: an agent proposed comparing every operand index at run time; the owner rejected it, because the windows are facts the dispatch already carries.
