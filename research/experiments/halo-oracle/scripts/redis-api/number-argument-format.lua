-- checks: Lua numbers passed as redis.call arguments reach the command as the text the host formats; ECHO returns each argument unchanged.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 format number arguments differently. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 formats every number with %.17g: 0.1 is 0.10000000000000001, 1/3 is 0.33333333333333331, 1e17 is 1e+17, 2^63 is 9.2233720368547758e+18, negative zero is -0, 5e-324 is 4.9406564584124654e-324; the controls 3, 0.5 and 2^53 print as 3, 0.5 and 9007199254740992.
-- 7.2.16 prints an integral value inside the long long range as an integer (1e17 is 100000000000000000, negative zero is 0; the controls 3 and 2^53 are unchanged) and any other value with the shortest round-trip digits (0.1 is 0.1, 1/3 is 0.3333333333333333, 5e-324 is 5e-324). Also: 1e-5 is 0.00001, 1e-7 is 1e-7, 2^63 is 9223372036854776000, 1e19 is 1e+19, 1e100 is 1e+100, 0/0 is -nan and 1/0 is inf.
local z = 0
local values = {0.1, 1/3, 3.14, 1e-5, 1e-7, 1e17, 2^63, -z, 5e-324, 3, 0.5, 2^53, 1e19, 1e100, 0/0, 1/0}
local out = {}
for i = 1, #values do out[i] = redis.call("ECHO", values[i]) end
return out
