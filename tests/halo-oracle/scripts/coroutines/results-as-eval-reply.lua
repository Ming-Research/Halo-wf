-- checks: a coroutine's return table becomes the EVAL reply directly, including nested values and a status reply.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local thread = coroutine.create(function()
  return {"coroutine-reply", 17, {"nested", 23}, {ok = "OK"}}
end)
local ok, result = coroutine.resume(thread)
if not ok then error(result, 0) end
return result
