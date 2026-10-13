-- checks: protected calls and sort/gsub callbacks inserted near the nested-resume limit consume their own C-depth while each child starts with its resume baseline.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local observations = {}
local function observe(mode, at)
  local reached = 0
  local function descend(depth)
    reached = depth
    local function next_child()
      local child = coroutine.create(descend)
      local ok, failed, message = coroutine.resume(child, depth + 1)
      if not ok then return depth + 1, failed end
      return failed, message
    end
    if depth ~= at then return next_child() end
    local failed, message
    local function invoke()
      if mode == "pcall" then
        failed, message = next_child()
      elseif mode == "sort" or mode == "pcall-sort" then
        table.sort({2, 1}, function(a, b)
          failed, message = next_child()
          return a < b
        end)
      else
        string.gsub("x", "x", function()
          failed, message = next_child()
          return "y"
        end)
      end
    end
    if mode == "pcall" or mode == "pcall-sort" or mode == "pcall-gsub" then
      local ok, err = pcall(invoke)
      if not ok then return depth + 1, err end
    else
      invoke()
    end
    return failed, message
  end
  local root = coroutine.create(descend)
  local ok, failed, message = coroutine.resume(root, 1)
  observations[#observations + 1] = {mode, at, reached, tostring(ok), type(failed), tostring(failed), type(message), tostring(message), coroutine.status(root)}
end
for _, mode in ipairs({"pcall", "sort", "gsub", "pcall-sort", "pcall-gsub"}) do
  observe(mode, 190)
  observe(mode, 197)
end
return observations
