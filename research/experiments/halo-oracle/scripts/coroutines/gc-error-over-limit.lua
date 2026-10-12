-- checks: an error raised inside a coroutine stays alive through the collection that runs while the dying coroutine is still installed above the host's heap limit, until resume returns it.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys. The main chunk holds a 40 MiB string and the coroutine drops a 30 MiB string just before its arithmetic error, with no safepoint between them, so a host with a 64 MiB heap limit collects before resume returns, when the dying coroutine's error value has no other holder; this targets the error omission at every budget, ordinarily and under collector stress.
local big = string.rep("a", 40 * 1048576)
local co = coroutine.create(function()
  local n = #string.rep("b", 30 * 1048576)
  return n + nil
end)
local ok, err = coroutine.resume(co)
return {tostring(ok), err, #big}
