-- checks: Redis's pcall keeps an error table whose err field is neither a string nor a number, and returns nil and false errors unchanged.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local a,x=pcall(function() error({err=true},0) end)
local b,y=pcall(function() error({err={}},0) end)
local c,z=pcall(error,nil)
local d,w=pcall(error,false)
return {type(x),type(x.err),type(y),type(y.err),type(z),type(w),w==false}
