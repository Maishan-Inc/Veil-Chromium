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

Source of the Tier 1 patch set: switch registration and seed plumbing, UA/UA-CH coherence, canvas
(`getImageData`, `toDataURL`, `measureText`), WebGL `readPixels`, GPU info,
font enumeration, `hardwareConcurrency`, timezone-as-a-switch, and the `navigator.webdriver` /
headless / `Runtime.enable` surfaces.

Three of its patches are **not** shipped. `007-shadow-root` added an ungated
`Element.fakeShadowRoot` marker rather than closing a surface. `003-audio-fingerprint`'s
perturbation of the reported sample rate was both illegal (an `OfflineAudioContext` must report the
rate the page asked for) and quantised away for about a seed in five; the audio surface is now Veil's
own — see **Veil** below. And `014-client-rects` translated the whole document by a seed-derived
±0.001 px, which left every width, height and inter-element distance bit-identical to stock while
putting the coordinates off Chromium's 1/64 `LayoutUnit` grid — a protection with no effect and a tell
that costs one expression to read, dropped in Stage 6 T09.

## clearcote-browser

[`clearcotelabs/clearcote-browser`][cc] — BSD-3-Clause.

Source of the Tier 2 patch set: `screen` and media queries, the WebGL capability block, `mediaDevices`,
`mediaCapabilities`, speech voices, device sensors, `getBattery`, `navigator.connection`, keyboard
layout, storage quota, `performance.memory`, geolocation, WebGPU coherence, and the TLS JA3/JA4 +
HTTP/2 persona. Its dedicated coherence patches (`092-language-locale-coherence`,
`075-webgpu-coherence`, `160-coherence-misc`) are the reference for keeping surfaces from contradicting
each other, and `070-webgl-gpu`'s downward-clamp argument — never report a limit above what the driver
can deliver, because an upward claim is falsifiable by allocation — is carried into Veil's `963`.

Stage 6's phase 3 took **arguments and call-site sets, not code**, from three more of its patches, and
each Veil patch header says so in full: `170-speech-voices` for substituting the voice list in the one
function both emission paths share and for never filling `getVoices()` synchronously (`968`);
`147-media-capabilities` for overriding at the last codec-aware point and for never over-claiming a codec
the table does not speak for (`969`); `020-audio` for the rule that a substituted latency must land on a
grid genuine Chrome can produce (`967`). Their persona-struct rung and their tables are not carried —
6.9 in `Veil/docs/MIGRATION-UNGOOGLED.md` records why — and `148-media-devices`' wholesale replacement of
the device list is deliberately **not** taken, because `getUserMedia()` resolves out of the same
enumeration (6.15).

Stage 6's T19 ports **`100-webrtc-leak`** as Veil's `983`: the fabricated server-reflexive
candidate pinned to the proxy exit IP (`--webrtc-ip=`), with the srflx rewrite, the forced
gathering, and the process-global forced-IP store. The host-candidate suppression of the
counterpart is replaced by Veil's `984` (the next patch in the series), which turns host
candidates into synthetic mDNS hostnames instead — Chrome's own shape — and adds an opt-out the
counterpart lacks.

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

Present in this range today:

- `915-canvas-measure-text-multiplier-and-worker` — fixes three measured defects in `015`: a
  multiplicative `TextMetrics::Shuffle()` call site handed an additive noise value, a realm test that
  left a Worker's `OffscreenCanvas` unspoofed, and an empty-string guard that made the perturbation
  factor recoverable in one expression.
- `950-audio-render-noise` — perturbs the rendered samples of an `OfflineAudioContext` from the seed.
  Replaces `003-audio-fingerprint` outright rather than correcting it: that patch perturbed the
  *reported sample rate*, which no real browser can do, so there was nothing to keep.
- `902-chromium-version-from-the-build` — derives the Chromium version UA-CH reports from
  `PRODUCT_VERSION` instead of `002`'s table, which was frozen at the Chromium
  `fingerprint-chromium` was built from and made the engine claim two versions at once.
