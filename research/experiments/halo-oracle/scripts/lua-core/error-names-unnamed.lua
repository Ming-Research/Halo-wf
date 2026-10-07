-- checks: Call results, constructors, constants, tag-method chains and native calls have no operand name.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
local function value() return false end
record(function() return value().x end)
record(function() return value()() end)
record(function() return value() + 1 end)
record(function() return #value() end)
record(function() return ({})() end)
record(function() return {} + 1 end)
record(function() return {} .. "x" end)
record(function() return "x" .. {} end)
record(function() local a = 1; return "bad" + a end)
record(function() local a = "2"; return a + "bad" end)
record(function() return "bad" + "also bad" end)
record(function() local t = setmetatable({}, {__index = 1}); return t.x end)
record(function() local t = setmetatable({}, {__newindex = 1}); t.x = 1 end)
record(function() for k in nil do return k end end)
local ok, message = pcall(false)
out[#out + 1] = tostring(message)
record(function() local t = setmetatable({}, {__tostring = false}); return tostring(t) end)
local xok, xmessage = xpcall(false, function(e) return e end)
out[#out + 1] = tostring(xmessage)
record(function()
  local replacements = setmetatable({}, {__index = 1})
  return string.gsub("a", ".", replacements)
end)
record(function()
  local mt = {__lt = false}
  local a, b = setmetatable({}, mt), setmetatable({}, mt)
  table.sort({a, b})
end)
-- GETGLOBAL indexes the environment through a non-stack copy. The sandbox
-- intercepts this missing name with its own error, rather than a type error.
record(function() return error_names_missing_global end)
record(function() table.sort({false, true}) end)
record(function() table.sort({1, "x"}) end)
record(function() return string.gsub("a", ".", {a = {}}) end)
record(function()
  local replacements = setmetatable({}, {__index = function()
    for i = 1, 2 do end
    return value().x
  end})
  return string.gsub("a", ".", replacements)
end)
record(function()
  local mt = {}
  mt.__index = function()
    for i = 1, 2 do end
    mt.__index = 1
  end
  return string.gsub("aa", ".", setmetatable({}, mt))
end)
return out
