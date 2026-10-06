-- checks: an ordinary call reaches each kind of callee as Lua specifies: a native function, a native iterator, a number and nil (both errors), and a vararg Lua function.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function invoke(f, a, b)
  local result = f(a, b)
  return result
end
local native = invoke(math.abs, -17, 99)
local iterator = string.gmatch("abc", "%a")
local sentinel = invoke(iterator)
local ok, err = pcall(function()
  local result = invoke(7, 1, 2)
  return result
end)
local nilok, nilerr = pcall(function()
  local result = invoke(nil, 1, 2)
  return result
end)
local function vararg(a, ...)
  return a + select("#", ...)
end
local variable = invoke(vararg, 20, 30)
return {native, sentinel, ok and 1 or 0,
  string.find(err, "attempt to call a number value", 1, true) and 1 or 0,
  nilok and 1 or 0,
  string.find(nilerr, "attempt to call a nil value", 1, true) and 1 or 0,
  variable}
