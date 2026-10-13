-- checks: __concat handles table operands; tostring honors __tostring.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local calls = {}
local left, right
right = setmetatable({}, {__concat=function(a, b)
  local ticks = 0
  for i = 1, 9 do ticks = ticks + 1 end
  assert(ticks == 9)
  if a == right then
    assert(type(b) == "number" and b == 5)
    return "raw number"
  end
  assert(type(a) == "number" and a == 7 and b == right)
  calls[#calls + 1] = "right"
  return 12
end})
left = setmetatable({}, {__concat=function(a, b)
  assert(a == left)
  if b == right then return "left wins" end
  if b == "7" then return "empty suffix" end
  assert(b == "x12")
  calls[#calls + 1] = "left"
  return "done"
end})
assert("a" .. left .. "x" .. 7 .. right == "adone")
assert(#calls == 2 and calls[1] == "right" and calls[2] == "left")
assert(left .. right == "left wins")
assert(right .. 5 == "raw number")
assert(left .. 7 .. "" == "empty suffix")
local middle = setmetatable({}, {__concat=function(a, b)
  assert(b == "z")
  return right
end})
assert(left .. middle .. "z" == "left wins")
local blank = setmetatable({}, {__concat=function(a, b) return "" end})
assert("a" .. 7 .. blank .. "z" == "a7")
local ok, err = pcall(function()
  local bad = {}
  return bad .. "x" .. 7 .. "y"
end)
assert(not ok)
assert(string.find(err, "attempt to concatenate local 'bad' (a table value)", 1, true))
local mt={__tostring=function(t) return "T" .. t.n end,__concat=function(a,b) return tostring(a) .. ":" .. tostring(b) end}
local t=setmetatable({n=7},mt)
return {tostring(t),t .. "x","x" .. t}
