-- checks: Control for the runtime-error cases: redis.error_reply with a newline in its text becomes one RESP error line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
-- differs: Planned as a control expected not to differ; the recording makes it a difference candidate. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.2.16 sends the error line "ERR a b": the line break becomes a space and the line gains an ERR prefix, which error_reply without a line break does not get on either release (error-reply). 7.0.15 is read from the source as sending "a b" (addReplyErrorFormatEx maps CR and LF to spaces; no ERR prefix), unverified.
return redis.error_reply("a\nb")
