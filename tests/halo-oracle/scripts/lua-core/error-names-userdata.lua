-- checks: cjson.null uses the same operand descriptions with userdata as its Lua type.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() local x = cjson.null; return x.a end)
record(function() local x = cjson.null; x.a = 1 end)
record(function() local x = cjson.null; return x() end)
record(function() local x = cjson.null; return x + 1 end)
record(function() local x = cjson.null; return "2" + x end)
record(function() local x = cjson.null; return x .. "a" end)
record(function() local x = cjson.null; return "a" .. x end)
record(function() local x = cjson.null; return #x end)
record(function() return cjson.null() end)
return out
