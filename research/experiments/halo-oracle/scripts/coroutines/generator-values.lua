-- checks: create/resume/yield transfer multiple values both ways, retaining nil holes and trailing nils.
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
local thread = coroutine.create(function(...)
  local initial = pack(...)
  local sent = pack(coroutine.yield("ready", nil, initial[1], initial[2], initial[3], initial[4], initial[5]))
  local final = pack(coroutine.yield("received", nil, sent[1], sent[2], sent[3], sent[4], sent[5]))
  return "done", nil, final[1], final[2], final[3], final[4], nil
end)
return {
  pack(coroutine.resume(thread, "start", nil, 23, nil)),
  pack(coroutine.resume(thread, "left", nil, "right", nil)),
  pack(coroutine.resume(thread, 41, nil, 43)),
  coroutine.status(thread)
}
