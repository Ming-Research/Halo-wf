-- checks: Symbolic walks cross forward tests and jumps and skip closure capture cells.
-- KEYS: []
-- ARGV: []
-- expects: Array of pcall messages; no pre-existing keys.
local out = {}
local function record(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
record(function()
  local flag = true
  return ({bad = false}).bad + (flag and 1 or 2)
end)
record(function()
  local flag = false
  return ({bad = false}).bad + (flag and 1 or 2)
end)
record(function()
  local flag = true
  return (flag and false or {}) + 1
end)
record(function()
  local x = false
  local function capture() return x end
  return x()
end)
record(function()
  local x = false
  for i = 1, 2 do local unused = i end
  return x.a
end)
record(function()
  local x = false
  for k, v in pairs({1}) do local unused = v end
  return x.a
end)
record(function()
  local t = {bad = false}
  return t.bad + (1 < 2 and 1 or 2)
end)
record(function()
  local t = {bad = false}
  return t.bad + (1 <= 2 and 1 or 2)
end)
record(function()
  local t = {bad = false}
  return t.bad + (1 == 2 and 1 or 2)
end)
local captured = false
record(function()
  return type + function() return captured end
end)
return out
