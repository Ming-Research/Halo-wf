#!/bin/sh
# Fetches Redis 7.0.15, the reference (AGENTS.md), into <directory>, checks the
# tarball against the hash Redis publishes in its redis-hashes repository, an
# independent source, and builds its bundled Lua with Redis's own deps
# Makefile: <directory>/redis-7.0.15/deps/lua/src holds lua, liblua.a and the
# headers. `make reference-lua` runs it; it does nothing when that Lua exists.
set -eu
dir=${1:?usage: fetch-redis.sh <directory>}
version=7.0.15
src=$dir/redis-$version
[ -x "$src/deps/lua/src/lua" ] && [ -f "$src/deps/lua/src/liblua.a" ] && exit 0
mkdir -p "$dir"
curl -fsSL --retry 3 -o "$dir/redis-$version.tar.gz" "https://download.redis.io/releases/redis-$version.tar.gz"
expected=$(curl -fsSL --retry 3 https://raw.githubusercontent.com/redis/redis-hashes/master/README \
  | awk -v name="redis-$version.tar.gz" '$2 == name && $3 == "sha256" { print $4 }')
[ -n "$expected" ]
actual=$( (sha256sum "$dir/redis-$version.tar.gz" 2>/dev/null || shasum -a 256 "$dir/redis-$version.tar.gz") | awk '{ print $1 }')
[ "$actual" = "$expected" ] || { echo "redis-$version.tar.gz: SHA-256 $actual, published $expected" >&2; exit 1; }
rm -rf "$src"
tar -xzf "$dir/redis-$version.tar.gz" -C "$dir"
make -C "$src/deps" lua > "$dir/lua-build.log" 2>&1 || { tail -40 "$dir/lua-build.log" >&2; exit 1; }
[ -x "$src/deps/lua/src/lua" ] || { echo "Redis's deps build made no lua executable" >&2; exit 1; }
