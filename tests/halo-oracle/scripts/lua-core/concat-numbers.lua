-- checks: Concatenation coerces numbers with Lua number formatting.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local empty = ""
local binary = "a\000b"
assert(empty .. empty .. empty == "")
assert(binary .. empty == binary)
assert(empty .. binary .. empty .. 42 .. empty == "a\000b42")
assert(42 .. empty == "42")
local numbers = {0, -0.0, 1/3, 1e-7, 1e20, math.huge, -math.huge, 0/0}
for _, n in ipairs(numbers) do
  local expected = tostring(n)
  assert("[" .. n .. "]" .. empty == "[" .. expected .. "]")
end
return {"value=" .. 42 .. ":" .. 1.25, 1 .. 2 .. "x", "third=" .. (1/3)}
