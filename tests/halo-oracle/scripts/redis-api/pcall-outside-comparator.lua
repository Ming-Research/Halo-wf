-- checks: a redis.call error raised in a sort comparator and caught by a pcall around the sort is the err string.
-- KEYS: ["halo-oracle:api"]
-- ARGV: []
-- expects: No pre-existing keys.
local ok,e=pcall(table.sort,{2,1},function(a,b) return redis.call("GET",KEYS[1],"extra") end)
return {type(e),e}
