-- checks: an escaped capture outlives its unreachable suspended owner, retaining its table and accepting writes after allocation pressure and later thread-slot reuse.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress this targets captured-value and owner-close omissions.
local read, write
local owner = coroutine.create(function()
  local held = {amount = 31, label = string.rep("held", 3)}
  read = function() return held.amount, held.label end
  write = function(amount) held = {amount = amount, label = "replacement"} end
  coroutine.yield("escaped")
  return held.amount
end)
local ok, label = coroutine.resume(owner)
owner = nil
local checksum = 0
for i = 1, 96 do
  local temporary = {amount = i, label = string.rep("x", i % 7 + 1)}
  checksum = checksum + temporary.amount
end
local before, before_label = read()
write(73)
for i = 1, 32 do
  local replacement = coroutine.create(function() local unrelated = {amount = 900 + i}; return unrelated.amount end)
  local ran, result = coroutine.resume(replacement)
  if not ran then error(result, 0) end
  checksum = checksum + result
end
local after, after_label = read()
return {tostring(ok), label, before, before_label, after, after_label, checksum}
