-- checks: Methods of a cjson.new() instance, called through the table and after extraction, beside a string.gmatch iterator.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local j=cjson.new()
local encode=j.encode
local words={}
for w in string.gmatch('a b','%a') do words[#words+1]=w end
return {j.encode({1,2}),encode({3}),j.decode('[4]')[1],table.concat(words,',')}
