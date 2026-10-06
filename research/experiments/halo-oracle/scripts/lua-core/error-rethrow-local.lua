-- checks: an error caught by pcall and raised again through a local alias of error is reported at the line of the rethrow.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local raise=error
local ok,e=pcall(function()
  local t=nil
  return t.x
end)
raise(e,0)
