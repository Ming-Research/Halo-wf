-- checks: coroutines entered through __index wrappers that clear their own metamethod stay distinct from a coroutine created while they run, and the inner one still reads its parked parent's local.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; each wrapper sits only in a callback slot above its caller's live registers, so a running coroutine is reachable only as the current thread and its normal parent only as its resumer. Under collector stress this targets the current-thread and resumer omissions.
local function id(value)
  return value
end
local function chain()
  local outer_meta, inner_meta = {}, {}
  local outer_holder = setmetatable({}, outer_meta)
  local inner_holder = setmetatable({}, inner_meta)
  outer_meta.__index = coroutine.wrap(function()
    outer_meta.__index = nil
    local parent = {tag = "parent"}
    inner_meta.__index = coroutine.wrap(function()
      inner_meta.__index = nil
      local total = 0
      for i = 1, 16 do
        local temporary = {i}
        total = total + temporary[1]
      end
      local fresh = coroutine.create(function() return "fresh" end)
      local same = rawequal(coroutine.running(), fresh)
      local resumed, value = coroutine.resume(fresh)
      return table.concat({tostring(same), tostring(resumed), tostring(value), total, parent.tag}, ":")
    end)
    return id(inner_holder).missing
  end)
  return id(outer_holder).missing
end
return {chain()}
