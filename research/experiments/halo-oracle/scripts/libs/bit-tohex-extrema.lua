-- checks: bit.tohex with a digit count at the signed 32-bit extremes.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 differ for a digit count of -2147483648. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 negates the count in signed int arithmetic, which overflows (undefined behavior, memory unsafe); no 7.0.15 reply is a specification. The count 2147483648 wraps to -2147483648 in the same way.
-- 7.2.16 handles the count safely: bit.tohex(255, -2147483648) and bit.tohex(255, 2147483648) return 000000FF, and bit.tohex(0xDEADBEEF, -2147483648) returns DEADBEEF.
local function hex(...)
  local ok, s = pcall(bit.tohex, ...)
  if ok then return s end
  return "error: " .. tostring(s)
end
return {hex(255, -2147483648), hex(255, 2147483648), hex(0xDEADBEEF, -2147483648)}
