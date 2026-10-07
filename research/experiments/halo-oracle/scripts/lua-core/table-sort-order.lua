-- checks: Default auxsort permutation for duplicate numbers, signed zeros, strings with NUL, NaN, hash-backed indices and short arrays.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local function joined(t)
  local text = {}
  for i = 1, #t do
    text[i] = tostring(t[i])
  end
  return table.concat(text, "|")
end

local numbers = {}
local seed = 12345
local zero = 0
for i = 1, 300 do
  seed = (seed * 25173 + 13849) % 65536
  local value = seed % 23 - 11
  if i % 13 == 0 then
    value = -zero
  elseif i % 17 == 0 then
    value = zero
  end
  numbers[i] = value
end
table.sort(numbers)

local words = {"a", "a\000", "a\000b", "a\000a", "", "b", "\000", "a"}
local strings = {}
for i = 1, 50 do
  strings[i] = words[(i * 7) % #words + 1]
end
table.sort(strings)

local nonfinite = {3, zero / zero, -zero, 2, 0, -1, 3, zero / zero, 1}
local ok, err = pcall(table.sort, nonfinite)
local nan_result
if ok then
  nan_result = "ok:" .. joined(nonfinite)
else
  nan_result = "error:" .. tostring(err)
end

local hash_backed = {[1] = 3, [2] = -zero, [3] = 1, [4] = 0,
                     [5] = -1, [6] = 3, [7] = -zero, [8] = 2}
table.sort(hash_backed)

local empty = {}
local one = {-zero}
local two = {0, -zero}
local three = {1, 0, -zero}
table.sort(empty)
table.sort(one)
table.sort(two)
table.sort(three)
return {joined(numbers), joined(strings), nan_result, joined(hash_backed),
        joined(empty), joined(one), joined(two), joined(three)}
