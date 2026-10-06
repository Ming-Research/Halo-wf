-- checks: an error string.gsub raises after its replacement function returns, including when the budget suspended that function, is reported at the gsub call's line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local function replacement()
  for i=1,2 do end
  return {}
end
return string.gsub("x","x",replacement)
