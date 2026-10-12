-- checks: direct Lua calls of wrappers prefix located and numeric errors, preserve table identity and locate a dead-wrapper error; only the enclosing Lua thunk is protected.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local observations = {}
local token = {tag = "wrapped-table"}
local function observe(name, body)
  local wrapped = coroutine.wrap(body)
  local ok, value = pcall(function()
    local result = wrapped()
    return result
  end)
  if type(value) == "table" then
    observations[#observations + 1] = {name, tostring(ok), type(value), tostring(value == token), value.tag}
  else
    observations[#observations + 1] = {name, tostring(ok), type(value), tostring(value)}
  end
end
observe("located-string", function() error("direct-wrapped-string") end)
observe("level-zero-string", function() error("direct-wrapped-zero", 0) end)
observe("number", function() error(17, 0) end)
observe("table", function() error(token, 0) end)
local dead = coroutine.wrap(function() return "finished" end)
local first = dead()
local ok, err = pcall(function()
  local result = dead()
  return result
end)
observations[#observations + 1] = {"dead", first, tostring(ok), type(err), err}
return observations
