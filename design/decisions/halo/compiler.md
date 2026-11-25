# The compiler

How Halo turns a script's source into its instructions.

### decision the-compiler-is-a-one-pass-port
The compiler ports Lua 5.1's one pass: a lexer feeds a parser that emits code through expression descriptors, `freereg` and jump lists, with `lcode.c`'s folding and PUC's error texts.
- rejected: an agent proposed compiling through an abstract syntax tree; the owner rejected it, because register allocation and jump patching would then be a second design, while the port matches PUC's register and jump choices and its compile errors.
