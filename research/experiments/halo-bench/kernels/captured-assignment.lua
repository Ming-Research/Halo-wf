local N = 1000000
local captured = 0
local function assign(value)
  captured = value
  return captured
end
local sum = 0
for i = 1, N do
  sum = sum + assign(i)
end
print(sum)
