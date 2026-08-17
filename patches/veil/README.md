# `patches/veil/` — Veil's fingerprint patch set

Empty on purpose. Stage 4 of `Veil/docs/MIGRATION-UNGOOGLED.md` stands up the build pipeline and
ships **zero** Veil patches, so that when the build breaks it is unambiguous whether the cause was
a patch or the CI. The Tier 1 patches land in Stage 5, one patch per CI build per baseline run.

## The rule that will bite you: append to `patches/series`

`build.py` applies two series, in this order:

1. `ungoogled-chromium/patches` — the submodule's own series (core de-Googling)
2. `patches/` — this repo's series

`patches/series` is a flat list of paths relative to `patches/`. Note the trap in the existing
entries: there is a directory *inside* `patches/` literally named `ungoogled-chromium/windows/`.
It is a plain directory, not the submodule.

A Veil patch is registered by **appending** its path to the end of `patches/series`:

```
ungoogled-chromium/windows/windows-fix-unsupported-llvm-flags.patch
veil/000-add-fingerprint-switches.patch
veil/001-disable-runtime-enable.patch
```

Appending is what makes Veil patches apply after both upstream series. Order within the file is
the apply order.

**A `.patch` file in this directory that is not listed in `series` is silently ignored.** `build.py`
calls `generate_patches_from_series(..., resolve=True)`, which resolves only the entries it is
given; an unlisted file is never applied and nothing warns you. The build succeeds and produces a
binary identical to an unpatched one. `.github/workflows/lint-patches.yml` exists solely to catch
this — it runs the submodule's `check_patch_files.py`, whose `check_unused_patches` walks `patches/`
and fails on any file missing from `series`. `.md` files are exempt, which is why this README
needs no entry.

Do not rely on the build to tell you. Run the linter, and confirm the patch's *effect* against
`Veil/tools/detection-baseline/` — a patch whose hook moved to a different call path still applies
cleanly and does nothing.

## Every patch records its origin in its own header

Non-negotiable, and it is a licensing requirement, not a courtesy. Chromium,
ungoogled-chromium, `adryfish/fingerprint-chromium` and `clearcotelabs/clearcote-browser` are all
BSD-3: their patches may be ported with the copyright notice retained. See `CREDITS.md` for the
project-level attribution; per-patch provenance goes in the patch file itself:

```
# Origin:  adryfish/fingerprint-chromium
# Source:  patches/extra/fingerprint/003-audio-fingerprint.patch
# Commit:  <sha the patch was taken from>
# License: BSD-3-Clause (see CREDITS.md)
# Changes: rebased onto 151.0.7922.137; renamed --fingerprint-audio to --veil-audio-noise
#
# <what the patch does, in one or two sentences>
```

A ported patch with no `Origin` line is a licensing defect and should be rejected in review.

## Naming

Mirror the numeric prefixes in `Veil/docs/ENGINE.md` → Tier 1 so the mapping between the plan and
the repo stays mechanical: `000-add-fingerprint-switches.patch`, `003-audio-fingerprint.patch`,
`012-canvas-get-image-data.patch`, and so on. `000` must land first — nothing else works without
the switch plumbing.

## A switch may not exist before its patch

`Veil/crates/runtime/engine.toml` declares `flag_dialect`. Under `veil-patched`,
`veil_core::to_engine_args` emits `--fingerprint=<seed>` and the per-surface switches. Chromium
ignores unknown switches silently, so a switch Veil emits without a patch behind it produces a
profile the UI reports as protected and that leaks everything. That is the exact bug Stage 1 of the
migration removed.

The dialect stays `stock-chromium` until all of Tier 1 has landed **and** been verified against the
detection baseline. Each new switch spelling is introduced in the same commit as the patch that
implements it.
