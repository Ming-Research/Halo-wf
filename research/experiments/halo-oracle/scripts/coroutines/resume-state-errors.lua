-- checks: resume returns its exact errors for a running, normal or dead coroutine.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = tostring(select(i, ...)) end
  return out
end
local observations = {}
local parent, child
parent = coroutine.create(function()
  observations[#observations + 1] = {"running", coroutine.status(parent), pack(coroutine.resume(parent))}
  child = coroutine.create(function()
    observations[#observations + 1] = {"normal", coroutine.status(parent), pack(coroutine.resume(parent))}
    return "child-done"
  end)
  local child_result = pack(coroutine.resume(child))
  observations[#observations + 1] = {"child", child_result}
  return "parent-done"
end)
local parent_result = pack(coroutine.resume(parent))
observations[#observations + 1] = {"parent", parent_result}
observations[#observations + 1] = {"dead", coroutine.status(parent), pack(coroutine.resume(parent))}
return observations
