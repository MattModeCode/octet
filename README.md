<div align="center">

<img src="assets/icons/icon.svg" width="96" height="96" alt="Octet icon">

# Octet

**An eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community.**

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-0C0A0F)
![Engine](https://img.shields.io/badge/engine-Godot%204.7-478CBF)
![License](https://img.shields.io/badge/license-MIT-FF2D6E)

</div>

---

Octet is a fast, keyboard-native rhythm game. Notes fall down eight lanes mapped to the home row, and you hit them the instant they cross the judgment line. Drop in any song and the built-in editor finds the tempo and the beats for you, so mapping is placement, not hand-syncing by ear. Browse and download community-made maps from the shared Map Hub.

## Features

- **Eight-lane play** on the home row — `A S D F` / `J K L ;` — with taps, chords, and holds, tiered timing windows, combo, live accuracy, and letter grades.
- **Built-in editor** with automatic BPM and beat detection, a waveform + beat-grid overlay, snap-to-grid placement, multiple difficulties, and playtest-in-editor.
- **Map Hub** — browse, search, and download community-made maps, played straight from the client. Publishing today is a manual, repo-owner step (see [Maps](#maps)); per-map and global leaderboards are planned but not live.
- **Tight sync** via an audio-driven conductor clock and a per-machine calibration screen for audio and input latency.
- **Windows, macOS, and Linux** native builds.

## Controls

| Lane | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|------|---|---|---|---|---|---|---|---|
| Key  | A | S | D | F | J | K | L | ; |

All keys are rebindable. Scroll speed, offsets, and accessibility options are in settings.

## Download

Native builds for Windows, macOS, and Linux are published under
[Releases](../../releases). Grab the `v1.0.0` build for your platform:

- **Windows** — download `Octet-v1.0.0-windows-x64.zip`, extract, run
  `Octet.exe`. Unsigned build — Windows SmartScreen will warn on first launch
  (**More info → Run anyway**).
- **macOS** — download `Octet-v1.0.0-macos-universal.zip`, extract. Unsigned/
  un-notarised, so Gatekeeper blocks a plain double-click; before first launch
  run `xattr -dr com.apple.quarantine Octet.app`, then open normally.
- **Linux** — download `Octet-v1.0.0-linux-x86_64.zip`, extract, then
  `chmod +x Octet.x86_64 && ./Octet.x86_64`.

Each release includes a `SHA256SUMS.txt` to verify your download.

## Build from source

Requires **Godot 4.7**.

```bash
# clone, then open in Godot 4.7
godot4 project.godot
```

## Maps

Maps are `.octet` bundles — a zip of the audio, one or more `.oct` chart files, and optional cover/background art. The `.oct` chart is JSON: metadata, timing points, and a list of notes. Full format in `docs/PROJECT_BRIEF.md` §4 and [`docs/CODEMAPS/data.md`](docs/CODEMAPS/data.md).

Community maps in **Map Hub** are served today as plain files from this repo's `maps/`
directory over `raw.githubusercontent.com` (see [`docs/MAP_HUB_PUBLISHING.md`](docs/MAP_HUB_PUBLISHING.md)) — no backend required. Per-map and global leaderboards are not live yet; the UI marks them "coming soon" rather than faking scores.

## Roadmap

- ✅ **M1** — First playable: full eight-lane gameplay, judgments, calibration, results.
- ✅ **M2** — Editor: waveform, manual BPM/offset, snapped placement, difficulties, save/export.
- ✅ **M3** — Automatic BPM + beat detection. Shipped in **v1.0.0**, along with Map Hub
  browse/download. **v1.1.0** added new maps and stability fixes. **v1.1.0** added new maps and stability fixes.
- ⬜ **M4** — Online: accounts, real map-hub publishing, per-map leaderboards.
- ⬜ **M5** — Community, global ranks, polish, signed/notarised installers.

## Documentation

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — how the systems fit together and why
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — dev setup, running tests, project conventions
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) — full design and technical spec
- [`docs/DESIGN_BRIEF.md`](docs/DESIGN_BRIEF.md) — visual identity and screens
- [`docs/MAP_HUB_PUBLISHING.md`](docs/MAP_HUB_PUBLISHING.md) — Map Hub manifest schema and publishing
- [`docs/CODEMAPS/`](docs/CODEMAPS/) — architecture, gameplay, editor, UI, data, and dependency codemaps

## Tech

Godot 4.7 (GDScript — no GDExtension in use; the audio-analysis FFT is hand-rolled in pure
GDScript, see [`docs/CODEMAPS/editor.md`](docs/CODEMAPS/editor.md)). Map Hub runs today as
plain files served from this repo over `raw.githubusercontent.com`. A backend for accounts
and leaderboards (Roadmap M4) is planned but not yet implemented.
