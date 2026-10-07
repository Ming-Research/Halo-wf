-- checks: SELF names a missing or non-callable method; an invalid receiver is still an index operand.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function() local t = {}; return t:missing() end)
record(function() local t = {bad = false}; return t:bad() end)
record(function() local s = "text"; return s:missing() end)
record(function() local t; return t:missing() end)
return out
