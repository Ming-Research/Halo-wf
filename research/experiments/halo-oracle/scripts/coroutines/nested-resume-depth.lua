-- checks: nested coroutines resume ever deeper until the reference refuses; the first failure is returned with the greatest entered depth.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local reached = 0
local function descend(depth)
  reached = depth
  local child = coroutine.create(descend)
  local ok, failed_depth, err = coroutine.resume(child, depth + 1)
  if not ok then return depth + 1, failed_depth end
  return failed_depth, err
end
local root = coroutine.create(descend)
local ok, failed_depth, err = coroutine.resume(root, 1)
if not ok then return {reached, tostring(ok), type(failed_depth), failed_depth} end
return {reached, tostring(ok), failed_depth, type(err), err, coroutine.status(root)}
