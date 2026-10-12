-- checks: wrap transfers yield/resume and return values, and raises coroutine errors through the wrapped function.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do
    local value = select(i, ...)
    out[i + 1] = type(value) .. ":" .. tostring(value)
  end
  return out
end
local wrapped = coroutine.wrap(function(...)
  local initial = pack(...)
  local sent = pack(coroutine.yield("wrapped", nil, initial[1], initial[2], initial[3]))
  return "returned", nil, sent[1], sent[2], sent[3], nil
end)
local failing = coroutine.wrap(function()
  coroutine.yield("before-error")
  error("wrapped-boom")
end)
return {
  pack(wrapped(11, nil)),
  pack(wrapped("back", nil)),
  pack(pcall(wrapped)),
  pack(failing()),
  pack(pcall(failing)),
  pack(pcall(failing))
}
