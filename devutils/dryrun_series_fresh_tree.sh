#!/usr/bin/env bash
# Per-patch dry-run against a FRESH tree — the T25 (rebase) pre-flight.
#
# check_series_applies_local.sh needs a checked-out, fully patched build/src, which a fresh
# extract does not have until build.py runs. This script is the other half: point it at a tree
# and it dry-runs series entries one patch at a time with --fuzz=0, so a patch whose context
# moved reports itself instead of applying with fuzz and silently degrading.
#
# Prerequisite: the tree must already carry everything the probed entries anchor on. For a
# fresh extract that means build.py's patch stage has run for the blocks BELOW the one you
# probe — apply order is submodule series (108) → fork Windows series (23) → patches/veil/ —
# so probe `veil` against a tree that has the first two blocks applied (build.py stops there
# on its own when the compile is not requested, or `quilt push -a` under
# devutils/set_quilt_vars.sh). The `veil` scope is the rebase case: the upstream blocks are
# already exercised end to end by CI, and the conflicts T25 expects live in the veil block.
#
# It is a measurement, not a build step: nothing is written to the tree (--dry-run throughout).
#
#   usage: devutils/dryrun_series_fresh_tree.sh <tree-dir> [veil]
#
#     <tree-dir>  the Chromium source tree to probe (e.g. build/src after a fresh extract)
#     [veil]      optional; restrict to the `veil/` block (default: the whole series)
#
# Output: one line per entry — `PASS`/`FAIL`/`MISS` (target absent from the tree) — plus the
# failing hunks of every FAIL. Exit 0 only when every probed entry applies with zero fuzz.
set -u

if [ $# -lt 1 ]; then
  echo "usage: $0 <tree-dir> [veil]" >&2
  exit 2
fi

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TREE=$1
SCOPE=${2:-all}
FLAGS="-p1 --ignore-whitespace --no-backup-if-mismatch --dry-run --fuzz=0"

if [ ! -d "$TREE" ]; then
  echo "no tree at $TREE" >&2
  exit 2
fi

if [ "$SCOPE" = "veil" ]; then
  mapfile -t SERIES < <(grep '^veil/' "$REPO/patches/series")
else
  mapfile -t SERIES < <(grep -v '^#' "$REPO/patches/series" | grep -v '^[[:space:]]*$')
fi

if [ ${#SERIES[@]} -eq 0 ]; then
  echo "no series entries matched scope '$SCOPE'" >&2
  exit 2
fi

echo "tree:   $TREE"
echo "scope:  $SCOPE (${#SERIES[@]} entries)"
echo

fails=0
missing=0
for entry in "${SERIES[@]}"; do
  patch_file="$REPO/patches/$entry"
  if [ ! -f "$patch_file" ]; then
    echo "MISS  $entry (no such file)"
    missing=$((missing + 1))
    continue
  fi
  output=$(patch $FLAGS -d "$TREE" -i "$patch_file" 2>&1)
  status=$?
  if [ $status -eq 0 ] && ! grep -q "with fuzz" <<<"$output"; then
    echo "PASS  $entry"
  else
    echo "FAIL  $entry (exit $status)"
    grep -E "FAILED|fuzz|Reject|can't find file|No such file" <<<"$output" | sed 's/^/      /'
    fails=$((fails + 1))
  fi
done

echo
echo "summary: ${#SERIES[@]} probed, $fails failed, $missing missing"
[ $fails -eq 0 ] && [ $missing -eq 0 ]
