-- checks: resume records yield outcomes across five metamethods, a __call handler, pcall, xpcall, sort, gsub, foreach and generic-for inside the coroutine, without presuming refusal.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = tostring(select(i, ...)) end
  return out
end
local observations = {}
local function observe(name, operation)
  local thread = coroutine.create(operation)
  local trace = {name}
  repeat
    trace[#trace + 1] = pack(coroutine.resume(thread, "continued"))
    trace[#trace + 1] = coroutine.status(thread)
  until coroutine.status(thread) ~= "suspended"
  observations[#observations + 1] = trace
end
observe("__index", function()
  local value = setmetatable({}, {__index = function()
    coroutine.yield("yield:__index")
    return "index-value"
  end})
  return value.missing
end)
observe("__add", function()
  local meta = {__add = function()
    coroutine.yield("yield:__add")
    return 9
  end}
  return setmetatable({}, meta) + setmetatable({}, meta)
end)
observe("__lt", function()
  local meta = {__lt = function()
    coroutine.yield("yield:__lt")
    return true
  end}
  return setmetatable({}, meta) < setmetatable({}, meta)
end)
observe("__concat", function()
  local meta = {__concat = function()
    coroutine.yield("yield:__concat")
    return "concatenated"
  end}
  return setmetatable({}, meta) .. setmetatable({}, meta)
end)
observe("__tostring", function()
  return tostring(setmetatable({}, {__tostring = function()
    coroutine.yield("yield:__tostring")
    return "stringified"
  end}))
end)
observe("__call", function()
  local callable = setmetatable({}, {__call = function(self, argument)
    local resumed = coroutine.yield("yield:__call", argument)
    return "call-value", resumed
  end})
  return callable("call-argument")
end)
observe("pcall", function()
  return pcall(function()
    coroutine.yield("yield:pcall")
    return "pcall-complete"
  end)
end)
observe("xpcall", function()
  return xpcall(function()
    coroutine.yield("yield:xpcall")
    return "xpcall-complete"
  end, function(err) return err end)
end)
observe("table.sort", function()
  local values = {2, 1}
  table.sort(values, function(a, b)
    coroutine.yield("yield:sort")
    return a < b
  end)
  return table.concat(values, ",")
end)
observe("string.gsub", function()
  return string.gsub("a", "a", function()
    coroutine.yield("yield:gsub")
    return "replacement"
  end)
end)
observe("table.foreach", function()
  table.foreach({17}, function(key, value)
    coroutine.yield("yield:foreach", key, value)
  end)
  return "foreach-complete"
end)
observe("generic-for", function()
  local calls, result = 0, ""
  local function iterator()
    calls = calls + 1
    if calls == 1 then
      coroutine.yield("yield:iterator")
      return 1, "iterator-value"
    end
  end
  for key, value in iterator do result = key .. ":" .. value end
  return result, calls
end)
return observations
