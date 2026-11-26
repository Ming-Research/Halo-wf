#!/bin/sh
# The build kept per work for Halo's fast runs on the 14900k, which every
# runner of that machine reaches, since they all run as one user with one home
# directory. fast.yml and fast-state.yml run it; nothing else does.
#
# A work's state is $HOME/fast-state/Halo-wf/<work>/ (manual/ for a run a
# person asks for, with no work): build/, the Makefile's HALO_BUILD (the
# compiler's download, the test programs and the reference Lua), and cache/,
# WHITEFOOT_CACHE (the compiler's cache). main/ is the same for main, which
# fast-state.yml brings up to date after each push to main, and from which a
# work's first run starts.
#
#   fast-state.sh use WORK       prints the work's directory, made from main/
#                                where it is not there yet, and marks it used
#   fast-state.sh lock DIR CMD…  runs CMD holding DIR's lock
#   fast-state.sh warm-begin     makes main-next/ from main/, to build into
#   fast-state.sh warm-end       makes main-next/ the new main/
#   fast-state.sh clean          removes each work's directory unused for 24 h
#
# Two runs of one work at once take turns: each step that writes the
# directory holds an exclusive flock on <dir>.lock. A copy of main/ holds a
# shared flock on main.lock, and warm-end swaps main/ under an exclusive one.
# The lock files stay, so a run that waits on one never holds a lock another
# run cannot see.
set -eu

root=$HOME/fast-state/Halo-wf
# How long a work's directory may go unused before clean removes it, in
# minutes.
unused_minutes=1440

mkdir -p "$root"

case "${1:-}" in
use)
  work=${2:-}
  case "$work" in
    '') name=manual ;;
    main|main-next|.*|*[!A-Za-z0-9._-]*)
      echo "fast-state: '$work' is not a work's name (letters, digits, '.', '_' and '-')" >&2; exit 2 ;;
    *) name=$work ;;
  esac
  dir=$root/$name
  flock "$dir.lock" sh -eu -c '
    dir=$1; root=$2
    if [ ! -d "$dir" ]; then
      rm -rf "$dir.part"
      if [ -d "$root/main" ]; then
        flock -s "$root/main.lock" cp -a "$root/main" "$dir.part"
        echo "fast-state: $dir starts from main" >&2
      else
        mkdir -p "$dir.part"
        echo "fast-state: $dir starts empty; main has no build yet" >&2
      fi
      mv "$dir.part" "$dir"
    fi
    mkdir -p "$dir/build" "$dir/cache"
    touch "$dir/last-used"
  ' sh "$dir" "$root"
  echo "$dir"
  ;;
lock)
  dir=$2; shift 2
  exec flock "$dir.lock" "$@"
  ;;
warm-begin)
  rm -rf "$root/main-next"
  if [ -d "$root/main" ]; then
    flock -s "$root/main.lock" cp -a "$root/main" "$root/main-next"
  fi
  mkdir -p "$root/main-next/build" "$root/main-next/cache"
  echo "$root/main-next"
  ;;
warm-end)
  rm -rf "$root/main-old"
  flock "$root/main.lock" sh -eu -c '
    root=$1
    if [ -d "$root/main" ]; then mv "$root/main" "$root/main-old"; fi
    mv "$root/main-next" "$root/main"
  ' sh "$root"
  rm -rf "$root/main-old"
  touch "$root/main/last-used"
  echo "fast-state: main is up to date"
  ;;
clean)
  for dir in "$root"/*; do
    [ -d "$dir" ] || continue
    case "${dir##*/}" in main|main-next) continue ;; esac
    stamp=$dir/last-used
    [ -e "$stamp" ] || stamp=$dir
    if [ -n "$(find "$stamp" -maxdepth 0 -mmin +"$unused_minutes")" ]; then
      lock=${dir%.part}.lock
      if flock -n "$lock" rm -rf "$dir"; then
        echo "fast-state: removed $dir, unused for $unused_minutes minutes"
      else
        echo "fast-state: $dir is in use; it stays"
      fi
    fi
  done
  ;;
*)
  echo "usage: fast-state.sh use WORK | lock DIR CMD... | warm-begin | warm-end | clean" >&2
  exit 2
  ;;
esac
