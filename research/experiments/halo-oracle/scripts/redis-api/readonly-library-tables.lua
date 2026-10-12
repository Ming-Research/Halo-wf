-- checks: Whether a script can write the library tables reachable from the globals (string, math, table, redis, _G) and an existing key of the string metatable, each under pcall: a new key, an existing key with a constant or a register key and value, rawset, and whether each refusal carries the script location.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local upper, pi, index = string.upper, math.pi, getmetatable("").__index
local function try(f, ...)
  local ok, e = pcall(f, ...)
  if ok then return "ok" end
  return tostring(e)
end
local out = {}
out[#out + 1] = try(function() string.halo_x = 1 end)
out[#out + 1] = try(function() string.upper = 1 end)
out[#out + 1] = try(function() math.pi = 1 end)
out[#out + 1] = try(function() table.halo_x = 1 end)
out[#out + 1] = try(function() redis.halo_x = 1 end)
out[#out + 1] = try(function() _G.halo_x = 1 end)
out[#out + 1] = try(rawset, string, "halo_x", 1)
out[#out + 1] = try(function() getmetatable("").__index = 1 end)
out[#out + 1] = try(function() local v = 1; string.upper = v end)
out[#out + 1] = try(function() local k, v = "upper", 1; string[k] = v end)
out[#out + 1] = type(string.upper) .. "," .. type(math.pi) .. "," .. type(getmetatable("").__index)
pcall(rawset, string, "upper", upper)
pcall(rawset, math, "pi", pi)
pcall(rawset, getmetatable(""), "__index", index)
pcall(rawset, string, "halo_x", nil)
return out
