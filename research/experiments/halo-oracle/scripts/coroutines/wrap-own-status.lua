-- checks: a wrapped coroutine observes its own running status and identity across a yield, its child sees it normal, and the caller sees it suspended then dead.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local self
local wrapped = coroutine.wrap(function()
  self = coroutine.running()
  local child = coroutine.create(function()
    return coroutine.status(self), tostring(coroutine.running() ~= self)
  end)
  local ok, parent_status, different = coroutine.resume(child)
  coroutine.yield(coroutine.status(self), tostring(ok), parent_status, different)
  return coroutine.status(self), tostring(coroutine.running() == self)
end)
local running, ok, normal, different = wrapped()
local suspended = coroutine.status(self)
local last, same = wrapped()
return {running, ok, normal, different, suspended, last, same, coroutine.status(self), tostring(coroutine.running() == nil)}
