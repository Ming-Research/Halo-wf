-- checks: an unstarted thread retains its private entry closure, and a normal resumer retains private locals while its child allocates and enters a grandchild.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys; under collector stress this exercises thread-entry, stack, frame, resumer and current-thread paths; alternate retaining paths can mask individual omissions.
local function make_entry()
  local secret = {value = 101, label = string.rep("entry", 2)}
  return coroutine.create(function() return secret.value, secret.label end)
end
local waiting = make_entry()
local churn = 0
for i = 1, 64 do local temporary = {i}; churn = churn + temporary[1] end
local ok1, secret, label = coroutine.resume(waiting)
local parent = coroutine.create(function()
  local private = {value = 211, label = string.rep("parent", 2)}
  local child = coroutine.create(function()
    local total = 0
    for i = 1, 64 do local temporary = {i}; total = total + temporary[1] end
    local grandchild = coroutine.create(function()
      for i = 1, 64 do local temporary = {i}; total = total + temporary[1] end
      return total
    end)
    local ok, value = coroutine.resume(grandchild)
    if not ok then error(value, 0) end
    return value
  end)
  local ok, value = coroutine.resume(child)
  return tostring(ok), value, private.value, private.label
end)
local ok2, child_ok, total, held, held_label = coroutine.resume(parent)
return {tostring(ok1), secret, label, churn, tostring(ok2), child_ok, total, held, held_label, coroutine.status(parent)}
