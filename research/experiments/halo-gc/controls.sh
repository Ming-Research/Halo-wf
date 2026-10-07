#!/bin/sh
# The collector's removed-root controls ("Local root witnesses" in README.md):
# the local root cases pass with every root, and each fails once its sole
# root is hidden from the collector or one marking call of mark_roots
# (lib/halo/vm/collect.wf) is removed. Expected failures require a reply/conversion
# difference, with no native-exit failure or Traceback. A pure-shell classifier
# self-test runs first, before compiler setup. Mutants build in copies under the
# scratch directory; the working tree is never edited. `make roots` runs it:
#   WHITEFOOTC=<compiler> controls.sh <built e2e test program> <scratch directory>
set -u

is_reply_failure() (
  difference=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *Traceback*|"FAIL "*": native exit "*) return 1 ;;
      "FAIL "*": reply/conversion difference; inspect actual JSON") difference=0 ;;
    esac
  done
  return "$difference"
)

classifier_self_test() {
  is_reply_failure <<'EOF' || return 1
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
EOF
  if is_reply_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
FAIL gc/frame-closure.lua budget=7 collections=None: native exit -11 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)
EOF
  then return 1; fi
  if is_reply_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
Traceback (most recent call last):
EOF
  then return 1; fi
  if is_reply_failure <<'EOF'
1/1 passed
EOF
  then return 1; fi
  return 0
}

if ! classifier_self_test; then
  echo "roots classifier self-test: failed" >&2
  exit 1
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd -P)
wfc=${WHITEFOOTC:?set WHITEFOOTC to the Whitefoot compiler}
binary=${1:?usage: controls.sh <e2e test program> <scratch directory>}
out=${2:?usage: controls.sh <e2e test program> <scratch directory>}
mkdir -p "$out"
cases=$root/research/experiments/halo-gc/cases
status=0

compare() {
  python3 -B "$root/research/experiments/halo-e2e/run.py" --compiler "$wfc" --scratch-root "$out" "$@"
}

# A control expected to fail must fail by a reply comparison, not a crash.
expect() {
  want=$1; label=$2; shift 2
  "$@" > "$out/$label.log" 2>&1
  got=$?
  echo "roots $label: exit $got (want $want), $(grep -E 'passed$' "$out/$label.log" | tail -1)"
  if [ "$got" != "$want" ]; then status=1; cat "$out/$label.log"; return; fi
  if [ "$want" = 1 ]; then
    if ! is_reply_failure < "$out/$label.log"; then
      echo "roots $label: did not fail by a reply comparison"; status=1; cat "$out/$label.log"
    fi
  fi
}

mutant() {
  label=$1; line=$2
  tree=$out/tree-$label
  rm -rf "$tree"
  mkdir -p "$tree/research/experiments"
  cp -R "$root/lib" "$tree/lib"
  cp -R "$root/research/experiments/halo-e2e" "$tree/research/experiments/halo-e2e"
  grep -vF "$line" "$root/lib/halo/vm/collect.wf" > "$tree/lib/halo/vm/collect.wf"
  removed=$(( $(wc -l < "$root/lib/halo/vm/collect.wf") - $(wc -l < "$tree/lib/halo/vm/collect.wf") ))
  if [ "$removed" != 1 ]; then
    echo "roots mutant $label: removed $removed lines, want 1"; status=1; return
  fi
  if ! (cd "$tree/research/experiments/halo-e2e" && "$wfc" --graph modules.wfg --entry test -o "$out/mutant-$label") > "$out/build-$label.log" 2>&1; then
    echo "roots mutant $label: build failed"; status=1; cat "$out/build-$label.log"
  fi
}

expect 0 every-root compare --binary "$binary" --cases "$cases" --budgets 1,7,1000 --gc-stress
expect 0 frame-sole-root compare --binary "$binary" --cases "$cases" --filter gc/frame-closure --budgets 1 --gc-stress --isolate-frames
expect 0 parked-sole-root compare --binary "$binary" --cases "$cases" --filter gc/suspended-stack --budgets 1 --gc-stress --collect-suspended
expect 1 parked-root-hidden compare --binary "$binary" --cases "$cases" --filter gc/suspended-stack --budgets 1 --gc-stress --collect-suspended --omit-suspended-root
mutant open-upvalues 'pkg::heap::gc_mark_upvalue(heap: &vm^.heap, h: u);'
mutant frame-closure 'pkg::heap::gc_mark(heap: &vm^.heap, v: f);'
mutant constants 'pkg::heap::gc_mark(heap: &vm^.heap, v: k);'
expect 1 open-upvalues-unmarked compare --binary "$out/mutant-open-upvalues" --cases "$cases" --filter gc/open-upvalues --budgets 1,7,1000 --gc-stress
expect 1 frame-closure-unmarked compare --binary "$out/mutant-frame-closure" --cases "$cases" --filter gc/frame-closure --budgets 1 --gc-stress --isolate-frames
expect 1 constants-unmarked compare --binary "$out/mutant-constants" --budgets 1,7,1000 --gc-stress
exit $status
