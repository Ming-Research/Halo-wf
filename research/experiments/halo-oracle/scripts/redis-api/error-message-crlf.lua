-- checks: A runtime error whose message holds a carriage return and a newline, raised at the top level of the script, becomes one RESP error line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
-- differs: Redis 7.0.15 and 7.2.16 differ in how a script error message with a line break reaches the reply. Both replies below are from reading the source and unverified.
-- 7.0.15 sends the message unchanged through addReplyErrorSdsEx, so the CR LF ends the error line early and the rest of the message is read as the next reply (broken RESP framing; this runner cannot record it).
-- 7.2.16 is assumed to turn CR and LF into spaces: "ERR user_script:N: a  b script: ..." with two spaces.
error("a\r\nb")
