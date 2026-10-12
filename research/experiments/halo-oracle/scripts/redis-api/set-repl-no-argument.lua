-- checks: redis.set_repl called with no arguments raises an error; the text pcall returns.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 word this error differently. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 says "redis.set_repl() requires two arguments." (pcall returns the err field, which may carry an ERR prefix and a script location).
-- 7.2.16 corrects the wording: pcall returns "ERR redis.set_repl() requires one argument." (an ERR prefix, no script location).
local ok, e = pcall(redis.set_repl)
return {tostring(ok), type(e), type(e) == "string" and e or "not a string"}
