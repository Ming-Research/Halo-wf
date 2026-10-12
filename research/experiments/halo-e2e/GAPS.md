# Embedding boundaries exposed by the first comparison

These are integration gaps in the current Halo implementation, not Lua source
rejections or proposals to change the language. Reopen them before the firn
binding treats this experiment as full Redis compatibility.

## Collector roots

The VM collector's `mark_roots` scans the active constant pool, but has no
embedding root-list argument. Before each engine start/resume, the embedding
module rebuilds the unused tail of that pool from every cached script's original
constants and every host pin. The compiled constant ranges and indexes stay
unchanged. This makes host pins and inactive cached constants real roots without
adding globals that a Lua program could enumerate or changing VM files.

Pins are acquired/released while the engine is idle or suspended. A Host callback
receives the VM and stack, not the engine; it must keep values needed across
safepoints in the stack, globals or an already pinned container. Extending that
contract to pin/unpin *during* a running callback needs a VM-visible registry/root
list. VM.md section 2 specifies a registry, but the current VM exposes none.
Unpin removes the root at the next start/resume mirror refresh, not by collecting
immediately. Pin tokens are never reused; released slots remain nil until engine
destruction. Root mirroring consumes memory proportional to the cached constants
and pin token slots; this experiment does not measure that cost.

The probe forces collection to distinguish retention of a pin and an inactive
script's string from accidental survival, then forces another collection after
unpin to observe reclamation. Its result is reported with the experiment.

## Script identity and retained closures

ScriptIds pair a slot and a flush generation. Reset preserves the cache; flush
closes active upvalues, removes scripts and invalidates their IDs. Generation
exhaustion refuses subsequent compilation rather than reusing an identity.

VM `start` replaces its prototype and line metadata from one script. A closure
retained by the host or in a global table from one cached script cannot safely be
called by another script: prototype/code identities are script-relative. The
embedding currently follows that VM interface; it does not rebase/merge scripts.
A flush likewise cannot preserve callable closures of flushed scripts. Reopen
with a two-script witness retaining a closure across start, and assign script
ownership to closures or use one engine-wide code/prototype identity space before
supporting that use. Corpus cases run independent engines and do not verify it.

## Error locations and Stop

`format_error(engine, line)` locates the error as `chunk:LINE: msg` in the
chunk name the script was compiled under and preserves a location already
present in a string error. `error_value` keeps the original object. The caller
supplies a known source line; zero means unknown. The test host's Redis
formatter `format_redis_error(engine, source, line)` in
`test/redis-error.wf` composes the Redis 7 EVAL table/string distinction and
script-body SHA-1 suffix. It
uses an explicit caller-supplied line rather than treating a budget checkpoint
as a failure location, and writes the VM's message as raised, located or not.

Global read/write slow paths retain a continuation PC in `callback_plan`;
the test host uses its previous instruction's line. A missing global's host
callback adds Lua's prefix before raising, so a protected call sees it too.
A script assignment into a read-only table, of a global, a new key or a key
the table already holds, raises the located message, as the reference's
`luaV_settable` does through `luaG_runerror`, whether a `pcall` catches it or
not: the table-store instructions' direct path stores only into writable
tables and leaves a read-only one to the slow executor, which locates the
refusal. `rawset`, `setmetatable` and the table library raise it unlocated
even when a script line calls them directly, as the reference's `lua_rawset`,
`lua_rawseti` and `lua_setmetatable` do through `luaG_runerror` while the C
function is the current call: the VM marks such an error as raised by a
native function, and the library call's luaL_error location skips a marked
error. The formatter adds no prefix (`redis-api/readonly-library-tables`
under `pcall`, `redis-api/readonly-rawset-error` uncaught).

Ordinary redis.member calls in this experiment use the member lookup's line
from the continuation. A native Call/TailCall does not retain its PC in the
Host interface. A member saved in a local and invoked later, or a multiline
call whose lookup and call have different lines, therefore needs the VM to
export the actual failing PC; nested protected/callback errors also need
that information. Reopen with those witnesses before claiming general EVAL
location parity. The formatter can accept their correct line once exported.

