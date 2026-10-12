-- checks: a coroutine runs a long warmup and 4096 yields, so budgets 1, 7 and 1000 suspend execution inside its own stack.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local thread = coroutine.create(function()
  local warmup = 0
  for i = 1, 2048 do warmup = warmup + i end
  local total = 0
  for i = 1, 4096 do
    local sent = coroutine.yield(i)
    total = total + sent
  end
  return total, warmup
end)
local count, sum, sent = 0, 0, 0
local final, warmup
while coroutine.status(thread) ~= "dead" do
  local ok, value, second = coroutine.resume(thread, sent)
  if not ok then error(value, 0) end
  if coroutine.status(thread) == "dead" then
    final, warmup = value, second
  else
    count, sum, sent = count + 1, sum + value, value * 2
  end
end
return {count, sum, final, warmup, coroutine.status(thread)}
