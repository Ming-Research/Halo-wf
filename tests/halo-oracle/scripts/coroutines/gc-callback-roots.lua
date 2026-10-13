-- checks: nested resumes park foreach, sort, gsub and xpcall state while a child allocates, and callbacks finish using their saved tables, keys, strings, closures and errors.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress this exercises library, sort, pattern, error and stopped execution edges without assuming each is an independent root.
local function work()
  local child = coroutine.create(function()
    local total = 0
    for i = 1, 24 do local temporary = {i}; total = total + temporary[1] end
    coroutine.yield(total)
    return total + 1
  end)
  local ok1, first = coroutine.resume(child)
  local ok2, last = coroutine.resume(child)
  if not ok1 then error(first, 0) end
  if not ok2 then error(last, 0) end
  return first + last
end
local outer = coroutine.create(function()
  local key = string.rep("key", 5)
  local entries = {[key] = 43}
  key = nil
  local foreach_total = 0
  table.foreach(entries, function(current, value)
    entries[current] = nil
    current = nil
    foreach_total = foreach_total + value + work()
  end)
  local values = {}
  for i = 1, 9 do values[i] = {rank = 10 - i, text = string.rep("v", i)} end
  table.sort(values, function(a, b)
    work()
    return a.rank < b.rank
  end)
  local sorted = {}
  for i = 1, #values do sorted[i] = values[i].rank .. ":" .. #values[i].text end
  local source = string.rep("abc", 3)
  local pattern = "(" .. string.rep(".", 3) .. ")"
  local replaced, count = string.gsub(source, pattern, function(part)
    work()
    return "[" .. part .. "]"
  end)
  local ok, err = xpcall(function()
    error({tag = string.rep("saved-error", 2)}, 0)
  end, function(held)
    work()
    return held
  end)
  return {foreach_total, table.concat(sorted, ","), replaced, count, tostring(ok), type(err), err.tag}
end)
local ok, result = coroutine.resume(outer)
if not ok then error(result, 0) end
return result
