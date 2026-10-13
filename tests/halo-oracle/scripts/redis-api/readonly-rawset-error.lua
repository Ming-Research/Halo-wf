-- checks: The error reply when a script's last statement calls rawset on a protected library table, which raises the refusal inside a library function rather than at a script line.
-- KEYS: []
-- ARGV: []
-- expects: No pre-existing keys.
-- error: true
return rawset(string, "halo_x", 1)
