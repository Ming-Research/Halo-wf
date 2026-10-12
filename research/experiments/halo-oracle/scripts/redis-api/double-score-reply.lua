-- checks: ZADD with a Lua number score and ZSCORE and ZRANGE WITHSCORES replies, which the host formats as double replies.
-- KEYS: ["halo-oracle:api:zset"]
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 format double replies differently. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 sends the score as 0.10000000000000001 (%.17g) in ZSCORE and in the WITHSCORES list.
-- 7.2.16 sends 0.1 (shortest round-trip digits).
local added = redis.call("ZADD", KEYS[1], 0.1, "m")
local score = redis.call("ZSCORE", KEYS[1], "m")
return {added, score, redis.call("ZRANGE", KEYS[1], 0, -1, "WITHSCORES")}
