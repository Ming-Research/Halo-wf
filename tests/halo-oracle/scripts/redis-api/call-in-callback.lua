-- checks: redis.call and redis.pcall return to Lua library callbacks: a sort comparator, a gsub replacement and a __tostring metamethod, and a pcall inside the comparator catches redis.call's error.
-- KEYS: ["halo-oracle:api"]
-- ARGV: []
-- expects: No pre-existing keys.
local t={3,1,2}
local errs,last=0,nil
table.sort(t,function(a,b)
  redis.call("RPUSH",KEYS[1],a)
  local ok,e=pcall(redis.call,"INCR",KEYS[1])
  if not ok then errs,last=errs+1,e end
  return a<b
end)
local s=string.gsub("ab","%w",function(c) return c..redis.call("RPUSH",KEYS[1],c) end)
local m=tostring(setmetatable({},{__tostring=function() return redis.call("LPOP",KEYS[1]) end}))
local p=redis.pcall("INCR",KEYS[1])
return {t[1],t[2],t[3],errs,last,s,m,p.err,redis.call("LRANGE",KEYS[1],0,-1)}
