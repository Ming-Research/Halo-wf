-- checks: pcall's post-catch err lookup honors __index, result types and arity, nested catches, sort callbacks, and host calls; lookup errors escape, and xpcall keeps its original error.
-- KEYS: ["pcall-field-key"]
-- ARGV: []
-- expects: No pre-existing keys; this script writes and deletes its declared key.
local out = {}
local lookups = 0
local function observe(label, original, ...)
  local row = {label, select('#', ...)}
  for i = 1, select('#', ...) do
    local value = select(i, ...)
    row[#row + 1] = type(value)
    row[#row + 1] = tostring(value)
    if type(value) == "table" then
      row[#row + 1] = tostring(value == original)
    end
  end
  out[#out + 1] = row
end
local function object(label, fields, index)
  return setmetatable(fields, {
    __tostring = function() return label end,
    __index = index
  })
end
local function indexed(label, fn)
  return object(label, {}, function(t, key)
    lookups = lookups + 1
    return fn(t, key)
  end)
end
local child = object("field-table", {})
local inherited = object("inherited", {err = "inherited-string"})
local middle = object("middle", {}, inherited)
local cases = {
  {"raw-string", object("raw-string-table", {err = "raw-string"}, function()
    error("raw hit must not invoke __index")
  end)},
  {"raw-number", object("raw-number-table", {err = 17})},
  {"missing", object("missing-table", {})},
  {"table", object("table-field-table", {err = child})},
  {"false", object("false-field-table", {err = false})},
  {"index-table", object("index-table-error", {}, inherited)},
  {"index-chain", object("index-chain-error", {}, middle)},
  {"index-string", indexed("index-string-table", function(t, key)
    return tostring(t) .. ":" .. key
  end)},
  {"index-number", indexed("index-number-table", function() return 23 end)},
  {"index-nil", indexed("index-nil-table", function() return nil end)},
  {"index-raises", indexed("index-raises-table", function()
    error("field lookup failed")
  end)},
  {"index-host", indexed("index-host-table", function()
    local value = redis.call("GET", KEYS[1])
    return "host:" .. tostring(value)
  end)}
}
for _, case in ipairs(cases) do
  local label, value = case[1], case[2]
  if label == "index-raises" then
    observe(label, value, pcall(function()
      pcall(error, value)
      return "lookup error was swallowed"
    end))
  else
    observe(label, value, pcall(error, value))
  end
  local before = lookups
  local handled = false
  observe("xpcall-" .. label, value, xpcall(function()
    error(value)
  end, function(e)
    handled = e == value
    return e
  end))
  out[#out + 1] = {"handler-original-" .. label, tostring(handled), lookups - before}
end
redis.call("SET", KEYS[1], "stored")
local host = cases[#cases][2]
observe("host-present", host, pcall(error, host))
local host_raw = indexed("host-raw-table", function()
  return redis.call("GET", KEYS[1])
end)
observe("host-raw-present", host_raw, pcall(error, host_raw))
redis.call("DEL", KEYS[1])
observe("host-raw-missing", host_raw, pcall(error, host_raw))
local nested = indexed("nested-table", function()
  local inner = indexed("inner-table", function() return "inner" end)
  observe("inside-index", inner, pcall(error, inner))
  return nil
end)
observe("nested", nested, pcall(error, nested))
observe("ephemeral", nil, pcall(function()
  error(indexed("ephemeral-table", function()
    pcall(error, "replace active error")
    local garbage = {}
    for i = 1, 20 do garbage[i] = {tostring(i)} end
    return nil
  end))
end))
local sorted = {3, 1, 2}
table.sort(sorted, function(a, b)
  local failure = indexed("comparator-table", function()
    local ok, value = pcall(function() return a < b end)
    redis.call("GET", KEYS[1])
    return tostring(ok) .. ":" .. tostring(value)
  end)
  local ok, result = pcall(error, failure)
  return result == "true:true"
end)
out[#out + 1] = {"sorted", table.concat(sorted, ",")}
local host_error = indexed("host-error-table", function()
  return redis.call("GET", KEYS[1], "extra")
end)
observe("host-raises", host_error, pcall(function()
  pcall(error, host_error)
  return "host error was swallowed"
end))
local cycle = object("cycle", {})
getmetatable(cycle).__index = cycle
observe("index-cycle", cycle, pcall(function() return pcall(error, cycle) end))
local invalid = object("invalid-index", {}, true)
observe("index-invalid", invalid, pcall(function() return pcall(error, invalid) end))
local native_index = object("native-index", {}, pcall)
observe("native-index", native_index, pcall(error, native_index))
local native_nested = setmetatable({}, {
  __index = pcall,
  __call = tostring,
  __tostring = function() error({err = "inner"}) end
})
local function observe_native(...)
  local ok, value, field = ...
  out[#out + 1] = {"native-nested", select('#', ...), type(ok), tostring(ok),
    type(value), tostring(value == native_nested), type(field), tostring(field)}
end
observe_native(pcall(error, native_nested))
observe("string-error", nil, pcall(error, "plain", 0))
observe("number-error", nil, pcall(error, 31))
observe("nil-error", nil, pcall(error, nil))
observe("false-error", nil, pcall(error, false))
observe("success", nil, pcall(function() return "ok", 42, nil end))
for _, level in ipairs({1, 2, 3, 0}) do
  local failure = object("level-error", {}, function()
    error("boom", level)
  end)
  local function run()
    local ok, value = pcall(error, failure)
    return ok, value
  end
  observe("index-error-level-" .. level, failure, pcall(run))
end
return out
