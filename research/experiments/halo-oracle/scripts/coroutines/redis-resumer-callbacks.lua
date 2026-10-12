-- checks: children resumed from sort and gsub callbacks perform successful Redis calls, catch redis.call failure, return redis.pcall failure and success, propagate an uncaught child command error, and yield back to the correct callback.
-- KEYS: ["halo-oracle:coroutine-callback-bad", "halo-oracle:coroutine-callback-list"]
-- ARGV: []
-- expects: The bad string key is not an integer and the list starts absent.
-- setup: ["SET", "halo-oracle:coroutine-callback-bad", "not-an-integer"]
local observations = {}
local function observe(mode)
  local thread = coroutine.create(function()
    local size = redis.call("RPUSH", KEYS[2], mode)
    local ok, err = pcall(redis.call, "INCR", KEYS[1])
    local failed = redis.pcall("INCR", KEYS[1])
    local value = redis.pcall("GET", KEYS[1])
    coroutine.yield(size, tostring(ok), type(err), err, type(failed), failed.err, value)
    return redis.call("LRANGE", KEYS[2], 0, -1)
  end)
  local result
  local function resume()
    local ok, size, caught, kind, err, failed_kind, failed, value = coroutine.resume(thread)
    local failing = coroutine.create(function() return redis.call("INCR", KEYS[1]) end)
    local failed_ok, failure = coroutine.resume(failing)
    result = {tostring(ok), size, caught, kind, err, failed_kind, failed, value, tostring(failed_ok), type(failure), failure.err}
  end
  local outer
  if mode == "sort" then
    local values = {2, 1}
    table.sort(values, function(a, b)
      resume()
      return a < b
    end)
    outer = values
  else
    local value, count = string.gsub("x", "x", function()
      resume()
      return "done"
    end)
    outer = {value, count}
  end
  local state = coroutine.status(thread)
  local ok, list = coroutine.resume(thread)
  observations[#observations + 1] = {mode, result, outer, state, tostring(ok), list, coroutine.status(thread)}
end
observe("sort")
observe("gsub")
return observations
