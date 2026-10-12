#!/bin/sh
# CI-only, single-edge omissions. Keep isolated observations and require a
# changed coroutine oracle reply or native crash under collector stress.
# The compiler has no source-mutator mode; copy/delete/build isolates each
# omission. Remove with these research controls when maintained tests replace
# them. Sample stack first, then select a bounded batch after reading its cost.
set -u

# run.py exit 1 includes both semantic differences and infrastructure failures.
# Accept only its explicit reply-difference reasons or native signal crashes.
# Transport/setup/budget exits, malformed output/statistics and timeouts do
# not establish detection. compare() bounds each case at 60 seconds, so a
# looping mutant costs minutes rather than hours; its timeout is no reply.
# A completed run needs at least one valid difference or signal crash; a
# missing baseline or fatal runner exception invalidates it.
is_oracle_detection() (
  difference=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *Traceback*) return 1 ;;
      "FAIL coroutines/"*": reply/conversion difference; inspect actual JSON") difference=0 ;;
      "FAIL coroutines/"*": error text/location difference: "*) difference=0 ;;
      "FAIL coroutines/"*": unavailable global/library: "*) difference=0 ;;
      "FAIL coroutines/"*": unsupported test-host command: "*) difference=0 ;;
      "FAIL coroutines/"*": missing library/host member: "*) difference=0 ;;
      "FAIL coroutines/"*": runtime/compile error: "*) difference=0 ;;
      "FAIL coroutines/"*": budget changes reply; "*) difference=0 ;;
      "FAIL coroutines/"*": native exit -"[1-9]*" (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)") difference=0 ;;
      "FAIL "*) ;;
    esac
  done
  return "$difference"
)

