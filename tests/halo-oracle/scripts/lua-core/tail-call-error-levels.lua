-- checks: error(msg, level) counts each call a Lua-to-Lua tail call replaced as one level without a location (one, two and three in one frame, before a sort comparator, inside a comparator and before pcall); a tail call into a native function (error, pcall) keeps the calling frame.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local out = {}
local function run(label, f)
  for _, level in ipairs({1, 2, 3, 4, 5, 6, 7}) do
    local ok, msg = pcall(f, level)
    out[#out + 1] = label .. "/" .. level .. ":" .. tostring(msg)
  end
end
local function once_inner(level) error("m", level) end
local function once_middle(level) return once_inner(level) end
local function once(level) once_middle(level) end
local function twice_inner(level) error("m", level) end
local function twice_second(level) return twice_inner(level) end
local function twice_first(level) return twice_second(level) end
local function twice(level) twice_first(level) end
local function countdown(n, level)
  if n == 0 then error("m", level) end
  return countdown(n - 1, level)
end
local function counted(level) countdown(3, level) end
local function sorting(level)
  local function cmp(a, b) error("m", level) end
  table.sort({3, 1, 2}, cmp)
end
local function sort_tail(level) return sorting(level) end
local function sorted(level) sort_tail(level) end
local function cmp_fail(level) error("m", level) end
local function compared(level)
  table.sort({3, 1, 2}, function(a, b) return cmp_fail(level) end)
end
local function fail(level) error("m", level) end
local function guarded(level)
  local ok, msg = pcall(fail, level)
  error(msg, 0)
end
local function guard_tail(level) return guarded(level) end
local function protected(level) guard_tail(level) end
local function raise(level) return error("m", level) end
local function raised(level) raise(level) end
local function raise_tail(level) return raise(level) end
local function chained(level) raise_tail(level) end
local function pcall_tail(level) return pcall(fail, level) end
local function pcalled(level)
  local ok, msg = pcall_tail(level)
  error(msg, 0)
end
run("once", once)
run("twice", twice)
run("countdown", counted)
run("sort", sorted)
run("comparator", compared)
run("pcall", protected)
run("error", raised)
run("chain", chained)
run("pcalltail", pcalled)
return out
