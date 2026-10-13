-- checks: status reports suspended, running, normal and dead; running is nil outside and identifies the current coroutine inside.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local outside = coroutine.running()
local observations = {tostring(outside == nil), type(outside)}
local parent, child
parent = coroutine.create(function()
  observations[#observations + 1] = {coroutine.status(parent), type(coroutine.running()), tostring(coroutine.running() == parent)}
  child = coroutine.create(function()
    return coroutine.status(parent), coroutine.status(child), tostring(coroutine.running() == child)
  end)
  local ok, normal, running, same = coroutine.resume(child)
  observations[#observations + 1] = {tostring(ok), normal, running, same, coroutine.status(child)}
  coroutine.yield("paused")
  return "finished"
end)
observations[#observations + 1] = coroutine.status(parent)
local first, value = coroutine.resume(parent)
observations[#observations + 1] = {tostring(first), value, coroutine.status(parent)}
local last, result = coroutine.resume(parent)
observations[#observations + 1] = {tostring(last), result, coroutine.status(parent), tostring(coroutine.running() == nil)}
return observations
