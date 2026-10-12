-- checks: a yield can return through resume called from pcall, a sort comparator, __index or a gsub replacement in the resumer.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = tostring(select(i, ...)) end
  return out
end
local observations = {}
local function observe(name, invoke)
  local thread = coroutine.create(function()
    local a, b = coroutine.yield("from-coroutine", nil, 7)
    return "finished", a, b
  end)
  local calls, first = 0, {"resume-not-called"}
  local function resume()
    calls = calls + 1
    first = pack(coroutine.resume(thread))
  end
  local outer = invoke(resume)
  local paused = coroutine.status(thread)
  local last = pack(coroutine.resume(thread, "back", nil))
  observations[#observations + 1] = {name, calls, first, outer, paused, last, coroutine.status(thread)}
end
observe("pcall", function(resume)
  return pack(pcall(function()
    resume()
    return "pcall-return"
  end))
end)
observe("table.sort", function(resume)
  local values = {2, 1}
  table.sort(values, function(a, b)
    resume()
    return a < b
  end)
  return {values[1], values[2]}
end)
observe("__index", function(resume)
  local value = setmetatable({}, {__index = function()
    resume()
    return "index-return"
  end})
  return {value.missing}
end)
observe("string.gsub", function(resume)
  local result, count = string.gsub("a", "a", function()
    resume()
    return "replacement"
  end)
  return {result, count}
end)
return observations
