#!/bin/sh
# TEMPORARY, item 274: the Whitefoot upgrade benchmark, run once through the fast workflow on the
# 14900K, then removed before the work merges. Arguments: the mode (sample: fib once; full: the seven
# kernels of the compiler-upgrade procedure in RESULTS.md, six pairs each), the pinned whitefootc, the
# reference Lua, and the output directory. The 'before' binary is built from this same source by the
# previous release's compiler. The script always ends with exit 1, so run_tests returns its summary as
# the failure text.
set -eu

mode=$1
wfc=$2
lua=$3
out=$4
old_release=wf-af7665be672d
old_sha=7a403678f04edf84151813edc683503f85eb0c22ab7396adfb98d99d3639d058

mkdir -p "$out/old"
curl -fsSL --retry 3 -o "$out/old/whitefootc-linux-x86_64.tar.gz" \
  "https://github.com/Ming-Research/Whitefoot/releases/download/$old_release/whitefootc-linux-x86_64.tar.gz"
echo "$old_sha  $out/old/whitefootc-linux-x86_64.tar.gz" | sha256sum -c -
tar -xzf "$out/old/whitefootc-linux-x86_64.tar.gz" -C "$out/old"
old="$out/old/whitefootc"

if [ "$mode" = sample ]; then
  kernels=fib
  batches="1"
  scale=
else
  # The three batches of RESULTS.md's compiler-upgrade procedure, in its order, in one request.
  kernels=fib,loop,integer-table,string-key,concat,sort,binary-trees
  batches="1 3 6"
  scale="--scale binary-trees=14"
fi

graph=research/experiments/halo-bench/modules.wfg
"$wfc" --graph "$graph" --entry bench --full-lto -o "$out/halo-after"
"$old" --graph "$graph" --entry bench --full-lto -o "$out/halo-before"

status=0
for runs in $batches; do
  code=0
  # shellcheck disable=SC2086
  python3 -B research/experiments/halo-bench/run.py --lua "$lua" \
    --before-binary "$out/halo-before" --binary "$out/halo-after" \
    --kernels "$kernels" $scale --runs "$runs" --out "$out/compare-$runs.json" \
    --compiler "$wfc" > "$out/compare-$runs.log" 2>&1 || code=$?
  [ "$code" = 0 ] || status=$code
  echo "batch runs=$runs: run.py exit $code"
done

echo "upgrade benchmark, $mode mode: $old_release -> $(basename "$wfc"); run.py exit $status"
sha256sum "$wfc" "$old" "$out/halo-before" "$out/halo-after"
for runs in $batches; do
  echo "--- batch runs=$runs, last 20 lines"
  tail -n 20 "$out/compare-$runs.log"
done
exit 1
