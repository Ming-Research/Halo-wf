-- checks: a table that table.foreach walks stays alive while foreach's saved library record is its only holder and a child allocates inside the callback.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; foreach runs as an __index function, so its arguments lie above the caller's registers and its first callback call overwrites them, and that callback then removes the only other reference. Under collector stress the caller is parked while the child collects, so this targets the library-table omission, whose freed table a decoy would reuse before foreach reads the next key.
local keep = {}
local function churn()
  local child = coroutine.create(function()
    for i = 1, 32 do keep[#keep + 1] = {tag = "decoy"} end
  end)
  local ok, err = coroutine.resume(child)
  if not ok then error(err, 0) end
end
local walked = setmetatable({"a", "b", "c"}, {__index = table.foreach})
local proxy = setmetatable({}, {__index = walked})
walked = nil
local seen = {}
local function visit(key, value)
  seen[#seen + 1] = key .. "=" .. value
  if key == 1 then
    getmetatable(proxy).__index = nil
    churn()
  end
end
local ok, result = pcall(function() return proxy[visit] end)
return {tostring(ok), table.concat(seen, " "), tostring(result)}
