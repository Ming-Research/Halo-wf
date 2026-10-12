-- checks: a child writes a main-chunk local through a closure while main is a normal resumer, then another child observes the same captured value.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local value = {amount = 13}
local function replace(amount)
  local previous = value.amount
  value = {amount = amount}
  return previous, value.amount
end
local child = coroutine.create(function()
  local before, after = replace(29)
  coroutine.yield(before, after)
  return replace(47)
end)
local ok1, before1, after1 = coroutine.resume(child)
local main1 = value.amount
local ok2, before2, after2 = coroutine.resume(child)
local other = coroutine.create(function() return replace(61) end)
local ok3, before3, after3 = coroutine.resume(other)
return {tostring(ok1), before1, after1, main1, tostring(ok2), before2, after2, tostring(ok3), before3, after3, value.amount}
