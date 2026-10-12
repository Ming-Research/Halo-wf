-- checks: tail calls to yield and resume preserve nil holes, trailing nils and success flags through both the suspension and completion paths.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = type(select(i, ...)) .. ":" .. tostring(select(i, ...)) end
  return out
end
local tail_yield = coroutine.create(function(...)
  return coroutine.yield(...)
end)
local tail_resume = coroutine.create(function(...)
  return coroutine.resume(tail_yield, ...)
end)
local first = pack(coroutine.resume(tail_resume, "outgoing", nil, 7, nil))
local states = {coroutine.status(tail_resume), coroutine.status(tail_yield)}
local second = pack(coroutine.resume(tail_yield, "incoming", nil, 9, nil))
local leaf = coroutine.create(function(...) return ... end)
local relay = coroutine.create(function(...) return coroutine.resume(leaf, ...) end)
return {first, states, second, pack(coroutine.resume(relay, "leaf", nil, 11, nil)), coroutine.status(leaf), coroutine.status(relay), coroutine.status(tail_yield)}
