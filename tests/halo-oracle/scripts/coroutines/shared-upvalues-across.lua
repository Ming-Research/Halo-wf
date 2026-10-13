-- checks: closures made in one coroutine share reads and writes from another and the main script while their creating coroutine is suspended and after it is dead.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local read, write
local creator = coroutine.create(function()
  local value = 10
  read = function() return value end
  write = function(next_value)
    local previous = value
    value = next_value
    return previous, value
  end
  coroutine.yield("closures-ready")
  return value
end)
local observations = {}
local ok, label = coroutine.resume(creator)
observations[#observations + 1] = {tostring(ok), label, coroutine.status(creator), read()}
local old, changed = write(20)
observations[#observations + 1] = {"main-suspended", old, changed, read()}
local other = coroutine.create(function()
  local before = read()
  local previous, after = write(30)
  coroutine.yield(before, previous, after, read())
  local closed = read()
  local closed_previous, closed_after = write(50)
  return closed, closed_previous, closed_after, read()
end)
local second_ok, before, previous, after, seen = coroutine.resume(other)
observations[#observations + 1] = {"other-suspended", tostring(second_ok), before, previous, after, seen, coroutine.status(creator)}
local creator_ok, final = coroutine.resume(creator)
observations[#observations + 1] = {"creator-return", tostring(creator_ok), final, coroutine.status(creator), read()}
old, changed = write(40)
observations[#observations + 1] = {"main-dead", old, changed, read()}
local last_ok, closed, closed_previous, closed_after, closed_seen = coroutine.resume(other)
observations[#observations + 1] = {"other-dead", tostring(last_ok), closed, closed_previous, closed_after, closed_seen, coroutine.status(other), read()}
return observations
