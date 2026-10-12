-- checks: Redis calls inside a coroutine write a declared list before and after yields and return to the correct execution stack.
-- KEYS: ["halo-oracle:coroutine-list"]
-- ARGV: []
-- expects: No pre-existing keys.
local thread = coroutine.create(function()
  local first = redis.call("RPUSH", KEYS[1], "first")
  local sent = coroutine.yield("after-first", first)
  local second = redis.call("RPUSH", KEYS[1], sent)
  local last = coroutine.yield("after-second", second)
  local third = redis.call("RPUSH", KEYS[1], last)
  return third, redis.call("LRANGE", KEYS[1], 0, -1)
end)
local first_ok, first_label, first_count = coroutine.resume(thread)
local before = redis.call("LRANGE", KEYS[1], 0, -1)
local second_ok, second_label, second_count = coroutine.resume(thread, "second")
local middle = redis.call("LRANGE", KEYS[1], 0, -1)
local last_ok, final_count, final_list = coroutine.resume(thread, "third")
return {
  {tostring(first_ok), first_label, first_count, before},
  {tostring(second_ok), second_label, second_count, middle},
  {tostring(last_ok), final_count, final_list, coroutine.status(thread)},
  redis.call("LRANGE", KEYS[1], 0, -1)
}
