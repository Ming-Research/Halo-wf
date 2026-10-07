-- checks: table.foreach calls its function with each key and value in next order, returns the first non-nil result, lets the function assign existing fields and call Redis, rejects a non-table or non-function argument, passes a callback error on unchanged, and runs under pcall and inside sort and gsub callbacks.
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
failure(function() table.foreach({1}, function() error("bare", 0) end) end)
out[#out + 1] = tostring(select(2, pcall(table.foreach, {7, 8}, function(k, v) if v == 8 then return "p" .. k end end)))
out[#out + 1] = (string.gsub("ab", "%w", function(c) return table.foreach({c}, function(k, v) return v .. v end) end))
local sorted = {3, 1, 2}
table.sort(sorted, function(a, b) return table.foreach({a}, function(k, v) return v < b end) end)
out[#out + 1] = table.concat(sorted, ",")
return out
