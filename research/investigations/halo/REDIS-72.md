# Moving the reference to Redis 7.2.16

Status: question recorded before recording; nothing measured yet. Board
item `firn-req-halo-oracle-72`, under `halo-compat`.

## Question

The owner moved Firn's reference from Redis 7.0.15 to Redis 7.2.16, the
latest 7.2 maintenance release, so Halo's oracle replies must come from
7.2.16. Which recorded replies does 7.2.16 change, and can Halo match each
one?

## Comparison

`oracle-reference.yml`, pointed at 7.2.16 built from its verified source
on the reference platform, first compares the stored 7.0.15 replies with
7.2.16 and then records every reply again. Two attempts must record the
same bytes before any reply is committed. Every script whose reply
changes is listed below with its cause, read from Redis's 7.0 to 7.2
changes and its bundled Lua's patches.

Known before recording: from 7.2.11, a script that writes the shared
string metatable fails with "Attempt to modify a readonly table"
(CVE-2025-46818; Firn measured the 7.0.15 behavior in its CI).

## Known differences

Read from the Redis 7.0.15 and 7.2.16 sources before any recording; each
expected reply is unverified until CI records it. Layers: the **API layer** is
Redis's sandbox and reply conversion, which the host supplies; the **bundled
Lua** is the interpreter and libraries Halo implements; **memory safety**
means 7.0.15 had undefined behavior, so it gives no reply to match.

- A1, API layer: a Lua number passed to `redis.call` is written as an integer
  or with the shortest round-trip digits, not with `%.17g`
  (`number-argument-format`, `number-argument-effects`).
- A2, API layer: `{double=x}` replies and sorted-set scores are written the
  same way (`double-reply-table`, `double-score-reply`).
- A3, API layer: `getfenv`, `setfenv` and `newproxy` are no longer visible to
  scripts (`removed-globals`).
- A4, API layer: the string metatable is read-only
  (`string-metatable-readonly`).
- A5, API layer: a script error message with a line break no longer breaks
  the error reply (`error-message-newline`, `error-message-crlf`; control
  `error-reply-newline`).
- A6, API layer: the error text of `redis.set_repl` called without arguments
  changed (`set-repl-no-argument`).
- A7, host side, no script: `redis.acl_check_cmd` now checks the command's
  arity ("Wrong number of args for redis.acl_check_cmd()"); the corpus
  runner sets up no ACL.
- A8, host side, no script: `BLPOP`, `BRPOP`, `BLMOVE`, `BRPOPLPUSH`,
  `BZPOPMIN`, `BZPOPMAX` and `WAIT` are allowed in scripts and do not block
  (7.0.15 refused them); the host's command table decides this, not Lua.
- A10, host side, no script: the error text of an ACL refusal inside a
  script, and commands run from scripts no longer counted individually in
  command statistics or the slow log.
- A9, API layer: `redis.REDIS_VERSION` and `redis.REDIS_VERSION_NUM` name
  7.2.16 (`redis-version`).
- B1, bundled Lua and memory safety: `unpack` with a range whose length
  overflows an int raises "too many results to unpack"; three of the four
  ranges were undefined behavior in 7.0.15 (`unpack-overflow-range`).
- B2, bundled Lua and memory safety: `bit.tohex` with a digit count of
  -2147483648 (or 2147483648, which wraps to it) is handled; 7.0.15 negated
  it with undefined behavior (`bit-tohex-extrema`).
- B3 to B7, memory safety only, no script observes them: the lexer's long
  bracket separator count widened to `size_t` (differs only past 2^31 `=`
  signs); the parser anchors the chunk name during parsing (a use-after-free
  under collection); `luaH_getnum`'s range check rewritten with the same
  results; `DumpString` loses an always-false test; cjson's string index
  widened to `size_t` (differs only past 2 GiB). The bundled Lua's number
  formatting, string library, `struct`, `cmsgpack` and cjson's number
  output are byte-identical between the two releases, as are its build
  flags.

## What would change the plan

- A changed reply that Halo can match only with behavior that differs
  between scripts or hosts goes to the owner before Halo changes.
- A change in the bundled Lua itself (not only Redis's sandbox or reply
  conversion) also moves the reference interpreter that the reference
  check group builds (`REFERENCE_LUA` in the Makefile) and the PUC 5.1.5
  baseline of the performance comparisons; that move is decided
  separately, with its own measurement.

## Result

Not yet recorded.
