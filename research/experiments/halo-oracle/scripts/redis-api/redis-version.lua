-- checks: redis.REDIS_VERSION is a string and redis.REDIS_VERSION_NUM the same version packed as 0xMMmmpp.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: The host supplies the version, which changes with the reference. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15: "7.0.15" and 458767 (0x07000f).
-- 7.2.16: "7.2.16" and 459280 (0x070210).
return {redis.REDIS_VERSION, redis.REDIS_VERSION_NUM, type(redis.REDIS_VERSION), type(redis.REDIS_VERSION_NUM)}
