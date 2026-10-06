-- checks: an error raised inside a sort comparator is reported at the comparator's line, not the sort call's.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local raise=error
local t={3,1,2}
table.sort(t,function(a,b)
  raise("comparator")
end)
return t
