-- checks: tail transfers carry many freshly allocated arguments beyond fixed registers and return those values through nested resume and yield boundaries.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress this targets active/saved transfer argument and child edges where the runtime reaches those records.
local function make_values()
  return {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}, {10}, {11}, {12}, {13}, {14}, {15}, {16}, {17}, {18}, {19}, {20}, nil
end
local function summarize(...)
  local count, total = select("#", ...), 0
  for i = 1, count do
    local value = select(i, ...)
    if value ~= nil then total = total + value[1] end
  end
  return count, total
end
local function leaf(...)
  local count, total = summarize(...)
  local next_count, next_total = summarize(coroutine.yield(count, total))
  return next_count, next_total
end
local child = coroutine.create(leaf)
local function resume_values()
  return coroutine.resume(child, make_values())
end
local relay = coroutine.create(resume_values)
local ok1, child_ok, count1, total1 = coroutine.resume(relay)
local ok2, count2, total2 = resume_values()
local tail = coroutine.create(function() return coroutine.yield(make_values()) end)
local function yield_summary(ok, ...)
  local count, total = summarize(...)
  return tostring(ok), count, total
end
local ok3, count3, total3 = yield_summary(coroutine.resume(tail))
local ok4, count4, total4 = yield_summary(coroutine.resume(tail, make_values()))
return {tostring(ok1), tostring(child_ok), count1, total1, tostring(ok2), count2, total2, ok3, count3, total3, ok4, count4, total4}
