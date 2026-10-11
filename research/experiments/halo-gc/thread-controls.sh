#!/bin/sh
# CI-only seeded omissions for the isolated thread probes. The compiler has
# no source-mutation mode, so use the same copy/delete/build method as the
# existing roots controls. Remove with those probes when superseded.
# First select stack; select all only after inspecting the sample build cost.
set -u
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd -P)
wfc=${WHITEFOOTC:?set WHITEFOOTC to the pinned compiler}
out=${1:?usage: thread-controls.sh <scratch directory>}
selection=${THREAD_ROOT_MUTANTS:?select stack first, then named edges or all}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd -P)
tree=$out/tree
rm -rf "$tree"
mkdir -p "$tree/research/experiments"
cp -R "$root/lib" "$tree/lib"
cp -R "$root/research/experiments/halo-e2e" "$tree/research/experiments/halo-e2e"

build() {
  label=$1
  entry=$2
  started=$(date +%s)
  (cd "$tree/research/experiments/halo-e2e" && "$wfc" --graph modules.wfg --entry "$entry" \
    --cache "$out/cache" --fragments function -o "$out/test") > "$out/build-$label.log" 2>&1
  code=$?
  ended=$(date +%s)
  echo "thread roots $label build: exit $code, $((ended - started)) seconds"
  if [ "$code" != 0 ]; then cat "$out/build-$label.log"; return 1; fi
}

if ! build baseline thread_roots; then exit 1; fi
timeout 60 "$out/test" > "$out/baseline.log" 2>&1
code=$?
echo "thread roots baseline: exit $code (want 0)"
if [ "$code" != 0 ]; then cat "$out/baseline.log"; exit 1; fi

status=0
selected=0
while IFS='|' read -r label want entry file line; do
  case ",$selection," in
    *,all,*|*,"$label",*) ;;
    *) continue ;;
  esac
  selected=$((selected + 1))
  # Reset all candidate files so each build contains exactly one omission.
  cp "$root/lib/halo/heap/gc.wf" "$tree/lib/halo/heap/gc.wf"
  cp "$root/lib/halo/heap/threads.wf" "$tree/lib/halo/heap/threads.wf"
  cp "$root/lib/halo/vm/collect.wf" "$tree/lib/halo/vm/collect.wf"
  source=$root/$file
  target=$tree/$file
  grep -vF "$line" "$source" > "$target"
  removed=$(( $(wc -l < "$source") - $(wc -l < "$target") ))
  if [ "$removed" != 1 ]; then
    echo "thread roots $label: removed $removed lines (want 1)"
    status=1
    continue
  fi
  if ! build "$label" "$entry"; then status=1; continue; fi
  timeout 60 "$out/test" > "$out/$label.log" 2>&1
  code=$?
  echo "thread roots $label: exit $code (want isolated observation $want)"
  # Compilation errors, signals, timeouts and unrelated assertions never
  # count as detecting the omitted edge.
  if [ "$code" != "$want" ]; then status=1; cat "$out/$label.log"; fi
done <<'EDGES'
thread|221|thread_roots|lib/halo/heap/gc.wf|mark_thread_contents(heap: heap, ti: ti);
stack|236|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: stack_value);
frame|221|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame_function);
open-list|222|thread_roots|lib/halo/heap/gc.wf|gc_mark_upvalue(heap: heap, h: upvalue);
library-table|223|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.table);
library-comparator|224|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.comparator);
library-error|225|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.saved_error);
library-key|226|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: context.foreach_key);
library-frame|227|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: library_function);
sort-a|228|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.a);
sort-b|229|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.b);
sort-pivot|230|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: frame.pivot);
pattern-source|231|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: source);
pattern-pattern|232|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: pattern);
pattern-replacement|233|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: replacement);
error|234|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: error);
stopped|235|thread_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: stopped_value);
main|213|thread_roots|lib/halo/vm/collect.wf|pkg::heap::gc_mark(heap: &vm^.heap, v: main);
inactive-open-list|240|upvalue_roots|lib/halo/heap/gc.wf|gc_mark_upvalue(heap: heap, h: upvalue);
captured-value|241|upvalue_roots|lib/halo/heap/gc.wf|gc_mark(heap: heap, v: captured);
owner-close|242|upvalue_roots|lib/halo/heap/threads.wf|set heap^.upvalues.inner[ui].payload = Upval::Closed(v: held);
explicit-close|243|upvalue_roots|lib/halo/heap/threads.wf|close_thread_upvalues(heap: heap, h: h);
EDGES
if [ "$selected" = 0 ]; then echo "thread roots: selection names no edge"; exit 1; fi
exit "$status"
