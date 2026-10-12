-- checks: an uncaught coroutine error returned by resume is propagated to the top-level EVAL error.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local thread = coroutine.create(function()
  error("uncaught-coroutine-error")
end)
local ok, err = coroutine.resume(thread)
if not ok then error(err, 0) end
return "unexpected-success"
