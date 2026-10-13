-- checks: table.foreach whose function removes the key being visited and then adds new keys until the table rehashes meets an invalid key when it resumes its traversal; the error is raised inside foreach, after the function returned, and carries no script location; the function ran once; next given the same removed key raises the same bare error.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function try(f)
  local ok, e = pcall(f)
  if ok then return "ok" end
  return tostring(e)
end
local function grow(t)
  for i = 1, 100 do t["x" .. i] = i end
end
local calls = 0
local t = {a = 1}
local out = {}
out[#out + 1] = try(function()
  table.foreach(t, function(k)
    calls = calls + 1
    t[k] = nil
    grow(t)
  end)
end)
out[#out + 1] = calls
local u = {a = 1}
local k = next(u)
u[k] = nil
grow(u)
out[#out + 1] = try(function() next(u, k) end)
return out
