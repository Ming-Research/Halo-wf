-- checks: A returned {double=x} table becomes a RESP2 bulk string holding the host's text for the number.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 format double replies differently. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 formats a finite double with %.17g and sends inf and -inf as words: 0.1 is 0.10000000000000001, 1/3 is 0.33333333333333331, 1e17 is 1e+17, 2^63 is 9.2233720368547758e+18, 1e-7 is 9.9999999999999995e-08, 3 is 3, 0/0 is -nan on x86-64 glibc, 1/0 is inf.
-- 7.2.16 uses the shortest round-trip digits: 0.1 is 0.1, 1/3 is 0.3333333333333333, 1e17 is 100000000000000000, 2^63 is 9223372036854776000, 1e-7 is 1e-7, 0/0 is nan, 1/0 is inf and 3 is 3.
return {{double=0.1}, {double=1/3}, {double=1e17}, {double=2^63}, {double=1e-7}, {double=0/0}, {double=1/0}, {double=3}}