- `906-font-fingerprint-one-os-and-deterministic-absence` — fixes four independent mechanisms in
  `006` that put two operating systems' system fonts in one list, and makes a family's absence
  deterministic instead of a per-family lottery.
- `960-display-panel` — reads `--fingerprint-screen-{width,height}` and
  `--fingerprint-device-scale-factor`, which `000` had declared and nothing had read, and derives the
  work area, colour depth, orientation and `isExtended` from the panel and the claimed platform.
  Rewritten against clearcote's `140-screen` + `141-media-queries` rather than ported, because both
  read a persona struct Veil deliberately does not carry.
- `963-webgl-capability-profile` — the capability half of `011`: the `getParameter` limits, their
  WebGL2 block and the extension list follow the same platform claim the renderer *name* follows,
  instead of leaving the real card's numbers beside a spoofed name. Two tables transcribed from
  ANGLE's own D3D11 and Metal backends, clamped down to the live driver, with every algebraically
  dependent limit derived after the clamp. Takes the call-site set and the clamp argument from
  clearcote's `070-webgl-gpu`; the numbers, the derivation and the extension handling are Veil's.
- `967-audio-device-persona` — answers `AudioContext.baseLatency` from the output buffer size the
  claimed platform's own Chromium backend would choose (256 frames on macOS, 512 on Linux, both
  transcribed with a line citation) instead of from the host's audio device, whose 10 ms WASAPI period
  is a Windows signature. Leaves `outputLatency` and `maxChannelCount` alone, and the measurement that
  says why is in the patch header.
- `968-speech-voice-persona` — presents the claimed platform's `speechSynthesis` catalogue in place of
  the host's, which is installed by the OS and its language packs and so names the platform *and* the
  locale in one read. The list-building shape is transcribed from `content/browser/speech/tts_mac.mm`;
  the roster is Veil's, deliberately smaller than a maximal Mac's rather than invented.
- `969-media-devices-and-codec-persona` — HEVC support answered once where `canPlayType`, MSE and
  `decodingInfo().supported` all arrive, the hardware-decode set keyed on the Apple part `011` picked
  for the seed, and one described capture device added for a kind the host does **not** have. Additive
  by design: a present device is never replaced, because `getUserMedia()` resolves out of the same
  enumeration.
- `972-generic-families-and-local-fonts` — the CSS generics resolve to the faces the claimed platform's
  Chrome defaults to (`chrome/app/resources/locale_settings_mac.grd`), so `monospace` stops falling
  through to a proportional face; and `queryLocalFonts()` is filtered by the same membership rule `006`
  and `906` apply, from the same tables, instead of enumerating the host's real set.
- `961-touch-and-pointer-persona` — `navigator.maxTouchPoints` and the four pointer / hover media
  features answered from one number, in the single browser-side place all five are written
  (`SlowWebPreferenceCache::Load`). A macOS claim reports 0 because macOS builds
  `ui/base/pointer/pointer_device_default.cc`, whose `MaxTouchPoints()` is a constant 0 — so the count
  is not a market fact about Apple but a property of what Chromium compiles. Takes the one switch this
  block needs, `--fingerprint-max-touch-points`, and nothing else from clearcote's `150`, which
  overrides the getter alone and leaves the media queries contradicting it.
- `905-device-memory-switch` — corrects `005`, whose `deviceMemory()` body was `return 8;` gated on
  nothing at all, so every profile reported 8 GB and no stored value could be honoured. Reads
  `--fingerprint-device-memory` and falls back to the host's real `ApproximatedDeviceMemory` value — the
  same two rungs `005` already gives `hardwareConcurrency`. clearcote's `030` was the audited counterpart
  and is not the source: its middle rung is the persona struct, and both of its outer rungs clamp to 8
  with the comment "real Chrome never reports >8", which Chromium 151 contradicts — `kMaxMemory` is 32
  and stock Chrome reports 32 on the build host.

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
