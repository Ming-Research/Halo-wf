-- checks: getfenv, setfenv and newproxy: whether reading each global succeeds, the error text if not, and rawget of the name in _G.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- differs: Redis 7.0.15 and 7.2.16 differ in the sandbox. The 7.2.16 reply is recorded in expected/ (oracle-reference run 38230247230); the 7.0.15 reply is from reading the source and unverified.
-- 7.0.15 lets scripts read all three: each pcall succeeds with type function, and rawget finds a function.
-- 7.2.16 removes them: each read raises "Script attempted to access nonexistent global variable" with the name, and rawget finds nil.
local reads = {
  function() return getfenv end,
  function() return setfenv end,
  function() return newproxy end,
}
local names = {"getfenv", "setfenv", "newproxy"}
local out = {}
for i = 1, #names do
  local ok, v = pcall(reads[i])
  out[#out + 1] = names[i]
  out[#out + 1] = tostring(ok)
  out[#out + 1] = ok and type(v) or v
  out[#out + 1] = type(rawget(_G, names[i]))
end
return out
