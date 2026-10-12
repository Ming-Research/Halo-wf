-- checks: parked library calls keep a comparator that sort received from foreach after the comparator leaves by tail call, a foreach key evicted from its table, and a pcall error table whose err lookup replaced the current error, while children allocate.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress the calling thread is parked while each child collects, so this targets the saved library-comparator, library-key and library-error omissions. The foreach case continues from a key its callback evicted, so the reference raises its invalid-key error.
local keep = {}
local function churn_closures()
  local child = coroutine.create(function()
    for i = 1, 32 do keep[#keep + 1] = function() return false end end
  end)
  local ok, err = coroutine.resume(child)
  if not ok then error(err, 0) end
end
local function churn_tables()
  local child = coroutine.create(function()
    for i = 1, 32 do keep[#keep + 1] = {tag = "decoy"} end
  end)
  local ok, err = coroutine.resume(child)
  if not ok then error(err, 0) end
end
local function sorted_from_foreach()
  local log = {}
  local values = {3, 1, 2}
  local outer = {}
  local function compare(a, b)
    log[#log + 1] = a .. "<" .. b
    if #log == 1 then churn_closures() end
    return a < b
  end
  outer[values] = function(a, b)
    outer[values] = nil
    return compare(a, b)
  end
  table.foreach(outer, table.sort)
  return {table.concat(values, ","), table.concat(log, " ")}
end
local function keyed()
  local t = {}
  t[string.rep("k", 3)] = true
  return t
end
local function evicted_key()
  local t = keyed()
  local ok, message = pcall(table.foreach, t, function(key, value)
    t[key] = nil
    t[1] = 1
    key = nil
    churn_tables()
    t[string.rep("n", 3)] = value
  end)
  return {tostring(ok), tostring(message)}
end
local function replaced_error()
  local log = {}
  local lookup_meta = {}
  lookup_meta.__index = function(raised, key)
    log[#log + 1] = key .. ":" .. raised.tag
    raised = nil
    local caught, message = pcall(error, "replacement", 0)
    log[#log + 1] = tostring(caught) .. ":" .. message
    churn_tables()
    return nil
  end
  local carrier = setmetatable({}, {__index = function()
    error(setmetatable({tag = "original"}, lookup_meta), 0)
  end})
  local function read(value)
    return value.missing
  end
  local ok, err, field = pcall(read, carrier)
  return {tostring(ok), type(err), tostring(err.tag), tostring(field), table.concat(log, " ")}
end
return {sorted_from_foreach(), evicted_key(), replaced_error()}
