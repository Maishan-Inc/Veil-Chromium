# Credits

`Veil-Chromium` is a fork of [`ungoogled-software/ungoogled-chromium-windows`][ucw] carrying Veil's
fingerprint patch set. Almost nothing here is original browser engineering; it is Chromium plus other
people's de-Googling and anti-fingerprinting work, rebased and extended. The exception is the small
`9NN` range in `patches/veil/`, which is Veil's own — see **Veil** below.

Per-patch provenance lives in each patch's own header comment (`Origin`, `Source`, `Commit`,
`License`, `Changes`) — see `patches/veil/README.md`. This file is the project-level attribution.

## Chromium

[The Chromium Project][chromium] — Copyright The Chromium Authors. BSD-3-Clause.

The engine. Its own `LICENSE` and the generated third-party license file ship inside every build
artifact; nothing in this repo relicenses them.

## ungoogled-chromium

[`ungoogled-software/ungoogled-chromium`][uc] — Copyright The ungoogled-chromium Authors.
BSD-3-Clause. Vendored as the `ungoogled-chromium` git submodule.

The base patch set: removal of Google-integrated background services, of binaries lacking source,
and of URL-fetching triggers, plus the switches that make the remainder controllable. Its series is
applied first, before anything in this repo's `patches/`.

## ungoogled-chromium-windows

[`ungoogled-software/ungoogled-chromium-windows`][ucw] — Copyright The ungoogled-chromium Authors.
BSD-3-Clause. This repository is a fork of it.

The Windows build: `build.py`, `package.py`, `flags.windows.gn`, the 23 `windows-*.patch` files,
and the 16-stage GitHub Actions pipeline that fits a Chromium build into free 6-hour runners. The
CI trim in this fork is documented in the header of
`.github/workflows/publish-release.yml`.

## fingerprint-chromium

[`adryfish/fingerprint-chromium`][fc] — BSD-3-Clause.

Source of the Tier 1 patch set: switch registration and seed plumbing, UA/UA-CH coherence, audio,
canvas (`getImageData`, `toDataURL`, `measureText`), `getClientRects`, WebGL `readPixels`, GPU info,
font enumeration, `hardwareConcurrency`, timezone-as-a-switch, and the `navigator.webdriver` /
headless / `Runtime.enable` surfaces.

## clearcote-browser

[`clearcotelabs/clearcote-browser`][cc] — BSD-3-Clause.

Source of the Tier 2 patch set: `screen` and media queries, `mediaDevices`, `mediaCapabilities`,
speech voices, device sensors, `getBattery`, `navigator.connection`, keyboard layout, storage quota,
`performance.memory`, geolocation, WebGPU coherence, and the TLS JA3/JA4 + HTTP/2 persona. Its
dedicated coherence patches (`092-language-locale-coherence`, `075-webgpu-coherence`,
`160-coherence-misc`) are the reference for keeping surfaces from contradicting each other.

## Brave

[Brave Browser][brave] — MPL-2.0.

No Brave code is ported. Brave's **per-site deterministic farbling** is the design model Veil
follows for keeping a persona stable per origin while remaining unique across origins. Credited as
prior art for the approach, not as a code dependency.

## Veil

[`Maishan-Inc/Veil-Chromium`][self] — BSD-3-Clause, the same terms as the code these patches edit.

The `9NN` patches in `patches/veil/` are Veil-authored and have no upstream counterpart. They exist
because a ported patch is kept byte-identical to its source — that is what its `Origin` / `Source` /
`Commit` header asserts — so a correction to one lives in its own file instead. Each declares
`Origin: none -- Veil-authored` explicitly and cites the measurement that justifies it; the numbering
rule (`9NN` corrects `0NN`, `950`–`999` for patches with no ported counterpart) is in
`patches/veil/README.md`.

Present in this range today: `915-canvas-measure-text-multiplier-and-worker`, which fixes two measured
defects in `015` — a multiplicative `TextMetrics::Shuffle()` call site handed an additive noise value,
and a realm test that left a Worker's `OffscreenCanvas` unspoofed.

## Notes on licensing

- Chromium, ungoogled-chromium, ungoogled-chromium-windows, fingerprint-chromium and
  clearcote-browser are all BSD-3-Clause. Porting their patches is permitted with the copyright
  notice retained, which is what the per-patch `Origin` / `License` headers exist to do.
- Brave is MPL-2.0 and is credited for a design idea only. If Brave source is ever ported, MPL-2.0
  file-level obligations apply and that patch must say so in its header.
- The Veil management application ([`Maishan-Inc/Veil`][veil]) is MIT. Distributing this Chromium
  fork does not change that; the two repositories share no code.

[brave]: https://github.com/brave/brave-core
[cc]: https://github.com/clearcotelabs/clearcote-browser
[chromium]: https://chromium.googlesource.com/chromium/src/
[fc]: https://github.com/adryfish/fingerprint-chromium
[self]: https://github.com/Maishan-Inc/Veil-Chromium
[uc]: https://github.com/ungoogled-software/ungoogled-chromium
[ucw]: https://github.com/ungoogled-software/ungoogled-chromium-windows
[veil]: https://github.com/Maishan-Inc/Veil
