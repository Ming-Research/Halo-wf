#!/bin/sh
# Fetches and builds the comparison interpreters of the fastest-interpreter
# baseline (README.md) into <directory>, each from source at a pinned version
# with the release build its project ships by default:
#   PUC Lua 5.4.9   lua.org tarball, SHA-256 as lua.org publishes it;
#                   `make linux` (gcc -std=gnu99 -O2 -DLUA_COMPAT_5_3)
#   LuaJIT 2.1      v2.1 branch at a pinned commit; `make` (gcc -O2
#                   -fomit-frame-pointer), run with -joff
#   Luau 0.742      release tag at its commit; `make config=release luau`
#                   (g++ -O2 -DNDEBUG -fno-math-errno), the CLI without
#                   --codegen, so its interpreter runs every function
# PUC Lua 5.1.5 comes from Redis 7.2.16 through the default version of
# tests/halo-oracle/fetch-redis.sh <dir>. <directory>/manifest.txt
# records versions, digests, compilers and one compile line of each build.
# Linux only (nproc, sha256sum); CI runs it.
set -eu
dir=${1:?usage: interpreters.sh <directory>}
mkdir -p "$dir"
dir=$(cd "$dir" && pwd)

lua54_version=5.4.9
lua54_sha256=2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6
luajit_commit=c6ffc141a8762b41703f9287d63d93622a13dd8f
luau_tag=0.742
luau_commit=8387cfb461b38ce09e37c1e4c2811538ef1bf5cb

manifest=$dir/manifest.txt
: > "$manifest"

# compile_line <log> <pattern>: the first compile command matching pattern.
compile_line() {
  grep -m1 -e "$2" "$1" || echo "no compile line matches $2"
}

build() {
  name=$1; shift
  "$@" > "$dir/$name-build.log" 2>&1 || { tail -40 "$dir/$name-build.log" >&2; exit 1; }
}

# fetch_commit <name> <repository> <commit>: a shallow fetch of exactly that
# commit; git checks the objects against the commit id.
fetch_commit() {
  rm -rf "${dir:?}/$1"
  git init -q "$dir/$1"
  git -C "$dir/$1" fetch -q --depth 1 "$2" "$3"
  git -C "$dir/$1" checkout -q FETCH_HEAD
  [ "$(git -C "$dir/$1" rev-parse HEAD)" = "$3" ] || { echo "$1: HEAD is not $3" >&2; exit 1; }
}

# PUC Lua 5.4.9.
tarball=$dir/lua-$lua54_version.tar.gz
curl -fsSL --retry 3 -o "$tarball" "https://www.lua.org/ftp/lua-$lua54_version.tar.gz"
actual=$(sha256sum "$tarball" | awk '{ print $1 }')
[ "$actual" = "$lua54_sha256" ] || { echo "lua-$lua54_version.tar.gz: SHA-256 $actual, pinned $lua54_sha256" >&2; exit 1; }
rm -rf "$dir/lua-$lua54_version"
tar -xzf "$tarball" -C "$dir"
build lua54 make -C "$dir/lua-$lua54_version" linux
lua54=$dir/lua-$lua54_version/src/lua
{
  echo "puc-5.4.9: $lua54"
  echo "  source lua-$lua54_version.tar.gz sha256 $actual"
  echo "  compile: $(compile_line "$dir/lua54-build.log" ' -c .*lvm\.c')"
} >> "$manifest"

# LuaJIT 2.1, the v2.1 branch's head when pinned (2026-09-08).
fetch_commit luajit https://github.com/LuaJIT/LuaJIT.git "$luajit_commit"
build luajit make -C "$dir/luajit" -j"$(nproc)" Q=
luajit=$dir/luajit/src/luajit
{
  echo "luajit-2.1-joff: $luajit -joff"
  echo "  source LuaJIT commit $luajit_commit, $("$luajit" -v)"
  echo "  compile: $(compile_line "$dir/luajit-build.log" ' -o lj_tab\.o ')"
} >> "$manifest"

# Luau 0.742 (released 2026-10-09).
fetch_commit luau https://github.com/luau-lang/luau.git "$luau_commit"
build luau make -C "$dir/luau" config=release luau
luau=$dir/luau/build/release/luau
{
  echo "luau-$luau_tag: $luau (default -O1, no --codegen)"
  echo "luau-$luau_tag-O2: $luau -O2 (no --codegen)"
  echo "  source Luau tag $luau_tag commit $luau_commit"
  echo "  compile: $(compile_line "$dir/luau-build.log" 'lvmexecute\.cpp')"
} >> "$manifest"

{
  echo "gcc: $(gcc --version | head -n 1)"
  echo "g++: $(g++ --version | head -n 1)"
  for binary in "$lua54" "$luajit" "$luau"; do
    sha256sum "$binary"
  done
} >> "$manifest"
cat "$manifest"
