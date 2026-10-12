-- checks: Whether a script can modify the string metatable: assignment, rawset and setmetatable(mt, nil), each under pcall, then whether the marker key survived.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 differ in the sandbox. Both replies below are from reading the source and unverified.
-- 7.0.15 allows all three writes: each pcall succeeds, the marker key is left set (value 1), and the script removes it afterwards so later scripts see an unchanged string metatable.
-- 7.2.16 (readonly string metatable, CVE-2025-46818) refuses each write with "Attempt to modify a readonly table" (assumed also for setmetatable, unverified), so the marker key is absent; type(mt.__index) is table in both.
local mt = getmetatable("")
local key = "halo_oracle_marker"
local function result(ok, v)
  if ok then return type(v) end
  return v
end
local ok1, e1 = pcall(function() mt[key] = 1 end)
local ok2, e2 = pcall(rawset, mt, key, 1)
local ok3, e3 = pcall(setmetatable, mt, nil)
local left = rawget(mt, key)
-- Remove the marker under pcall: on 7.2.16 this write is refused too.
pcall(rawset, mt, key, nil)
return {tostring(ok1), result(ok1, e1), tostring(ok2), result(ok2, e2), tostring(ok3), result(ok3, e3), tostring(left), type(mt.__index), tostring(mt.__index == string), tostring(rawget(mt, key))}
