-- checks: Argument errors derive names from CALL, TAILCALL and TFORLOOP and adjust method self; argument and plain library errors locate only immediate Lua callers.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() select(0) end)
record(function() local f = bit.tobit; f(false) end)
record(function() string.rep("x", {}) end)
record(function() math.mod(false, 1) end)
record(function() return ("x"):rep({}) end)
record(function() local t = {rep = string.rep}; return t:rep(1) end)
local captured = bit.tobit
record(function() captured(false) end)
record(function() local f = bit.tobit; return f(false) end)
local ok, message = pcall(string.rep)
out[#out + 1] = ok and "unexpected success" or tostring(message)
record(function() table.sort({false, true}, bit.tobit) end)
record(function() string.gsub("x", ".", string.rep) end)
record(function() for k in string.rep, 1 do end end)
record(function() local decode = cjson.decode; decode(false) end)
record(function() local f = select; f(0) end)
record(function() local f = type; f() end)
record(function() local f = rawget; f({}) end)
record(function() local f = rawset; f({}, "key") end)
record(function() local f = setmetatable; f({}, false) end)
record(function() local f = getmetatable; f() end)
record(function() local f = error; f("message", false) end)
record(function() local f = xpcall; f() end)
record(function() local t = {set = setmetatable}; t:set(false) end)
record(function() local f = cmsgpack.pack; f() end)
record(function() local t = setmetatable({}, {__add = bit.tobit}); return t + 1 end)
record(function() local t = setmetatable({}, {__call = bit.tobit}); return t() end)
record(function() for k in string.gsub, false do end end)
record(function() local f = struct.pack; f("?") end)
record(function() local f = string.format; f("%d", {}) end)
record(function() string.format("%111d", 1) end)
record(function() table.sort({"%111d", "%111d"}, string.format) end)
record(function() table.sort({1, 2}, function(a, b) return string.format("%111d", a) end) end)
return out
