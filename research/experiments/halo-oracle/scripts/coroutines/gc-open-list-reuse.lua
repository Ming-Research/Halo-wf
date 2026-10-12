-- checks: a suspended owner keeps an open capture whose only closure died; after resuming, its next capture and a block exit still close a live capture of a block local before the slot is reused.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress the owner is parked while main collects, so this targets the open-list and inactive-open-list omissions, whose freed capture handle the owner's next capture would reuse while its stale list entry stays first.
local function body()
  local low = "low"
  local keep_mid
  do
    local mid = "mid"
    keep_mid = function() return mid end
    local high = "high"
    local dropped = function() return high end
    dropped = nil
    coroutine.yield("parked")
    local keep_low = function() return low end
  end
  local overwrite = "overwrite"
  return keep_mid(), overwrite
end
local owner = coroutine.create(body)
local ok1, parked = coroutine.resume(owner)
local ok2, mid, overwrite = coroutine.resume(owner)
return {tostring(ok1), parked, tostring(ok2), mid, overwrite, coroutine.status(owner)}
