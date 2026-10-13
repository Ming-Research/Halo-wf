-- checks: Upvalue names and ordering survive two closure levels and every operand error family.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
local x, y = false, false
local function middle()
  return {
    function() return x.a end,
    function() x.a = 1 end,
    function() return x() end,
    function() return x + 1 end,
    function() return 1 + y end,
    function() return "2" + y end,
    function() return x .. "a" end,
    function() return "a" .. y end,
    function() return #x end,
    function() return -y end,
    function() local ignored = x; return y.a end
  }
end
for _, f in ipairs(middle()) do record(f) end
return out
