-- checks: a value held only in a deep register of a foreach callback inside a coroutine survives a budget stop taken with garbage over the host's heap limit, and is intact when the run continues.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys. The main chunk holds a 40 MiB string; 200 nested calls inside the callback put the fresh table far past the coroutine stack's length at callback entry, and the deepest call drops a 30 MiB string just before a call. At budget 1 that call always stops before its safepoint collects, so a host with a 64 MiB heap limit collects while only the stopped stack copy holds the table. Written to make the reply depend on the stopped-copy mark, it did not: the control omitting that mark left the reply unchanged (halo-gc README); it stays as the corpus's only case of that collection during a budget stop in a callback.
local big = string.rep("a", 40 * 1048576)
local keep = {}
local function refill()
  for i = 1, 32 do keep[#keep + 1] = {tag = "decoy"} end
end
local function deep(level)
  if level > 0 then
    local tag = deep(level - 1)
    return tag
  end
  local fresh = {tag = "fresh"}
  local width = #string.rep("x", 30 * 1048576)
  refill()
  return tostring(fresh.tag) .. "/" .. width
end
local seen = {}
local function visit(key, value)
  seen[#seen + 1] = key .. "=" .. deep(200)
end
local co = coroutine.create(function()
  table.foreach({"only"}, visit)
  return #seen
end)
local ok, count = coroutine.resume(co)
return {tostring(ok), tostring(count), tostring(seen[1]), #keep, #big}
