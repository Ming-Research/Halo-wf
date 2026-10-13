-- checks: The base library exposes _VERSION as the string Lua 5.1.
-- KEYS: []
-- ARGV: []
-- expects: Version string and its Lua type; no pre-existing keys.
return {_VERSION, type(_VERSION)}
