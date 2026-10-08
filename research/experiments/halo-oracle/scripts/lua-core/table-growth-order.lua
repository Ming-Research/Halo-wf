-- checks: pairs visits number and string keys in the reference's unsorted order, and # gives its border, after tables grow, migrate keys between hash and array, delete and regrow, and shrink.
-- KEYS: []
-- ARGV: []
-- expects: Array of key orders and borders; no pre-existing keys.
local out = {}
local function record(label, t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = tostring(k) end
  out[#out + 1] = label .. " #" .. #t .. ": " .. table.concat(keys, ",")
end
local a = {}
for i = 1, 40 do a[i] = i end
record("ascending", a)
local b = {}
for i = 40, 1, -1 do b[i] = i end
record("descending", b)
local c = {}
for i = 1, 30 do c[i * 3] = i end
for i = 1, 30 do c[i] = i end
record("sparse then dense", c)
local d = {}
for i = 1, 20 do d[i] = i; d["k" .. i] = i end
record("mixed", d)
local e = {}
for i = 1, 64 do e[i] = i end
for i = 1, 64, 2 do e[i] = nil end
for i = 65, 80 do e[i] = i end
record("holes then regrow", e)
local f = {}
for i = 1, 64 do f[i] = i end
for i = 1, 60 do f[i] = nil end
for i = 1, 8 do f["s" .. i] = i end
record("shrink", f)
local g = {}
g[1.5] = 1; g[-1] = 2; g[0] = 3
for i = 1, 17 do g[i] = i end
g[2 ^ 40] = 4
record("non-array numbers", g)
return out
