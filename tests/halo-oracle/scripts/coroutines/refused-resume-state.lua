-- checks: a resume refused with "C stack overflow" at the nested-resume limit leaves a never-started coroutine dead and a yielded coroutine suspended, and later resumes from the main chunk see those states.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys. Nested resumes descend as in nested-resume-depth; at the deepest level, where resuming a new child is refused, a fresh coroutine and one that has yielded once are each resumed and refused too.
local fresh = coroutine.create(function(...)
  return "fresh ran", ...
end)
local yielded = coroutine.create(function(...)
  local again = coroutine.yield("first", ...)
  return "yielded ran", again
end)
local first = {coroutine.resume(yielded, "start")}
local function descend(depth)
  local child = coroutine.create(descend)
  local ok, result = coroutine.resume(child, depth + 1)
  if ok then return result end
  local fresh_ok, fresh_err = coroutine.resume(fresh, "deep")
  local yielded_ok, yielded_err = coroutine.resume(yielded, "deep")
  return {depth, tostring(result), coroutine.status(child), tostring(fresh_ok), tostring(fresh_err), tostring(yielded_ok), tostring(yielded_err)}
end
local root = coroutine.create(descend)
local ok, deep = coroutine.resume(root, 1)
local out = {tostring(first[1]), tostring(first[2]), tostring(first[3]), tostring(ok)}
if type(deep) == "table" then
  for i = 1, #deep do out[#out + 1] = deep[i] end
else
  out[#out + 1] = tostring(deep)
end
out[#out + 1] = coroutine.status(fresh)
out[#out + 1] = coroutine.status(yielded)
local fresh_again = {coroutine.resume(fresh, "again")}
local yielded_again = {coroutine.resume(yielded, "again")}
out[#out + 1] = tostring(fresh_again[1])
out[#out + 1] = tostring(fresh_again[2])
out[#out + 1] = tostring(fresh_again[3])
out[#out + 1] = tostring(yielded_again[1])
out[#out + 1] = tostring(yielded_again[2])
out[#out + 1] = tostring(yielded_again[3])
out[#out + 1] = coroutine.status(fresh)
out[#out + 1] = coroutine.status(yielded)
return out
