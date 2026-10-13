-- checks: Redis's pcall returns the err field of an error table, a numeric field as a number, and any other error value unchanged; xpcall's handler still sees the table.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local a,x=pcall(function() error({err="ERR x"},0) end)
local b,y=pcall(function() error({err=42},0) end)
local c,z=pcall(function() error({x=1},0) end)
local d,w=pcall(error,{err="ERR direct"})
local e,v=xpcall(function() error({err="ERR xp"},0) end,function(m) return type(m) end)
return {type(x),x,type(y),y,type(z),type(w),w,v}
