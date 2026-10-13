-- checks: yielding outside a coroutine raises an error caught by pcall.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local ok, err = pcall(coroutine.yield, "outside", nil, 7)
return {tostring(ok), type(err), err, tostring(coroutine.running() == nil)}
