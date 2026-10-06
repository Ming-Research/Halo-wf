# Redis Lua library compatibility results

Run on GitHub-hosted x86-64 Linux by a temporary workflow (Halo-wf run 37454199989), with the pinned compiler release `wf-648338c31240` and Redis 7.0.15's bundled Lua built from source with gcc, the reference platform.

Local revision: `0ed0c604e158bb7eb3da2b2f17680373d04ee639`. Host: `Linux-6.17.0-1022-azure-x86_64-with-glibc2.39`.
Reference: Redis 7.0.15 bundled sources, all four libraries explicitly registered; `2.1.0	lua-cmsgpack 0.4.0`.
Reference build 20.912s. Halo build 65.645s. Budget 7.
Compiler SHA-256: `07b0969d5b1b6d761321f04153c6990e307c9cd30e2b14f1f2405f12891e4171`.
Executable SHA-256: `de49355d80ef3e247edf767b54467b7d73e42ca209839d310e3572e9e13ad988`.

| Library | Snippets | Matches | Mismatches |
| --- | ---: | ---: | ---: |
| bit | 223 | 223 | 0 |
| cjson | 297 | 290 | 7 |
| cmsgpack | 157 | 157 | 0 |
| struct | 254 | 254 | 0 |

Total: 933 snippets; 924 matches; 7 mismatches; 2 with no reference reply.

The comparator checks typed replies, binary bytes, and exact error text. Its fault sensitivity controls come from the existing end-to-end runner. The first return value is converted as Redis RESP2; snippets wrap multiple results where needed. No oracle fixtures were changed. The host is x86-64 Linux with glibc, the reference platform.

## Interpretation

- **Platform**: this run supersedes the macOS arm64 run at `2b6cc81c6` (903 of 930). Fifteen of its twenty platform-dependent mismatches match the x86-64 reference unchanged (903 - 2 + 15 = 916 matches before the fix), for example `userdata: (nil)` and conversions at or above 2^64.
- **Fixed**: five struct snippets packed NaN differently from x86-64. Integer formats give a NaN `0x8000000000000000`, and single narrowing keeps a NaN's sign; Halo now does both (`a7581bd85`). Three added snippets unpack NaN singles, and all match.
- **Open, 7 mismatches**: cjson/221–227 need Lua debug names for locals and fields in error text (`docs/todo.md`).
- **No reference reply, 2 snippets**: `bit.tohex(305419896, 2147483648)` and `bit.tohex(305419896, -2147483648)`. Redis 7.0.15's bundled `lua_bit.c` negates a digit count of -2^31, which overflows, and the reference process exits on SIGSEGV. These snippets have no comparable reply.

## Mismatches and snippets without a reference reply

### cjson/221
```lua
local f=cjson.decode; return f(false)
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: bad argument #1 to 'f' (string expected, got boolean) script: e110c7f374e4199be1a1e0dc03ef56fe320e1957, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: bad argument #1 to 'decode' (string expected, got boolean) script: e110c7f374e4199be1a1e0dc03ef56fe320e1957, on @user_script:1."}`

### cjson/222
```lua
local f=bit.tobit; return f(false)
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: bad argument #1 to 'f' (number expected, got boolean) script: 297e049d0025eb6882eecdc1d53885fed87a6ae2, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: bad argument #1 to 'tobit' (number expected, got boolean) script: 297e049d0025eb6882eecdc1d53885fed87a6ae2, on @user_script:1."}`

### cjson/223
```lua
return cjson.null()
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: attempt to call field 'null' (a userdata value) script: b8638b1cc530a3603ab9ddc2f569b5035c2f83fb, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: attempt to call a userdata value script: b8638b1cc530a3603ab9ddc2f569b5035c2f83fb, on @user_script:1."}`

### cjson/224
```lua
return cjson.null+1
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: attempt to perform arithmetic on field 'null' (a userdata value) script: 321563bc5a16711a77229de78c14de128c3dfd9b, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: attempt to perform arithmetic on a userdata value script: 321563bc5a16711a77229de78c14de128c3dfd9b, on @user_script:1."}`

### cjson/225
```lua
return cjson.null[1]
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: attempt to index field 'null' (a userdata value) script: 79cb4309d2b46fd7edbcd1621501d0630e1fad05, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: attempt to index a userdata value script: 79cb4309d2b46fd7edbcd1621501d0630e1fad05, on @user_script:1."}`

### cjson/226
```lua
return cjson.null.."x"
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: attempt to concatenate field 'null' (a userdata value) script: 1dd7ba35ae1e66ed7c7b9030edd86da15a4f5af4, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: attempt to concatenate a userdata value script: 1dd7ba35ae1e66ed7c7b9030edd86da15a4f5af4, on @user_script:1."}`

### cjson/227
```lua
return #cjson.null
```
Expected: `{"type": "error", "bytes": "ERR user_script:1: attempt to get length of field 'null' (a userdata value) script: 68d56be290ac550c4f3f1bba0f53ececb8c48b21, on @user_script:1."}`
Actual: `{"type": "error", "bytes": "ERR user_script:1: attempt to get length of a userdata value script: 68d56be290ac550c4f3f1bba0f53ececb8c48b21, on @user_script:1."}`

### bit/220: the reference exited with -11
```lua
return bit.tohex(305419896,2147483648)
```
Reference stderr: `""`

### bit/221: the reference exited with -11
```lua
return bit.tohex(305419896,-2147483648)
```
Reference stderr: `""`
