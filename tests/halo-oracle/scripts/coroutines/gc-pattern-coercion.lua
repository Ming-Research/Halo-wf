-- checks: gsub keeps the strings it made from a numeric source and a numeric pattern while its replacement function resumes a child that allocates strings, and later matches and the unmatched tail still use them.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; the converted strings exist only in the parked substitution, so under collector stress this targets the saved pattern-source and pattern-pattern omissions.
local keep = {}
local function churn()
  local child = coroutine.create(function()
    for i = 1, 32 do keep[#keep + 1] = string.rep("z", i) end
  end)
  local ok, err = coroutine.resume(child)
  if not ok then error(err, 0) end
end
local function numeric_source()
  local seen = {}
  local result, count = string.gsub(31415926535, "%d%d", function(digits)
    seen[#seen + 1] = digits
    if #seen == 1 then churn() end
    return "<" .. #seen .. ">"
  end)
  return {result, count, table.concat(seen, ",")}
end
local function numeric_pattern()
  local seen = {}
  local result, count = string.gsub("1a5 1b5 1c5", 1.5, function(matched)
    seen[#seen + 1] = matched
    if #seen == 1 then churn() end
    return "<" .. #seen .. ">"
  end)
  return {result, count, table.concat(seen, ",")}
end
return {numeric_source(), numeric_pattern()}
