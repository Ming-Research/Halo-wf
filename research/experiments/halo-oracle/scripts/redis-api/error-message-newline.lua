-- checks: A runtime error whose message holds a newline, raised at the top level of the script, becomes one RESP error line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
-- differs: Redis 7.0.15 and 7.2.16 differ in how a script error message with a line break reaches the reply. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 sends the message unchanged through addReplyErrorSdsEx, so the error line holds a bare LF: "-ERR user_script:N: a<LF>b script: ..." (broken RESP framing; this runner's reader rejects a line without CR LF, so 7.0.15 cannot record it).
-- 7.2.16 turns the LF into a space: "ERR user_script:N: a b script: ...".
error("a\nb")