# A fail-stop: every case stops in host setup (native exit 4) and none passes,
# while the baseline passed every case. Removing a root of the running
# execution frees a cell the collector then finds dead; the checked guard ends
# the script before any reply, which is a reply change Redis would not make.
is_fail_stop() (
  stopped=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *Traceback*) return 1 ;;
      [1-9]*/*" passed") return 1 ;;
      "FAIL coroutines/"*": native exit 4 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)") stopped=0 ;;
      "FAIL "*) return 1 ;;
    esac
  done
  return "$stopped"
)

classifier_self_test() {
  printf '%s\n' '0/3 passed' \
    'FAIL coroutines/fixture budget=1 collections=None: native exit 4 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)' \
    | is_fail_stop || return 1
  for invalid in \
    '1/3 passed' \
    'FAIL coroutines/fixture budget=1 collections=None: native exit 3 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)' \
    'FAIL coroutines/fixture budget=1 collections=1: reply/conversion difference; inspect actual JSON'; do
    if printf '%s\n' '0/3 passed' \
      'FAIL coroutines/fixture budget=7 collections=None: native exit 4 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)' \
      "$invalid" | is_fail_stop
    then return 1; fi
  done
  is_oracle_detection <<'EOF' || return 1
FAIL coroutines/fixture budget=1 collections=1: reply/conversion difference; inspect actual JSON
EOF
  is_oracle_detection <<'EOF' || return 1
FAIL coroutines/fixture budget=1 collections=None: native exit -11 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)
EOF
  for invalid in \
    '1/1 passed' \
    'Traceback (most recent call last):' \
    'FAIL coroutines/fixture budget=1 collections=0: stress performed no collection' \
    'FAIL coroutines/fixture budget=1 collections=None: invalid collection count' \
    'FAIL coroutines/fixture budget=1 collections=None: native exit 2 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)' \
    'FAIL coroutines/fixture budget=1 collections=None: native exit 3 (2 transport/I/O, 3 setup compile, 4 setup runtime, 5 budget limit, 6 host stop)' \
    "FAIL coroutines/fixture budget=1 collections=None: Command '['/scratch/oracle-test', 'one', '--gc-stress']' timed out after 60 seconds" \
    'FAIL coroutines/fixture budget=1 collections=None: Expecting value: line 1 column 1 (char 0)'; do
    if is_oracle_detection <<EOF
$invalid
EOF
    then return 1; fi
  done
  is_oracle_detection <<'EOF' || return 1
FAIL coroutines/fixture budget=1 collections=1: reply/conversion difference; inspect actual JSON
FAIL coroutines/fixture budget=7 collections=0: stress performed no collection
EOF
  if is_oracle_detection <<'EOF'
FAIL coroutines/fixture budget=1 collections=1: reply/conversion difference; inspect actual JSON
Traceback (most recent call last):
EOF
  then return 1; fi
  return 0
}

if ! classifier_self_test; then
  echo "coroutine oracle classifier self-test failed" >&2
  exit 1
fi
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd -P)
wfc=${WHITEFOOTC:?set WHITEFOOTC to the pinned compiler}
out=${1:?usage: thread-controls.sh <scratch directory>}
selection=${THREAD_ROOT_MUTANTS:?select stack first, then named edges or all}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd -P)
tree=$out/tree
rm -rf "$tree"
mkdir -p "$tree/research/experiments"
cp -R "$root/lib" "$tree/lib" || exit 1
cp -R "$root/research/experiments/halo-e2e" "$tree/research/experiments/halo-e2e" || exit 1
cp -R "$root/research/experiments/halo-oracle" "$tree/research/experiments/halo-oracle" || exit 1
cp "$root/research/experiments/compiler_cache.py" "$tree/research/experiments/compiler_cache.py" || exit 1
# The copied runner hashes the mutated source and recorded cases. It only
# reads the original git metadata to label the parent revision.
source_git=$(git -C "$root" rev-parse --absolute-git-dir) || exit 1
printf 'edge\tstage\texit\tseconds\tresult\n' > "$out/summary.tsv"

build() {
  build_label=$1
  build_entry=$2
  build_binary=$3
  build_started=$(date +%s)
  (cd "$tree/research/experiments/halo-e2e" && "$wfc" --graph modules.wfg --entry "$build_entry" \
    --cache "$out/cache" --fragments function -o "$build_binary") > "$out/build-$build_label.log" 2>&1
  build_code=$?
  build_ended=$(date +%s)
  build_seconds=$((build_ended - build_started))
  echo "thread controls $build_label build: exit $build_code, $build_seconds seconds"
  printf '%s\tbuild\t%s\t%s\t%s\n' "$build_label" "$build_code" "$build_seconds" \
    "$(if [ "$build_code" = 0 ]; then echo built; else echo build-failed; fi)" >> "$out/summary.tsv"
  if [ "$build_code" != 0 ]; then cat "$out/build-$build_label.log"; return 1; fi
}

# A row's oracle flags are extra run.py options; each distinct set gets its
# own unmutated baseline before any omission is built.
compare() {
  compare_label=$1
  compare_flags=$2
  compare_started=$(date +%s)
  # shellcheck disable=SC2086
  GIT_DIR="$source_git" python3 -B "$tree/research/experiments/halo-e2e/run.py" \
    --compiler "$wfc" --binary "$out/oracle-test" --scratch-root "$out" \
    --filter coroutines/ --budgets 1,7,1000 --gc-stress --case-timeout 60 $compare_flags \
    --actual "$out/actual-$compare_label" --report "$out/oracle-$compare_label.md" \
    > "$out/oracle-$compare_label.log" 2>&1
  compare_code=$?
  compare_ended=$(date +%s)
  compare_seconds=$((compare_ended - compare_started))
  echo "coroutine oracle $compare_label: exit $compare_code, $compare_seconds seconds"
}

# label|probes|file|omitted line|replacement|oracle flags. Every execution
# field has one mark line in mark_thread_contents (lib/halo/heap/gc.wf), which
# traces saved executions and the installed one that collect_if_due parks in
# its cell; collect.wf keeps only the main, current, global, metatable and
# constant roots. probes lists entry:exit isolated observations.
edges() {
  cat <<'EDGES'
thread|thread_roots:221|lib/halo/heap/gc.wf|mark_thread_contents(heap: heap, ti: ti);||
stack|thread_roots:236|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: stack_value);||
frame|thread_roots:221|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame_function);||--isolate-frames
open-list|thread_roots:222 upvalue_roots:240|lib/halo/heap/gc.wf|gc_mark_upvalue(heap: heap, h: upvalue);||
library-table|thread_roots:223|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.table);||
library-comparator|thread_roots:224|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.comparator);||
library-error|thread_roots:225|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.saved_error);||
library-key|thread_roots:226|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.foreach_key);||
library-frame|thread_roots:227|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: library_function);||
sort-a|thread_roots:228|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.a);||
sort-b|thread_roots:229|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.b);||
sort-pivot|thread_roots:230|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.pivot);||
pattern-source|thread_roots:231|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: source);||
pattern-pattern|thread_roots:232|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: pattern);||
pattern-replacement|thread_roots:233|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: replacement);||
error|thread_roots:234|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: error);||
stopped|thread_roots:235|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: stopped_value);||
main|thread_roots:213|lib/halo/vm/collect.wf|pkg::heap::gc_mark(heap: &vm^.heap, v: main);||
current-thread|switch_roots:46|lib/halo/vm/collect.wf|pkg::heap::gc_mark(heap: &vm^.heap, v: current);||
captured-value|upvalue_roots:241|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: captured);||
owner-close|upvalue_roots:242|lib/halo/heap/threads.wf|set heap^.upvalues.inner[ui].payload = Upval::Closed(v: held);|set heap^.upvalues.inner[ui].live = heap^.upvalues.inner[ui].live;|
explicit-close|upvalue_roots:243|lib/halo/heap/threads.wf|close_thread_upvalues(heap: heap, h: h);||
thread-entry|switch_roots:40|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: entry_value);||
resumer|switch_roots:41|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: resumer_value);||
transfer-child|switch_roots:42|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: transfer_child);||
transfer-arguments|switch_roots:43|lib/halo/heap/gc.wf|set limit = transfer_extent;||
EDGES
}

edges > "$out/edges" || exit 1
selected_flags() {
  while IFS='|' read -r label probes file line replacement flags; do
    case ",$selection," in
      *,all,*|*,"$label",*) [ -n "$flags" ] && printf '%s\n' "$flags" ;;
    esac
  done < "$out/edges" | sort -u
}

# Baseline transport, canonical recordings and collection counts must all pass
# before a mutation can be credited, with every flag set a selected row uses.
# Missing new Redis recordings fail here.
if ! build baseline-oracle test "$out/oracle-test"; then exit 1; fi
baseline() {
  baseline_label=baseline$(printf '%s' "$1" | tr -c 'a-z0-9' '-')
  compare "$baseline_label" "$1"
  printf '%s\toracle\t%s\t%s\tbaseline\n' "$baseline_label" "$compare_code" "$compare_seconds" >> "$out/summary.tsv"
  if [ "$compare_code" != 0 ]; then cat "$out/oracle-$baseline_label.log"; return 1; fi
}
baseline '' || exit 1
selected_flags | while IFS= read -r baseline_flags; do
  baseline "$baseline_flags" || exit 1
done || exit 1
if ! build baseline-probe thread_roots "$out/probe-test"; then exit 1; fi
timeout 60 "$out/probe-test" > "$out/baseline-probe.log" 2>&1
code=$?
echo "thread roots baseline: exit $code (want 0)"
printf 'baseline\tprobe\t%s\t-\tbaseline\n' "$code" >> "$out/summary.tsv"
if [ "$code" != 0 ]; then cat "$out/baseline-probe.log"; exit 1; fi

status=0
selected=0
while IFS='|' read -r label probes file line replacement flags; do
  case ",$selection," in
    *,all,*|*,"$label",*) ;;
    *) continue ;;
  esac
  selected=$((selected + 1))
  # Reset every candidate file: each binary has exactly one omitted operation.
  cp "$root/lib/halo/heap/gc.wf" "$tree/lib/halo/heap/gc.wf" || exit 1
  cp "$root/lib/halo/heap/threads.wf" "$tree/lib/halo/heap/threads.wf" || exit 1
  cp "$root/lib/halo/vm/collect.wf" "$tree/lib/halo/vm/collect.wf" || exit 1
  source=$root/$file
  target=$tree/$file
  matches=$(grep -cF "$line" "$source")
  if [ "$matches" != 1 ]; then
    echo "thread roots $label: matched $matches lines (want 1)"
    printf '%s\tmutation\t-\t-\tanchor-failed\n' "$label" >> "$out/summary.tsv"
    status=1
    continue
  fi
  # Preserve declared write effects where deletion alone would cause EFF-2.
  if [ -n "$replacement" ]; then
    LINE=$line REPLACEMENT=$replacement awk '{ i = index($0, ENVIRON["LINE"]); if (i > 0) print substr($0, 1, i - 1) ENVIRON["REPLACEMENT"]; else print }' "$source" > "$target"
  else
    grep -vF "$line" "$source" > "$target"
  fi
  diff -u "$source" "$target" > "$out/omission-$label.diff"
  if build "$label-oracle" test "$out/oracle-test"; then
    compare "$label" "$flags"
    result=inconclusive
    if [ "$compare_code" = 0 ]; then
      result=survived
    elif [ "$compare_code" = 1 ] && [ -s "$out/oracle-$label.md" ] && \
         is_oracle_detection < "$out/oracle-$label.log"; then
      result=detected
    elif [ "$compare_code" = 1 ] && [ -s "$out/oracle-$label.md" ] && \
         is_fail_stop < "$out/oracle-$label.log"; then
      result=fail-stop
    fi
    echo "coroutine oracle $label: $result (requires a reply difference, native crash or fail-stop in setup)"
    printf '%s\toracle\t%s\t%s\t%s\n' "$label" "$compare_code" "$compare_seconds" "$result" >> "$out/summary.tsv"
    case "$result" in detected|fail-stop) ;; *) status=1; cat "$out/oracle-$label.log" ;; esac
  else
    status=1
  fi
  # Keep each established isolated observation, entry:exit; it is additional
  # evidence, never a substitute for the oracle result.
  for probe in $probes; do
    entry=${probe%%:*}
    want=${probe#*:}
    if ! build "$label-$entry" "$entry" "$out/probe-test"; then status=1; continue; fi
    probe_started=$(date +%s)
    timeout 60 "$out/probe-test" > "$out/probe-$label-$entry.log" 2>&1
    code=$?
    probe_ended=$(date +%s)
    echo "thread roots $label $entry: exit $code (want isolated observation $want)"
    printf '%s\tprobe\t%s\t%s\texpected-%s\n' "$label-$entry" "$code" "$((probe_ended - probe_started))" "$want" >> "$out/summary.tsv"
    if [ "$code" != "$want" ]; then status=1; cat "$out/probe-$label-$entry.log"; fi
  done
done < "$out/edges"
if [ "$selected" = 0 ]; then echo "thread roots: selection names no edge"; exit 1; fi
exit "$status"
