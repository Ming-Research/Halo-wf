-- checks: A library's own error after a callback returns keeps the script location although the callback caught a read-only refusal raised inside rawset: table.sort's order error, string.gsub's replacement error, and a __tostring result reaching gsub, each beside a control without the caught refusal; next's invalid key error carries no location; the caught refusal itself carries none.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function try(f)
  local ok, e = pcall(f)
  if ok then return "ok" end
  return tostring(e)
end
local function refuse() return pcall(rawset, string, "halo_x", 1) end
local caught = setmetatable({}, {__tostring = function() refuse() return {} end})
local plain = setmetatable({}, {__tostring = function() return {} end})
local out = {}
out[#out + 1] = try(function() table.sort({1, 2, 3, 4}, function(a, b) refuse() return true end) end)
out[#out + 1] = try(function() table.sort({1, 2, 3, 4}, function(a, b) return true end) end)
out[#out + 1] = try(function() string.gsub("abc", "%w", function(c) refuse() return {} end) end)
out[#out + 1] = try(function() string.gsub("abc", "%w", function(c) return {} end) end)
out[#out + 1] = try(function() string.gsub("a", "a", function() local s = tostring(caught) return s end) end)
out[#out + 1] = try(function() string.gsub("a", "a", function() local s = tostring(plain) return s end) end)
out[#out + 1] = try(function() next({halo = 1}, "halo_missing") end)
out[#out + 1] = select(2, refuse())
out[#out + 1] = type(rawget(string, "halo_x"))
return out
