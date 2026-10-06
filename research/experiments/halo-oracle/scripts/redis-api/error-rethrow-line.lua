-- checks: redis.call's error caught by xpcall and raised again with error(e,0) is reported at the line of the rethrow.
-- KEYS: ["halo-oracle:api"]
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local _,e=xpcall(function()
  return redis.call("GET",KEYS[1],"extra")
end,function(e) return e end)
error(e,0)
