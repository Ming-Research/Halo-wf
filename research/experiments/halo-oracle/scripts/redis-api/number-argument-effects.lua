-- checks: A Lua number argument stored by SET is parsed back by INCR, and INCRBYFLOAT reads a fractional number argument.
-- KEYS: ["halo-oracle:api:num", "halo-oracle:api:float"]
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 format number arguments differently. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 stores 1e17 as the text 1e+17, so INCR fails with an integer-range error; INCRBYFLOAT of a missing key by 0.1 receives 0.10000000000000001 and stores that text.
-- 7.2.16 stores 1e17 as 100000000000000000, so INCR succeeds and stores 100000000000000001, but the script sees its reply as 100000000000000000, because 100000000000000001 is not a Lua number (double); INCRBYFLOAT receives 0.1 and stores 0.1.
local set = redis.call("SET", KEYS[1], 1e17)
local ok, incr = pcall(function() return redis.call("INCR", KEYS[1]) end)
local stored = redis.call("GET", KEYS[1])
local float = redis.call("INCRBYFLOAT", KEYS[2], 0.1)
return {set, tostring(ok), type(incr), incr, stored, float, redis.call("GET", KEYS[2])}
