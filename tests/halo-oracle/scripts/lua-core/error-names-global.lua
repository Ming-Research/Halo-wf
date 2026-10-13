-- checks: Existing globals supply global names without the nonexistent-global interception.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() return type.x end)
record(function() type.x = 1 end)
record(function() return _VERSION() end)
record(function() _VERSION(); return 1 end)
record(function() return _VERSION + 1 end)
record(function() return 1 + _VERSION end)
record(function() return "2" + _VERSION end)
record(function() return type .. "x" end)
record(function() return "x" .. type end)
record(function() return #type end)
record(function() return -type end)
return out
