# Veil-Chromium

The browser engine for [Veil][veil]. Derived from
[`ungoogled-software/ungoogled-chromium-windows`][ucw], carrying Veil's fingerprint patch set and
publishing Windows x64 builds to GitHub Releases.

Not a GitHub fork — a standalone repository whose `main` carries upstream's history via an `upstream`
remote. There is no "Sync fork" button; rebasing is `git fetch upstream` plus an explicit commit,
which is what the version policy wants anyway. Upstream's BSD-3 `LICENSE` is preserved in the tree.

Veil itself contains no browser code and no fingerprint logic. All spoofing lives here, in C++
patches, because a JavaScript-level spoof self-reveals through `Function.prototype.toString` and is
worse than no spoof. The only coupling between the two repositories is
`Veil/crates/runtime/engine.toml` — which release to download — and the launch-switch vocabulary.

**Current state: zero Veil patches.** This is Stage 4 of `Veil/docs/MIGRATION-UNGOOGLED.md`: stand up
the pipeline and prove it produces a build functionally identical to upstream. Builds from this
repository today are stock ungoogled-chromium. `engine.toml` therefore declares
`flag_dialect = "stock-chromium"`, and it must keep declaring that until the Tier 1 patches have
landed *and* been verified against the detection baseline. The dialect is what tells Veil which
switches it may emit; declaring a capability that does not exist makes Veil report profiles as
protected when they are not.

## Base point

Everything below is the exact pinning, not a summary of it.

| What | Value |
|---|---|
| Upstream repository | `ungoogled-software/ungoogled-chromium-windows` (remote `upstream`) |
| Upstream tag this is based on | `151.0.7922.137-1.1` |
| `ungoogled-chromium` submodule commit | `e241025306a6cbe3cc31d55f0c31544d6106fade` |
| Submodule URL (`.gitmodules`) | `https://github.com/Eloston/ungoogled-chromium.git` (org redirect to `ungoogled-software`; still resolves) |
| `ungoogled-chromium/chromium_version.txt` | `151.0.7922.137` |
| `ungoogled-chromium/revision.txt` (release revision) | `1` — unchanged from upstream |
| `revision.txt` (packaging revision, this repo) | `1000` — Veil's marker, see below |

**The submodule commit is what pins the Chromium version.** Not `revision.txt`: the two revision
files carry only the ungoogled release revision and the packaging revision. A rebase onto a new
Chromium major is a submodule bump plus, usually, patch conflicts — an explicit reviewed commit,
never a silent `git submodule update --remote`.

```bash
git clone https://github.com/Maishan-Inc/Veil-Chromium.git
cd Veil-Chromium
git remote add upstream https://github.com/ungoogled-software/ungoogled-chromium-windows.git
git submodule update --init
git -C ungoogled-chromium rev-parse HEAD   # must print e2410253…
```

## Version and tag scheme

`package.py` composes the release version from **three files, not from the git tag**:

```
ungoogled-chromium_<chromium_version>-<release_revision>.<packaging_revision>_windows_x64.zip
                    │                  │                  └─ revision.txt (this repo)      = 1000
                    │                  └───────────────────── ungoogled-chromium/revision.txt = 1
                    └──────────────────────────────────────── ungoogled-chromium/chromium_version.txt
```

So this fork builds and tags:

```
tag    151.0.7922.137-1.1000
asset  ungoogled-chromium_151.0.7922.137-1.1000_windows_x64.zip
```

Veil's marker is `1000` in the **packaging** revision, and the position matters for three reasons:

1. It lives in this repository's own `revision.txt`. Marking the *release* revision instead would
   mean committing inside the `ungoogled-chromium` submodule — a second fork and a `.gitmodules`
   change — and if you edited only the tag, `package.py` would still name the asset `-1.1` while the
   release said `-1.1000`.
2. Upstream's packaging revision counts rebuilds of one Chromium version and stays a small integer,
   so `1000` cannot collide.
3. **It is numeric.** Veil's `version_regex` requires digits after the `-`, and its `version_key`
   ordering parses every component with `unwrap_or(0)`. A prettier tag like `151.0.7922.137-veil.1`
   matches nothing at all: Veil finds no candidate, the Browser page shows an empty list, and that
   looks exactly like a network failure. This is asserted by
   `manifest::tests::version_regex_{accepts_the_veil_fork_tag_scheme,rejects_alphabetic_fork_tag_schemes}`
   and `provider::tests::veil_fork_tag_sorts_above_the_upstream_tag_it_forked_from` in the Veil repo.

`.github/workflows/lint-patches.yml` fails a tagged push whose tag disagrees with the three files.

## Patches

`patches/veil/` — currently a README and nothing else. Read
[`patches/veil/README.md`](patches/veil/README.md) before adding anything: a patch file that is not
appended to `patches/series` is **silently skipped**, the build succeeds, and the binary is
identical to an unpatched one.

Apply order is: the submodule's series, then this repo's `patches/series`, in file order.

Attribution for every ported patch is mandatory and is a licensing requirement — see
[`CREDITS.md`](CREDITS.md).

## Build and release

Free GitHub-hosted runners; no build machine.

- `build-x64.yml` → `reusable-build.yml`, **16 chained `build-*` jobs** on `windows-2022`, each
  handing the Chromium `out` directory to the next as an artifact because a single job caps at
  6 hours. Do not "simplify" this structure; it is the workaround, not accidental complexity.
- Trigger: **push a tag.** `publish-release.yml` requires `workflow_run.event == 'push'`, so a build
  started with `workflow_dispatch` will not publish. `workflow_dispatch` is kept only as a manual
  escape hatch for re-publishing an already-built tag.
- `publish-release.yml` (x64 only in this fork — see its header for what was removed and why)
  collects the artifact, generates `SHA256SUMS`, signs it if `VEIL_GPG_PRIVATE_KEY` is configured,
  and creates the Release.
- `lint-patches.yml` runs on every push. Cheap: submodule checkout plus Python.

`x86` and `arm` are not built. Veil is Windows-x64-only, and upstream's publish gate treated a
missing architecture as "not publishable" without logging an error.

### Wall-clock

Measured per release and recorded here; do not carry an estimate forward as if it were data.

| Tag | 16 build stages | `publish-release` | Total | Notes |
|---|---|---|---|---|
| `151.0.7922.137-1.1000` | _todo_ | _todo_ | _todo_ | first smoke build, zero Veil patches |

`Veil/docs/ENGINE.md` sizes the Stage 7 rebase cadence off this number.

### Verifying a release without trusting GitHub

```bash
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum -c SHA256SUMS
```

Veil's own downloader does not use `SHA256SUMS`: it takes the SHA-256 from the GitHub API's
per-asset `digest` field (`checksum_source = "asset_digest"`), which is computed by GitHub rather
than by the publisher. `SHA256SUMS` exists so a user can verify independently of GitHub. Both must
agree; if they ever disagree, do not install the build.

## Licensing

BSD-3-Clause, inherited from Chromium and ungoogled-chromium. See [`CREDITS.md`](CREDITS.md) for
per-project attribution and [`LICENSE`](LICENSE) for the notice. The Veil management application is
MIT and shares no code with this repository.

[ucw]: https://github.com/ungoogled-software/ungoogled-chromium-windows
[veil]: https://github.com/Maishan-Inc/Veil
