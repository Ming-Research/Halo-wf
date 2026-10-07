# What real Redis scripts use of Lua beyond Halo

## Question

Halo implements Lua 5.1 as Redis 7.0.15's scripting sandbox exposes it,
less the functions below. Which of them do real Redis scripts call? The
answer selects which Halo implements next; a function no surveyed script
calls stays unimplemented, with this survey as its ground, until a host
reports a script that needs it.

Redis 7.0.15 loads Lua's base, table, string, math and debug libraries with
`cjson`, `struct`, `cmsgpack` and `bit`, keeps the globals on its allow
lists, removes `dofile`, `loadfile` and `print`, and sets `debug` to nil
after start-up (`src/script_lua.c`: `libraries_allow_list`,
`lua_builtins_allow_list`, `lua_builtins_not_documented_allow_list`,
`deny_list`, `luaLoadLibraries`). Its Lua defines `LUA_COMPAT_MOD` and
`LUA_COMPAT_GFIND` (`deps/lua/src/luaconf.h`). Against Halo's builtin
table (`lib/halo/vm/module.wfm`), Halo lacks:

- the `coroutine` library: `create`, `resume`, `running`, `status`,
  `wrap`, `yield`;
- `loadstring` and `load`;
- `getfenv` and `setfenv`;
- `collectgarbage`, `gcinfo` and `newproxy`, with the `__gc` metamethod a
  `newproxy` userdata can carry, and weak tables (`__mode`);
- `string.dump` and `string.gfind`;
- `table.foreach`, `table.foreachi` and `table.setn`;
- `math.mod`.

## Corpus, fixed before reading any script

GitHub code search for files containing `redis.call`, one query per
language (Lua, JavaScript, TypeScript, Python, Go, Java, Ruby, PHP, C#),
the first 300 results of each in GitHub's order, forks excluded. Files in
repositories of Redis itself, its forks and Lua engines (Redis's own tests
exercise the sandbox, not scripts written for an application) are
excluded. A repository counts once per function, however many of its files
call it.

## Method and criterion

Each file is searched for each function's name in a call or field position
(`coroutine.`, `loadstring(`, `setfenv(`, `__gc`, `__mode`, `table.foreach`
and so on), and every match is read in context to keep only calls inside a
script that Redis runs, not comments, strings outside a script, or code
that runs in the client. A function is implemented next when at least one
surveyed repository calls it from a script on a path its normal operation
reaches; the others stay unimplemented.

The survey cannot see private scripts or scripts that search does not
index, and GitHub's order is not a sample of production use; the result is
stated no wider than the corpus.
