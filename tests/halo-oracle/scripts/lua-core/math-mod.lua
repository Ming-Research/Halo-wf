-- checks: math.mod is math.fmod, as Redis's Lua defines LUA_COMPAT_MOD: the same function value, its results, and the parity test Ohm's save script makes.
-- KEYS: []
-- ARGV: []
-- expects: Array of observations; no pre-existing keys.
local out = {}
out[#out + 1] = tostring(rawequal(math.mod, math.fmod))
out[#out + 1] = tostring(math.mod(7, 3))
out[#out + 1] = tostring(math.mod(-7, 3))
out[#out + 1] = tostring(math.mod(7, -3))
out[#out + 1] = tostring(math.mod(5.5, 2))
local attrs = {"name", "x", "count"}
out[#out + 1] = tostring(math.mod(#attrs, 2) == 1)
return out
