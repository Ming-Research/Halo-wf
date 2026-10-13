#!/bin/sh
# The collector's removed-root controls ("Local root witnesses" in ../../research/experiments/halo-gc/README.md):
# the local root cases pass with every root, and each fails once its sole
# root is hidden from the collector or one marking call is removed: a root of
# mark_roots (lib/halo/vm/collect.wf) or an execution field of
# mark_thread_contents (lib/halo/heap/gc.wf), which traces the installed
# execution after collect_if_due parks it in its thread cell. The same harness
# runs the test host's protection controls: the oracle scripts global-write,
# string-metatable-readonly and readonly-library-tables pass, and fail once the
# host leaves the globals table or the shared string metatable writable, or
# marks only those two tables and none reachable from them. An expected
# failure must be detected:
# every FAIL line must be a reply difference (any reason halo-e2e/run.py's
# reason() gives, or a budget-dependent reply) or the engine's own setup
# compile (3), setup runtime (4), budget (5) or host-stop (6) exit; a crash by
# signal, a transport failure (2), any other exit, a timeout, an invalid
# statistic or any other FAIL reason, or a Traceback, rejects the control.
# Pure-shell self-tests of the classifier and of the part selection run first,
# before compiler setup. Mutants build in copies under the scratch directory;
# the working tree is never edited. `make roots` runs all of it:
#   WHITEFOOTC=<compiler> controls.sh <built e2e test program> <scratch directory>
# ROOTS_PART selects what runs, so CI can run the parts as parallel jobs. Every
# check belongs to exactly one part, and the default runs all of them:
#   all (default)    every part, in the order below
#   base             the self-tests (run once, in this part), the four
#                    non-mutant root controls and the six protection
#                    controls; needs the built e2e test program
#   mutant-<label>   one mutant's build and its control, for each label of
#                    `mutants` below; it builds its own program and takes only
#                    the scratch directory:
#   ROOTS_PART=mutant-<label> WHITEFOOTC=<compiler> controls.sh <scratch directory>
#   list             prints the parts, one per line, and runs nothing
# `make roots-base` and `make roots-mutant-<label>` run the parts; the
# Makefile's gate-parts check compares this script's list with its own. An
# unknown part, or a part given the wrong number of arguments, exits 2. Each
# part ends by printing how many controls it ran, and fails when that differs
# from the part's count.
set -u

# The parts this script owns, and the number of controls each runs.
mutants="open-upvalues frame-closure constants"
parts=base
for m in $mutants; do parts="$parts mutant-$m"; done
base_controls=10
mutant_controls=1

part=${ROOTS_PART:-all}
if [ "$part" = list ]; then
  printf '%s\n' $parts
  exit 0
fi

# Whether ROOTS_PART=$1 with $2 arguments is a valid selection: `all` and
# `base` take the e2e test program and the scratch directory, a mutant part
# only the scratch directory. An invalid selection is reported and returns 2.
check_selection() {
  case " all $parts " in
    *" $1 "*) ;;
    *) echo "controls.sh: unknown ROOTS_PART '$1' (all, list or one of: $parts)" >&2; return 2 ;;
  esac
  case "$1" in
    all|base) want_args=2; usage="controls.sh <e2e test program> <scratch directory>" ;;
    *) want_args=1; usage="ROOTS_PART=$1 controls.sh <scratch directory>" ;;
  esac
  if [ "$2" != "$want_args" ]; then
    echo "usage: $usage" >&2; return 2
  fi
  return 0
}

check_selection "$part" "$#" || exit 2

# Whether the selected part includes the named one.
runs() { [ "$part" = all ] || [ "$part" = "$1" ]; }

is_detected_failure() (
  difference=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *Traceback*) return 1 ;;
      "FAIL "*": reply/conversion difference; inspect actual JSON") difference=0 ;;
      "FAIL "*": error text/location difference: "*) difference=0 ;;
      "FAIL "*": unavailable global/library: "*) difference=0 ;;
      "FAIL "*": unsupported test-host command: "*) difference=0 ;;
      "FAIL "*": missing library/host member: "*) difference=0 ;;
      "FAIL "*": runtime/compile error: "*) difference=0 ;;
      "FAIL "*": budget changes reply; "*) difference=0 ;;
      "FAIL "*": native exit "[3456]" ("*) difference=0 ;;
      "FAIL "*) return 1 ;;
    esac
  done
  return "$difference"
)

