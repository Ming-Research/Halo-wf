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

## Result

Searched on 2026-10-07: GitHub's index held 23,040 Lua, 4,544 JavaScript,
21,280 TypeScript, 18,880 Python, 12,640 Go, 10,912 Java, 1,468 Ruby,
22,272 PHP and 2,320 C# files containing `redis.call`. The first 300 of
each, 2,700 files in 2,168 repositories (search returned no forks), were
read in full and searched as above; the files themselves are not kept.
Seven repositories named `redis` were set aside as possible copies of
Redis; none had a match, so setting them aside changes nothing.

Calls inside a script Redis runs, on its normal path:

- `math.mod`: four repositories, one script. Ohm's save script tests
  `math.mod(#attrs, 2) == 1` on every save, in
  [soveran/ohm](https://github.com/soveran/ohm/blob/7dace9522d6af5af472bb34725f4972ef2845202/lib/ohm/lua/save.lua#L48)
  and its ports
  [soveran/ohm-crystal](https://github.com/soveran/ohm-crystal/blob/0d60236545ec77073a0378e4f76759389046e343/src/ohm/save.lua#L48),
  [pote/gohm](https://github.com/pote/gohm/blob/4d19ff19131fa94b8903c4f85e5469388c5840e1/lua_save.go#L51)
  and [luca3m/redis3m](https://github.com/luca3m/redis3m/blob/1c32da4df62bd415a175aae653c6f1649c0b37fe/data/lua/save.lua#L48).
- `table.foreach`: one repository. Discourse's presence channels convert
  the user ids a script reads and expire old members with it, in two
  scripts in
  [lib/presence_channel.rb](https://github.com/discourse/discourse/blob/833e1576d475b02bbea893272091dd3717773f73/lib/presence_channel.rb#L558).

No surveyed repository calls `coroutine`, `loadstring`, `load`,
`getfenv`, `setfenv`, `collectgarbage`, `gcinfo`, `newproxy`, `__gc`, a
weak table, `string.dump`, `string.gfind`, `table.foreachi` or
`table.setn` in a script. Matches read and set aside: `load(` in 18
repositories, every one in host-language code (JavaScript, Python, Go,
Ruby, PHP, C#); `__mode` in one script as the name of a hash field passed
to `HSET`; `setfenv` in one repository's game-server Lua, which reaches
Redis through a client module and is not a script Redis runs.

By the criterion, `math.mod` and `table.foreach` are implemented next, and
the other functions stay unimplemented.
