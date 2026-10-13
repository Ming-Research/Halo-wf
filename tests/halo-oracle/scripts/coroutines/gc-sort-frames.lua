-- checks: sort keeps its compared pair and its pivot while a comparator clears the table slots and its own parameters and resumes a child that allocates; the swap and the later comparisons use the kept values.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress the sorting thread is parked while the child collects, so this targets the saved sort-a, sort-b and sort-pivot omissions.
local keep = {}
local function churn()
  local child = coroutine.create(function()
    for i = 1, 32 do keep[#keep + 1] = {rank = -i, tag = "decoy"} end
  end)
  local ok, err = coroutine.resume(child)
  if not ok then error(err, 0) end
end
local function make_pair()
  return {{rank = 2, tag = "x"}, {rank = 1, tag = "y"}}
end
local function swapped_pair()
  local values = make_pair()
  local calls = 0
  table.sort(values, function(p, q)
    calls = calls + 1
    local less = p.rank < q.rank
    values[1], values[2] = nil, nil
    p, q = nil, nil
    churn()
    return less
  end)
  return {calls, values[1].tag, values[2].tag}
end
local function make_four()
  return {{rank = 1, tag = "a"}, {rank = 2, tag = "b"}, {rank = 3, tag = "c"}, {rank = 4, tag = "d"}}
end
local function parked_pivot()
  local values = make_four()
  local log = {}
  local removed, restored = false, false
  table.sort(values, function(p, q)
    local less = p.rank < q.rank
    log[#log + 1] = p.tag .. q.tag
    if removed and not restored then
      restored = true
      values[3] = p
    elseif not removed and q.tag == "b" and values[3] == q then
      removed = true
      values[3] = nil
      q = nil
      churn()
    end
    return less
  end)
  return {table.concat(log, ","), tostring(removed), tostring(restored), values[1].tag, values[2].tag, values[3].tag, values[4].tag}
end
return {swapped_pair(), parked_pivot()}