classifier_self_test() {
  is_detected_failure <<'EOF' || return 1
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
EOF
  if is_detected_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
FAIL gc/frame-closure.lua budget=7 collections=None: native exit -11 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)
EOF
  then return 1; fi
  if is_detected_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
Traceback (most recent call last):
EOF
  then return 1; fi
  if is_detected_failure <<'EOF'
1/1 passed
EOF
  then return 1; fi
  is_detected_failure <<'EOF' || return 1
FAIL apps/hash-cas budget=1 collections=None: native exit 4 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)
EOF
  if is_detected_failure <<'EOF'
FAIL apps/hash-cas budget=1 collections=None: native exit 2 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)
EOF
  then return 1; fi
  is_detected_failure <<'EOF' || return 1
FAIL gc/suspended-stack.lua budget=1 collections=3: runtime/compile error: user_script:1: attempt to index a function value
EOF
  if is_detected_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
FAIL gc/frame-closure.lua budget=7 collections=None: Command '['x']' timed out after 900 seconds
EOF
  then return 1; fi
  if is_detected_failure <<'EOF'
FAIL gc/frame-closure.lua budget=1 collections=1: reply/conversion difference; inspect actual JSON
FAIL gc/frame-closure.lua budget=7 collections=0: stress performed no collection
EOF
  then return 1; fi
  return 0
}

# The selection: an unknown part, a mutant part given no argument or two, and
# `base` given one, are refused with 2; the valid selections are accepted, so
# a check that refused everything fails too.
selection_self_test() {
  first=mutant-${mutants%% *}
  for bad in "unknown-part 1" "unknown-part 2" "mutant-unknown 1" "$first 0" "$first 2" "base 1"; do
    check_selection $bad 2>/dev/null
    got=$?
    if [ "$got" != 2 ]; then
      echo "roots selection self-test: ROOTS_PART=${bad% *} with ${bad#* } arguments returned $got, want 2" >&2
      return 1
    fi
  done
  for good in "all 2" "base 2" "$first 1"; do
    if ! check_selection $good 2>/dev/null; then
      echo "roots selection self-test: ROOTS_PART=${good% *} with ${good#* } arguments was refused" >&2
      return 1
    fi
  done
  return 0
}

if runs base; then
  if ! classifier_self_test; then
    echo "roots classifier self-test: failed" >&2
    exit 1
  fi
  if ! selection_self_test; then
    echo "roots selection self-test: failed" >&2
    exit 1
  fi
  echo "roots self-tests: classifier and selection passed"
fi

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
wfc=${WHITEFOOTC:?set WHITEFOOTC to the Whitefoot compiler}
if runs base; then
  binary=$1; out=$2
else
  out=$1
fi
mkdir -p "$out"
cases=$root/tests/halo-gc/cases
status=0
ran=0
ran_labels=

compare() {
  python3 -B "$root/tests/halo-e2e/run.py" --compiler "$wfc" --scratch-root "$out" "$@"
}

# A control expected to fail must fail by a reply comparison, not a crash.
expect() {
  want=$1; label=$2; shift 2
  ran=$((ran + 1)); ran_labels="$ran_labels $label"
  "$@" > "$out/$label.log" 2>&1
  got=$?
  echo "roots $label: exit $got (want $want), $(grep -E 'passed$' "$out/$label.log" | tail -1)"
  if [ "$got" != "$want" ]; then status=1; cat "$out/$label.log"; return; fi
  if [ "$want" = 1 ]; then
    if ! is_detected_failure < "$out/$label.log"; then
      echo "roots $label: did not fail by a detected result (a reply difference or a setup, budget or stop exit)"; status=1; cat "$out/$label.log"
    fi
  fi
}

