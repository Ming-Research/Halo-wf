-- checks: create rejects a non-function and resume rejects a non-coroutine with their exact argument errors.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = tostring(select(i, ...)) end
  return out
end
return {pack(pcall(coroutine.create, 7)), pack(pcall(coroutine.resume, "not-a-thread"))}
