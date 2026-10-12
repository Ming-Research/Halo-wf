-- checks: string.gsub rejects cjson.null as a replacement with the reference's userdata argument error.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
local ok, err = pcall(string.gsub, "a", "a", cjson.null)
return {type(cjson.null), tostring(ok), type(err), err}
