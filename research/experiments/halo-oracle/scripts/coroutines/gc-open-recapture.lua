-- checks: a suspended owner's open-upvalue list retains a capture after its first closure dies, so a later closure can recapture and update the same local.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress this targets open-list and inactive-open-list omissions.
local owner = coroutine.create(function()
  local value = 37
  local discarded = function() return value end
  local first = discarded()
  discarded = nil
  coroutine.yield(first)
  local read = function() return value end
  local write = function(next_value) value = next_value end
  write(83)
  coroutine.yield(read(), value)
  write(97)
  return read(), value
end)
local ok1, first = coroutine.resume(owner)
local total = 0
for i = 1, 64 do
  local unrelated = i
  local get = function() return unrelated end
  total = total + get()
end
local ok2, captured2, direct2 = coroutine.resume(owner)
local ok3, captured3, direct3 = coroutine.resume(owner)
return {tostring(ok1), first, tostring(ok2), captured2, direct2, tostring(ok3), captured3, direct3, total, coroutine.status(owner)}
