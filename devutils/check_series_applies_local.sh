#!/usr/bin/env bash
# Whole-series apply check — the one operation the build performs that the per-patch loop never does.
#
# `Veil/docs/MIGRATION-UNGOOGLED.md` 5.2 step 4 dry-runs ONE patch at a time against the live build
# tree, which is the right check while porting. It is not the check the build makes: `build.py` applies
# `patches/series` in order to a FRESH Chromium checkout, so an ordering conflict between two veil
# patches surfaces there and only there — in CI, after hours of runner time.
#
# This reproduces it locally without a build. Take a scratch copy of every file the veil block touches,
# reverse the block in REVERSE order to reach the post-upstream / pre-veil state, then apply the whole
# block FORWARD in series order. Both passes must be clean, and the result must come back
# byte-identical to the live build tree.
#
# Reversing in reverse order is the part that matters. Reversing a patch on its own against the fully
# patched tree fails legitimately whenever a later patch edits the same region — 002/012 do, and so do
# 015/915 and 002/902 (5.1q). In strict reverse order every patch sees the tree it was written against.
#
# Fuzz, rejects and non-zero exits are findings. OFFSETS ARE NOT: `patch` resolves line-number shifts
# silently, and the ones here are inherent, because a veil patch records the line numbers of the tree it
# was generated against while this tree also carries the 23 windows patches and the submodule's 108.
# They are collected and printed as data, since a growing offset is a hint that a patch is worth
# regenerating even though nothing is broken.
#
# Scope is the `veil/` block. The upstream blocks are already exercised end to end by every CI build,
# including the zero-patch `151.0.7922.137-1.1000` release.
#
# Local only, like devutils/check_patch_files_local.py: it needs a checked-out, fully patched
# build/src, which CI does not have at lint time.
#
#   usage: devutils/check_series_applies_local.sh [<build-src-dir>] [<scratch-dir>]
set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
SRC=${1:-$REPO/build/src}
WORK=${2:-${TMPDIR:-/tmp}/veil-series-apply-check}
FLAGS="-p1 --ignore-whitespace --no-backup-if-mismatch"

if [ ! -d "$SRC" ]; then
  echo "no build tree at $SRC — pass one as \$1" >&2; exit 2
fi

mapfile -t SERIES < <(grep '^veil/' "$REPO/patches/series")
mapfile -t FILES < <(for p in "${SERIES[@]}"; do grep '^+++ b/' "$REPO/patches/$p"; done \
                     | sed 's|^+++ b/||' | sort -u)
if [ ${#SERIES[@]} -eq 0 ]; then echo "no veil/ entries in patches/series" >&2; exit 2; fi

echo "series entries: ${#SERIES[@]}   files touched: ${#FILES[@]}"
echo "build tree:     $SRC"
rm -rf "$WORK"; mkdir -p "$WORK"
for f in "${FILES[@]}"; do
  if [ ! -e "$SRC/$f" ]; then echo "  !! missing from the build tree: $f"; exit 2; fi
  mkdir -p "$WORK/$(dirname "$f")"
  cp "$SRC/$f" "$WORK/$f"
done

fail=0
offsets=""
check() { # <label> <patch-output>
  local label=$1 out=$2
  if grep -qE "fuzz|FAILED|Reversed|Skipping|misordered|malformed|Only garbage" <<<"$out"; then
    echo "  !! $label"; sed 's/^/     /' <<<"$out"; fail=1
  fi
  local o
  o=$(grep -oE "offset -?[0-9]+ lines" <<<"$out" | tr '\n' ' ')
  [ -n "$o" ] && offsets="$offsets\n  $(printf '%-58s' "$label")$o"
}

echo
echo "--- reverse pass (series order reversed) ---"
for (( i=${#SERIES[@]}-1 ; i>=0 ; i-- )); do
  p=${SERIES[$i]}
  out=$(patch -R $FLAGS -d "$WORK" -i "$REPO/patches/$p" 2>&1); rc=$?
  printf "  %-58s rc=%d\n" "$p" "$rc"
  [ $rc -ne 0 ] && { echo "  !! reverse failed"; sed 's/^/     /' <<<"$out"; fail=1; }
  check "reverse $p" "$out"
done

echo
echo "--- forward pass (series order) ---"
for p in "${SERIES[@]}"; do
  out=$(patch $FLAGS -d "$WORK" -i "$REPO/patches/$p" 2>&1); rc=$?
  printf "  %-58s rc=%d\n" "$p" "$rc"
  [ $rc -ne 0 ] && { echo "  !! forward failed"; sed 's/^/     /' <<<"$out"; fail=1; }
  check "forward $p" "$out"
done

echo
echo "--- result vs the live build tree ---"
diffs=0
for f in "${FILES[@]}"; do
  if ! diff -q "$WORK/$f" "$SRC/$f" >/dev/null 2>&1; then
    echo "  DIFFERS  $f"; diffs=$((diffs+1)); fail=1
  fi
done
echo "  ${#FILES[@]} files compared, $diffs differ"

leftovers=$(find "$WORK" \( -name '*.rej' -o -name '*.orig' \) 2>/dev/null)
if [ -n "$leftovers" ]; then
  echo "  !! rejects/backups left behind:"; sed 's/^/     /' <<<"$leftovers"; fail=1
fi

echo
echo "--- offsets seen (informational: line-number shifts, not fuzz) ---"
printf "%b\n" "$offsets" | sed '/^$/d'
echo
if [ $fail -eq 0 ]; then
  echo "RESULT: clean — the whole veil series applies from scratch, zero fuzz, no rejects"
else
  echo "RESULT: FINDINGS above"
fi
exit $fail
