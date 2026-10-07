-- checks: Active local names, MOVE recursion, operand selection, and local scope boundaries.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() local t; return t.x end)
record(function() local t; t.x = 1 end)
record(function() local f = false; return f() end)
record(function() local f = false; f(); return 1 end)
record(function() local a, b = false, {}; return a + b end)
record(function() local a, b = 2, false; return a + b end)
record(function() local a, b = "2", false; return a + b end)
record(function() local a = false; return -a end)
record(function() local a = false; return #a end)
record(function() local a = false; return a .. "x" end)
record(function() local a = false; return "x" .. a end)
record(function() local a = false; return "x" .. 2 .. a end)
record(function(a) return a.x end)
record(function() do local old = 1 end; local current; return current.x end)
record(function() local function f() return f end; f = false; return f() end)
record(function(...) local a; return a.x end)
return out
