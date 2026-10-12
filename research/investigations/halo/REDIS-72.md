# Moving the reference to Redis 7.2.16

Status: recorded on Redis 7.2.16; Halo's test host is being brought to the
recorded replies (see Result). Board item `firn-req-halo-oracle-72`, under
`halo-compat`.

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

This list is the record made before recording; Result says what the
recording corrected. Read from the Redis 7.0.15 and 7.2.16 sources before any recording; each
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

### What the recording found

- `oracle-reference.yml` compared every stored reply of the existing corpus
  with Redis 7.2.16 on the reference platform: all are byte-identical.
- The 13 new scripts named above were recorded twice with identical bytes,
  on runs 38230247230 and 38230496205.
- Editing the scripts' headers to state the recorded replies changed the
  SHA-1 of `error-message-newline` and `error-message-crlf`, which their error
  replies carry. Those two were recorded again on run 38231089356 and a
  second time, identically, on run 38231687691 (comparison exit 0).

### Predictions the recording corrected

Read from the scripts' `-- differs:` headers before and after recording.

- A5's control was wrong: `error-reply-newline` was planned to reply
  "a b" on both releases and replies "ERR a b" on 7.2.16. In 7.2.16
  `redis.error_reply` passes its text, with a leading `-` ensured, through
  `luaPushErrorBuff`, which takes the bytes before the first space as the
  error code and supplies `ERR` when there is none. "oracle helper error"
  keeps "oracle" as its code (`error-reply`), "a\nb" has no space and gains
  `ERR`.
- A1's INCR reply was wrong: `number-argument-effects` predicted 100000000000000001;
  the script sees 100000000000000000, because the integer reply becomes a
  Lua number (a double). GET still returns the stored 100000000000000001.
- Spellings left open were recorded. Number arguments: 1e-5 is 0.00001,
  1e-7 is 1e-7, 2^63 is 9223372036854776000, 1e19 is 1e+19, 1e100 is 1e+100,
  0/0 is -nan, 1/0 is inf. Double replies: 1e17 is 100000000000000000, 2^63
  is 9223372036854776000, 1e-7 is 1e-7, 0/0 is nan, 1/0 is inf. `set_repl`
  says "ERR redis.set_repl() requires one argument.". `bit.tohex` gives
  000000FF and DEADBEEF at the extreme counts.
- Assumptions confirmed: `setmetatable` on the string metatable is refused
  too, and the LF and CR LF of a runtime error message become spaces. New
  detail: the refused assignment's message carries the script location
  (`user_script:14:`), the refused `rawset` and `setmetatable` do not.

### Halo against the recording

Gate run 38231089333 (commit aa1657c, before the two re-recordings): 333 of
363 comparisons pass (121 scripts at budgets 1, 7 and 1000), the same with
the collector stress mode. Of the 13 new scripts, `unpack-overflow-range`,
`bit-tohex-extrema` and `removed-globals` pass. Ten fail at every budget in
both modes:

| Script | Cause | Disposition |
| --- | --- | --- |
| `error-message-newline`, `error-message-crlf` | The expected files at that commit held the SHA-1 of the scripts before their header edit; Halo's replies equal the re-recorded files byte for byte. | None needed. |
| `error-reply-newline` | The test host stored `error_reply`'s text unchanged instead of applying `luaPushErrorBuff`'s code rule. | This change. |
| `set-repl-no-argument` | The test host had no `redis.set_repl`. | This change. |
| `redis-version` | The test host had no `REDIS_VERSION` or `REDIS_VERSION_NUM`. | This change. |
| `number-argument-format`, `number-argument-effects`, `double-score-reply` | The test host had no ECHO, INCRBYFLOAT or ZRANGE; behind that, number text. | Commands: this change. Number text: the fpconv package (`halo-redis-double-text`). |
| `double-reply-table` | The test host did not convert a `{double=x}` table; behind that, number text. | Conversion: this change. Number text: the fpconv package (`halo-redis-double-text`). |
| `string-metatable-readonly` | The string metatable is not read-only, and the embedding interface gives the host no way to reach or mark it. | `halo-embed-protect`. |

"Number text" is the digits of a finite, non-integral number: Redis 7.2.16
writes the shortest digits that read back exactly, Whitefoot's standard
library cannot produce them yet, and the test host writes Lua's %.14g text
instead. The two agree for 0.1 and differ for 1/3. After this change the
test host follows Redis 7.2.16's other number rules (integers within
LLONG_MAX/2, nan, inf, zeros), so by reading:

- `number-argument-format` still differs in 5 of 16 items (1/3, 1e-5, 1e-7,
  2^63, 5e-324), all number text.
- `double-reply-table` still differs in 3 of 8 items (1/3, 2^63, 1e-7), all
  number text.
- `number-argument-effects` and `double-score-reply` are expected to pass,
  because their only fractional value is 0.1. They do not test the
  shortest-digit rule, and the first does not test INCRBYFLOAT's long double
  sum, which the host computes in double.
- `string-metatable-readonly` still fails until `halo-embed-protect`.

Number text, afterwards: Redis 7.2.16 writes these digits with fpconv's
Grisu2, which has no exact fallback, so A1 and A2's "shortest round-trip
digits" is not exact. On Whitefoot CI run 38236089638, 355 of 16,922 nonzero
values outside the integer rule that redis-server 7.2.16 wrote had other
digits than the exact shortest (1e23 is 99999999999999990000000), and every
one matched a reconstruction of `fpconv_dtoa`. The test host now writes
number text with the fpconv package (`lib/fpconv`, a port of `fpconv_dtoa`),
and the gate compares its texts with the measured table
([fpconv README](../../../lib/fpconv/README.md#oracle-table)). The four
scripts' replies with it are unverified until CI runs them.

The reference check group (`REFERENCE_LUA`, the number library and the
MessagePack package against Redis's bundled Lua) now builds 7.2.16's Lua;
neither behavior fix in the bundled Lua (B1, B2) is reachable from its tests,
which the oracle scripts `unpack-overflow-range` and `bit-tohex-extrema`
cover instead. The performance baseline still builds PUC Lua 5.1.5 from Redis
7.0.15 (`fetch-redis.sh <directory> 7.0.15`): moving it changes the numbers
every earlier comparison reports against, so a measurement of both bundled
Lua builds decides it (`halo-bench-baseline-72`).