The saved-member witness `local call=redis.call` on line 1, followed by
`local x=1` on line 2 and `return call("GET","key","extra")` on line 3,
currently reports `on @user_script:1` instead of the call's line 3.
These witnesses distinguish corpus parity from general failure-location parity;
they require failure kind/PC information from the VM, outside the permitted
file boundary of this change.
The existing corpus's direct command/global errors exercise known locations;
its pass count alone does not settle this boundary. Command errors caught by
`pcall` remain plain strings, matching Redis's replacement `pcall`, while
unhandled command errors reach the EVAL formatter as tables. General user
error tables still follow the VM's ordinary pcall behavior and are outside
this Redis-host conversion.

Ordinary host Stop returns the untouched call stack. VM `resume` uses a saved
budget checkpoint; the ordinary `HostOutcome::Stop` path in `calls.wf` does not
itself save a new checkpoint. Engine resume therefore refuses a HostStopped outcome instead of dispatching from
an unrelated checkpoint. The probe checks that refusal makes no further host call,
then resets the engine.
Reopen with a stop/resume witness before promising that continuation. The slice
protocol's stop-before-write/reset/restart is the currently useful protocol.

## Test host and conversion scope

The host uses separate tables for values, key types and expiry durations. It
supports GET, SET, INCR, INCRBYFLOAT, DEL, EXISTS, EXPIRE, PEXPIRE, TTL, HSET,
HGET, HGETALL, LPUSH, RPUSH, LPOP, LRANGE, ZADD, ZCARD, ZSCORE, ZRANGE (by rank,
optionally WITHSCORES), ZREMRANGEBYSCORE, ECHO and PING. The implemented forms
serve the corpus, not the full Redis command option grammar. Expiry uses a
fixed clock at zero: positive durations remain live; nonpositive ones delete
immediately. Reopen with clock-valued expiry fixtures before using this host
to test countdowns. Malformed score/expiry inputs are not verified.

A Lua number passed to redis.call, a double reply (ZSCORE, WITHSCORES scores,
a returned `{double=x}`) and INCRBYFLOAT's result follow Redis 7.2.16's rules
(double2ll's integer range, d2string's nan, infinities and zeros), except
for the digits of a finite non-integral value: Redis writes the shortest
digits that read back exactly, and this host writes Lua's %.14g text, which
agrees for values such as 0.1 and differs for values such as 1/3. Whitefoot's
standard library has no shortest round-trip conversion yet (board item
`wf-need-halo-oracle-72`). INCRBYFLOAT also adds in double where Redis adds in
long double and prints with `%.17Lf`, so sums that the two precisions round
differently still differ.

RESP2 conversion truncates representable numbers toward zero, maps true to one and false/nil
to nil bulk, recognizes err before ok fields, and traverses tables from index
one until the first actual nil. False is an array element that converts to nil;
it does not end traversal. Numeric replies outside the signed 64-bit domain,
including nonfinite values, currently use INT64_MIN; Redis's target-specific C
conversion for those inputs has not been established by this corpus run.
Status/error payloads replace CR/LF with spaces and
use Redis's C-string boundary; a returned error table's text first loses its
trailing CR/LF, as Redis 7.2.16's addReplyErrorFormatEx trims it. A `{double=x}`
table, checked after err and ok, becomes a bulk string. A defensive reply nesting limit of 128 is a test
host limitation, not Lua acceptance. Cyclic/deep replies are not corpus cases.

`new_engine` installs the VM's slice-1 library. Redis call/pcall, status/error
reply, log, sha1hex, set_repl with its REPL_* flags, REDIS_VERSION and
REDIS_VERSION_NUM (7.2.16) are supplied by this host; set_repl checks its
arguments as Redis 7.2.16 does and otherwise has no effect, since the host does
not replicate; sha1hex uses the embedding's
Whitefoot digest implementation.

After the preparation chunk the host protects the script environment as
Redis 7.2.16's `scriptingInit` does, through the embedding's `set_metatable`,
`metatable_of`, `table_next` and `set_read_only`: the globals table gets an
`__index` that rejects undeclared names; then the globals table and every
table reachable from it through table values and metatables, such as the
`string`, `math` and `redis` tables and the rejecting metatable, become
read-only (`luaSetTableProtectionRecursively`); then so do the metatables of
the basic types, of which only strings have one, and what they reach
(`luaSetTableProtectionForBasicTypes`). The walk marks each table once.
KEYS and ARGV, which the preparation chunk has already set, are taken out of
the globals during the walk and put back after it, so they stay writable as
Redis's per-call KEYS and ARGV do (`luaCallFunction` installs them after
protection). `redis-api/readonly-library-tables` records the result.
