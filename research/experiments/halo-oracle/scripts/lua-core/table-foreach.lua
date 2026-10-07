-- checks: table.foreach calls its function with each key and value in next order, returns the first non-nil result, lets the function assign existing fields and call Redis, and rejects a non-table or non-function argument.
-- KEYS: ["halo-oracle:foreach:1", "halo-oracle:foreach:2"]
-- ARGV: []
-- expects: Array of observations; no pre-existing keys.
local out = {}
local log = {}
local none = table.foreach({10, 20, 30}, function(k, v) log[#log + 1] = k .. "=" .. v end)
out[#out + 1] = table.concat(log, ",")
out[#out + 1] = tostring(none)
log = {}
table.foreach({alpha = 1, beta = 2, gamma = 3, [4] = "four"}, function(k, v)
  log[#log + 1] = tostring(k) .. "=" .. tostring(v)
end)
out[#out + 1] = table.concat(log, ",")
out[#out + 1] = tostring(table.foreach({5, 6, 7}, function(k, v) if v == 6 then return k * 100 end end))
out[#out + 1] = tostring(table.foreach({5, 6, 7}, function(k, v) if v == 6 then return false end end))
local ids = {"1", "2", "3"}
table.foreach(ids, function(k, v) ids[k] = tonumber(v) end)
out[#out + 1] = type(ids[1]) .. ":" .. tostring(ids[1] + ids[2] + ids[3])
table.foreach(KEYS, function(i, key) redis.call("SET", key, i * 7) end)
out[#out + 1] = redis.call("GET", KEYS[1]) .. "," .. redis.call("GET", KEYS[2])
local function failure(f)
  local ok, message = pcall(f)
  out[#out + 1] = ok and "unexpected success" or tostring(message)
end
failure(function() return table.foreach(nil, function() end) end)
failure(function() return table.foreach({}, 1) end)
failure(function() table.foreach({1}, function() error("stop") end) end)
return out
