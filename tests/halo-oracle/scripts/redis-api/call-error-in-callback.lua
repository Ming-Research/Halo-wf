-- checks: redis.call's error inside a sort comparator ends the script with the error reply.
-- KEYS: ["halo-oracle:api"]
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
table.sort({2,1},function(a,b) return redis.call("GET",KEYS[1],"extra") end)
return "unreached"
