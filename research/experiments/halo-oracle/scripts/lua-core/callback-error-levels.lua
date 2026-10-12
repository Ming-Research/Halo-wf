-- checks: error(msg, level) counts frames through native functions (sort, gsub, pcall) that call back into Lua and adds a location only when the frame at that level is a Lua function; metamethods add no frame; a level past the top adds none.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local out = {}
local function run(label, f)
  for _, level in ipairs({0, 1, 2, 3, 4, 5, 50}) do
    local ok, msg = pcall(f, level)
    out[#out + 1] = label .. "/" .. level .. ":" .. tostring(msg)
  end
end
local function direct(level)
  local function inner() error("m", level) end
  inner()
end
local function viapcall(level) error("m", level) end
local function sorted(level)
  local function cmp(a, b) error("m", level) end
  table.sort({3, 1, 2}, cmp)
end
local function replaced(level)
  local function rep(c) error("m", level) end
  string.gsub("abc", "%w", rep)
end
local function indexed(level)
  local t = setmetatable({}, {__index = function() error("m", level) end})
  local _ = t.x
end
local function added(level)
  local t = setmetatable({}, {__add = function() error("m", level) end})
  local _ = t + 1
end
run("direct", direct)
run("pcall", viapcall)
run("sort", sorted)
run("gsub", replaced)
run("index", indexed)
run("add", added)
return out
