-- checks: an error string.gsub raises after a replacement function that called redis.call returns is reported at the gsub call's line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
local function replacement()
  redis.call("PING")
  return {}
end
return string.gsub("x","x",replacement)
