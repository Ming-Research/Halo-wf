-- checks: a function that holds an open capture resumes one coroutine that yields with its own capture open at a higher stack slot and another that finishes and closes its capture; after the function returns, its caller overwrites the old frame and the returned closure still reads and writes the captured value.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local seen = {}
local function make()
  local x = 7
  local function getx()
    x = x + 1
    return x
  end
  local hold = coroutine.create(function()
    local p1, p2, p3, p4, p5, p6, p7, p8 = 1, 2, 3, 4, 5, 6, 7, 8
    local deep = 41
    local function peek()
      deep = deep + 1
      return deep
    end
    coroutine.yield(peek())
    return peek() + p8
  end)
  local ok1, v1 = coroutine.resume(hold)
  local done = coroutine.create(function()
    local y = 100
    local function get() return y end
    return get()
  end)
  local ok2, v2 = coroutine.resume(done)
  seen[1] = v1
  seen[2] = v2
  return getx
end
local getx = make()
local function clobber(a, b, c, d)
  local t = {a, b, c, d}
  return #t
end
local junk = clobber(900, 901, 902, 903)
local ok1, r1 = pcall(getx)
local ok2, r2 = pcall(getx)
return {tostring(ok1), r1, tostring(ok2), r2, seen[1], seen[2], junk}
