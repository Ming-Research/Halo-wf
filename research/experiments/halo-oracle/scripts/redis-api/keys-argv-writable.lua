-- checks: KEYS and ARGV stay writable while the globals and library tables are read-only: assignment to KEYS[1] and ARGV[1], and table.insert appending to each.
-- KEYS: ["halo-oracle:keys"]
-- ARGV: ["first"]
-- expects: No pre-existing keys.
KEYS[1] = KEYS[1] .. ":changed"
ARGV[1] = ARGV[1] .. ":changed"
table.insert(KEYS, "halo-oracle:appended")
table.insert(ARGV, "appended")
return {KEYS[1], KEYS[2], ARGV[1], ARGV[2], #KEYS, #ARGV}
