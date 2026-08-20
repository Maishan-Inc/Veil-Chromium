#!/usr/bin/env python3
"""Cross-platform patch/series consistency check for Veil-Chromium.

Why this exists instead of `devutils/check_patch_files.sh`:

The submodule's `ungoogled-chromium/devutils/check_patch_files.py` compares
`str(path.relative_to(patches_dir))` against the entries in `series`. On Windows `str()` on a
`pathlib.Path` yields backslashes while `series` uses forward slashes, so the set difference removes
nothing and **every** series entry is reported as `Unused patch` — a clean tree exits 1 with 23 false
positives. Verified on Python 3.14.4. CI is unaffected because it runs on ubuntu-latest, where both
sides use `/`.

That is an upstream bug in a pinned submodule, so it is not patched there. This script is
fork-owned, normalizes with `as_posix()`, and gives Stage 5 a local pre-push signal on Windows.

Checks, matching what CI enforces:
  1. unused   — a .patch on disk that no series entry references (build.py silently skips it, so the
                build succeeds and the binary is identical to an unpatched one)
  2. missing  — a series entry with no file behind it
  3. dupes    — the same entry listed twice

Usage:
    python devutils/check_patch_files_local.py                 # fork series + submodule series
    python devutils/check_patch_files_local.py -p patches      # one directory

Exit code 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
_IGNORE_SUFFIXES = {'.md'}


def parse_series(series_path: Path) -> list[str]:
    """Same semantics as the submodule's `_common.parse_series`: drop blank and comment lines,
    strip in-line ` #` comments. Kept local so this script has no submodule import path."""
    lines = series_path.read_text(encoding='UTF-8').splitlines()
    lines = (line for line in lines if line)
    lines = (line for line in lines if not line.startswith('#'))
    return [line.strip().split(' #')[0] for line in lines]


def check(patches_dir: Path, series_name: str = 'series') -> list[str]:
    """Return a list of human-readable problems; empty means clean."""
    series_path = patches_dir / series_name
    if not series_path.is_file():
        return [f'no series file at {series_path}']

    listed = parse_series(series_path)
    on_disk = {
        path.relative_to(patches_dir).as_posix()
        for path in patches_dir.rglob('*')
        if not path.is_dir() and path.suffix not in _IGNORE_SUFFIXES
    }

    problems = []
    for entry in sorted(on_disk - set(listed) - {series_name}):
        problems.append(f'unused patch (not in series, will be SILENTLY SKIPPED): {entry}')
    for entry in listed:
        if not (patches_dir / entry).is_file():
            problems.append(f'series entry has no file: {entry}')
    for entry in sorted({e for e in listed if listed.count(e) > 1}):
        problems.append(f'duplicate series entry: {entry}')
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-p',
                        '--patches',
                        type=Path,
                        action='append',
                        help='Patches directory to check. Repeatable. '
                        'Default: patches and ungoogled-chromium/patches')
    args = parser.parse_args()

    targets = args.patches or [_ROOT / 'patches', _ROOT / 'ungoogled-chromium' / 'patches']
    failed = False
    for target in targets:
        target = target if target.is_absolute() else (Path.cwd() / target)
        if not target.is_dir():
            print(f'SKIP {target} (not a directory)')
            continue
        problems = check(target)
        rel = target.relative_to(_ROOT) if target.is_relative_to(_ROOT) else target
        if problems:
            failed = True
            print(f'FAIL {rel} ({len(problems)} problem(s))')
            for problem in problems:
                print(f'  {problem}')
        else:
            count = len(parse_series(target / 'series'))
            print(f'OK   {rel} ({count} series entries, no unused/missing/duplicate)')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