mutant() {
  label=$1; file=$2; line=$3
  tree=$out/tree-$label
  rm -rf "$tree"
  mkdir -p "$tree/tests"
  cp -R "$root/lib" "$tree/lib"
  cp -R "$root/tests/halo-e2e" "$tree/tests/halo-e2e"
  grep -vF "$line" "$root/$file" > "$tree/$file"
  removed=$(( $(wc -l < "$root/$file") - $(wc -l < "$tree/$file") ))
  if [ "$removed" != 1 ]; then
    echo "roots mutant $label: removed $removed lines, want 1"; status=1; return
  fi
  if ! (cd "$tree/tests/halo-e2e" && "$wfc" --graph modules.wfg --entry test -o "$out/mutant-$label") > "$out/build-$label.log" 2>&1; then
    echo "roots mutant $label: build failed"; status=1; cat "$out/build-$label.log"
  fi
}

if runs base; then
  expect 0 every-root compare --binary "$binary" --cases "$cases" --budgets 1,7,1000 --gc-stress
  expect 0 frame-sole-root compare --binary "$binary" --cases "$cases" --filter gc/frame-closure --budgets 1 --gc-stress --isolate-frames
  expect 0 parked-sole-root compare --binary "$binary" --cases "$cases" --filter gc/suspended-stack --budgets 1 --gc-stress --collect-suspended
  expect 1 parked-root-hidden compare --binary "$binary" --cases "$cases" --filter gc/suspended-stack --budgets 1 --gc-stress --collect-suspended --omit-suspended-root
  expect 0 globals-read-only compare --binary "$binary" --filter redis-api/global-write --budgets 1,7,1000
  expect 1 globals-writable compare --binary "$binary" --filter redis-api/global-write --budgets 1,7,1000 --omit-global-readonly
  expect 0 string-metatable-read-only compare --binary "$binary" --filter redis-api/string-metatable-readonly --budgets 1,7,1000
  expect 1 string-metatable-writable compare --binary "$binary" --filter redis-api/string-metatable-readonly --budgets 1,7,1000 --omit-string-readonly
  expect 0 library-tables-read-only compare --binary "$binary" --filter redis-api/readonly-library-tables --budgets 1,7,1000
  expect 1 library-tables-writable compare --binary "$binary" --filter redis-api/readonly-library-tables --budgets 1,7,1000 --omit-readonly-recursion
fi

# One mutant part: build the mutant without the given marking call, then run
# its control, which must fail by a detected result. The label names the part,
# the mutant and the control alike, so a part cannot run another's control.
mutant_part() {
  mutant_label=$1; removed_file=$2; removed_line=$3; shift 3
  runs "mutant-$mutant_label" || return 0
  mutant "$mutant_label" "$removed_file" "$removed_line"
  expect 1 "$mutant_label-unmarked" compare --binary "$out/mutant-$mutant_label" "$@"
}

mutant_part open-upvalues lib/halo/heap/gc.wf 'gc_mark_upvalue(heap: heap, h: upvalue);' --cases "$cases" --filter gc/open-upvalues --budgets 1,7,1000 --gc-stress
mutant_part frame-closure lib/halo/heap/gc.wf 'gc_mark(heap: heap, v: frame_function);' --cases "$cases" --filter gc/frame-closure --budgets 1 --gc-stress --isolate-frames
mutant_part constants lib/halo/vm/collect.wf 'pkg::heap::gc_mark(heap: &vm^.heap, v: k);' --budgets 1,7,1000 --gc-stress

# A part whose label has no control line ran none, and a control line whose
# label is not in `mutants` runs only under `all`, which then ran one too many.
case "$part" in
  all) want_ran=$base_controls; for m in $mutants; do want_ran=$((want_ran + mutant_controls)); done ;;
  base) want_ran=$base_controls ;;
  *) want_ran=$mutant_controls ;;
esac
echo "roots part $part: ran $ran controls (want $want_ran):$ran_labels"
if [ "$ran" != "$want_ran" ]; then
  echo "roots part $part: ran $ran controls, want $want_ran"; status=1
fi

# Thread controls are an explicitly selected investigation batch: sample one
# new build before choosing its scale. Positive thread probes always run in
# the ordinary embedding gate, independently of this selection. They run with
# the base part and are not counted among its controls.
if runs base && [ -n "${THREAD_ROOT_MUTANTS:-}" ]; then
  if ! sh "$root/tests/halo-gc/thread-controls.sh" "$out/thread-controls"; then status=1; fi
fi
exit $status
