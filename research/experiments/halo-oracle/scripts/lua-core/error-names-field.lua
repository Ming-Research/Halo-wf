-- checks: String constant fields retain their names; numeric and register keys use question mark.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
local t = {bad = false, [1] = false}
record(function() return t.bad.x end)
record(function() t.bad.x = 1 end)
record(function() return t.bad() end)
record(function() return t.bad + 1 end)
record(function() return 1 + t.bad end)
record(function() return "2" + t.bad end)
record(function() return t.bad .. "a" end)
record(function() return "a" .. t.bad end)
record(function() return #t.bad end)
record(function() return -t.bad end)
record(function() return t[1].x end)
record(function() local key = "bad"; return t[key]() end)
record(function() return t[true] + 1 end)
record(function() local key = "bad"; return #t[key] end)
record(function() return t["zero\000suffix"].x end)
return out
