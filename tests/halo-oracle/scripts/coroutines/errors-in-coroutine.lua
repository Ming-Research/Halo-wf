-- checks: resume and inner pcall preserve string locations, level-zero errors and table identity; Redis command failures and redis.pcall results remain observable inside coroutines.
-- KEYS: ["halo-oracle:coroutine-errors"]
-- ARGV: []
-- expects: A string key contains a value INCR cannot parse as an integer.
-- setup: ["SET", "halo-oracle:coroutine-errors", "not-an-integer"]
local function view(value)
  if type(value) == "table" then
    return {"table", type(value.err), tostring(value.err), type(value.tag), tostring(value.tag)}
  end
  return {type(value), tostring(value)}
end
local function pack(...)
  local out = {select("#", ...)}
  for i = 1, out[1] do out[i + 1] = view(select(i, ...)) end
  return out
end
local observations = {}
local function observe(name, body)
  local thread = coroutine.create(body)
  local result = pack(coroutine.resume(thread))
  observations[#observations + 1] = {name, result, coroutine.status(thread)}
end
observe("string-location-resume", function() error("coroutine-location") end)
observe("level-zero-resume", function() error("coroutine-no-location", 0) end)
local token = {tag = "identity-token"}
local failing = coroutine.create(function() error(token, 0) end)
local ok, err = coroutine.resume(failing)
observations[#observations + 1] = {"table-resume", tostring(ok), view(err), tostring(err == token), coroutine.status(failing)}
observe("string-location-pcall", function()
  return pcall(function() error("protected-coroutine-location") end)
end)
observe("level-zero-pcall", function()
  return pcall(function() error("protected-coroutine-no-location", 0) end)
end)
observe("table-pcall", function()
  local caught, value = pcall(function() error(token, 0) end)
  return caught, value, value == token
end)
observe("redis.call-resume", function() return redis.call("INCR", KEYS[1]) end)
observe("redis.call-pcall", function() return pcall(redis.call, "INCR", KEYS[1]) end)
observe("redis.pcall-error", function() return redis.pcall("INCR", KEYS[1]) end)
observe("redis.pcall-success", function() return redis.pcall("GET", KEYS[1]) end)
return observations
