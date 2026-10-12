-- checks: Control for the runtime-error cases: redis.error_reply with a newline in its text becomes one RESP error line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
-- differs: Control: the error_reply path was already sanitized in 7.0.15 and is expected not to differ. The reply below is from reading the source and unverified.
-- Both 7.0.15 and 7.2.16 send the error line "a b": addReplyErrorFormatEx maps CR and LF to spaces, and error_reply adds no ERR prefix.
return redis.error_reply("a\nb")
