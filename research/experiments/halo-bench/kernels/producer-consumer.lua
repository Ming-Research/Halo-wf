local N = 100000
local producer = coroutine.create(function()
  for i = 1, N do
    coroutine.yield(i)
  end
end)
local sum = 0
for i = 1, N do
  local ok, value = coroutine.resume(producer)
  if not ok then error(value) end
  sum = sum + value
end
local ok, value = coroutine.resume(producer)
assert(ok and value == nil and coroutine.status(producer) == "dead")
print(sum)
