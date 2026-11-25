# Halo

Halo as a whole: a Lua 5.1 engine written in Whitefoot, what it leaves to its hosts, and what its replies and its speed are judged against.

### decision halo-is-a-lua-engine-in-whitefoot
Halo is a Lua 5.1 engine written in Whitefoot, its own package in `lib/halo` with an embedding interface, which Firn binds to run Redis scripts.
- rejected: an agent proposed embedding a native Lua engine in Firn through a host binding; the owner rejected it, because an engine written in Whitefoot keeps the script runtime under the language's guarantees.

### decision halo-never-names-redis
Halo's code holds no rule of Redis: the host supplies `redis.call`, `KEYS`, `ARGV`, the reply conversions, the `EVAL` error reply, the script cache and the chunk name errors are located in.
- rejected: an agent proposed an interpreter specialized to Redis; the owner rejected it, because the engine and the codecs Redis scripts use are to stand as projects of their own, apart from Firn.
- rejected: an agent proposed a Redis adapter module in Halo's package, holding the `EVAL` error reply; the owner rejected it, because it puts Redis's reply format back into the engine and ties the engine to Firn's protocol, while the host can build that reply from the error value and line.

### decision replies-are-judged-against-redis-7-2-16
Halo's replies are judged against the Lua 5.1 that Redis 7.2.16 bundles, built on x86-64 Linux with glibc.
- replaced: Judging replies against Redis 7.0.15 was on main; the owner changed it, because the owner moved Firn's reference to 7.2.16, the latest 7.2 release: 7.2 is what Redis and Valkey share, it still gets security fixes, and it differs little from 7.0.
- replaced: Recording the reference's replies on a macOS arm64 build was on main; the owner changed it, because Redis's replies differ by platform where C leaves the result to the hardware and C library, and x86-64 Linux with glibc is Firn's reference platform.

### decision speed-is-measured-against-redis-7-2-16s-lua
Halo's speed is measured against PUC Lua 5.1.5 as Redis 7.2.16 bundles and builds it, and a report on sort also lists the time of Redis 7.0.15's build.
- replaced: Measuring against Redis 7.0.15's build was on main; the owner changed it, because one Lua for the reference and the yardstick spares every report a second build, and sort, 2.4% slower on 7.2.16's, stays shown against 7.0.15's (data: `research/experiments/halo-bench/RESULTS.md`).
