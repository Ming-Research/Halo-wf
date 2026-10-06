-- checks: an error raised inside a sort comparator is reported at the comparator's line, not the sort call's.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local t={3,1,2}
table.sort(t,function(a,b)
  local x=nil
  return x.y
end)
return t
