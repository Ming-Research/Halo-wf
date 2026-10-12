-- checks: unpack refuses ranges whose length does not fit in an int, with the "too many results to unpack" error.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 differ for the first three ranges. Both replies below are from reading the source and unverified.
-- 7.0.15 computes the result count in signed int arithmetic that overflows for (-1, 2147483647), (-2147483648, 2147483647) and (0, 2147483647), which is undefined behavior; no 7.0.15 reply to those three is a specification. (1, 2147483647) fits and fails the stack check with the same error.
-- 7.2.16 raises "too many results to unpack" for all four.
local function run(first, last)
  local ok, e = pcall(unpack, {}, first, last)
  return tostring(ok) .. ":" .. tostring(e)
end
return {run(-1, 2147483647), run(-2147483648, 2147483647), run(0, 2147483647), run(1, 2147483647)}
