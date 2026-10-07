-- checks: Nil and NaN store keys carry Lua instruction locations; rawset keeps bare errors.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() local t,k,v = {},nil,1; t[k] = v end)
record(function() local t,k,v = {},0/0,1; t[k] = v end)
record(function() local t = {}; t[nil] = 1 end)
record(function() local t,k,v = {inner = {}},nil,1; t.inner[k] = v end)
record(function() local t = {}; rawset(t, nil, 1) end)
record(function() local t = {}; rawset(t, 0/0, 1) end)
record(function() return {[0/0] = 1} end)
return out
