# Moving the reference to Redis 7.2.16

Status: question recorded before recording; nothing measured yet. Board
item `firn-req-halo-oracle-72`, under `halo-firn-redis72-needs`.

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
