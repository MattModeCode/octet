<div align="center">

# Octet

**An eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community.**

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS-0C0A0F)
![Engine](https://img.shields.io/badge/engine-Godot%204-478CBF)
![Backend](https://img.shields.io/badge/backend-Firebase-FFC93C)
![License](https://img.shields.io/badge/license-MIT-FF2D6E)

</div>

---

Octet is a fast, keyboard-native rhythm game. Notes fall down eight lanes mapped to the home row, and you hit them the instant they cross the judgment line. Drop in any song and the built-in editor finds the tempo and the beats for you, so mapping is placement, not hand-syncing by ear. Publish your maps to a shared community hub with per-map and global leaderboards.

> Octet is the successor to QWERTY — same core mechanic, rebuilt from the ground up.

## Features

- **Eight-lane play** on the home row — `A S D F` / `J K L ;` — with taps, chords, and holds, tiered timing windows, combo, live accuracy, and letter grades.
- **Built-in editor** with automatic BPM and beat detection, a waveform + beat-grid overlay, snap-to-grid placement, multiple difficulties, and playtest-in-editor.
- **Online map community** — upload, browse, search, download, and rate community maps, with per-map and global leaderboards.
- **Tight sync** via an audio-driven conductor clock and a per-machine calibration screen for audio and input latency.
- **Windows and macOS** native builds.

## Controls

| Lane | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|------|---|---|---|---|---|---|---|---|
| Key  | A | S | D | F | J | K | L | ; |

All keys are rebindable. Scroll speed, offsets, and accessibility options are in settings.

## Download

Native builds for Windows and macOS are published under [Releases](../../releases). *(Coming with the first playable milestone.)*

## Build from source

Requires **Godot 4** and a **Firebase** project.

```bash
# clone, then open in Godot 4
godot4 project.godot
```

Firebase configuration (web config keys) goes in a local config that is git-ignored; the service account key stays server-side in Cloud Functions and is never committed. See `docs/PROJECT_BRIEF.md` §6.4.

## Maps

Maps are `.octet` bundles — a zip of the audio, one or more `.oct` chart files, and optional cover/background art. The `.oct` chart is JSON: metadata, timing points, and a list of notes. Full format in `docs/PROJECT_BRIEF.md` §4.

## Roadmap

- **M1** — First playable: full eight-lane gameplay, judgments, calibration, results.
- **M2** — Editor: waveform, manual BPM/offset, snapped placement, difficulties, save/export.
- **M3** — Automatic BPM + beat detection.
- **M4** — Online: accounts, map hub, downloads, per-map leaderboards.
- **M5** — Community, global ranks, polish, installers.

## Documentation

- [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) — full design and technical spec
- [`docs/DESIGN_BRIEF.md`](docs/DESIGN_BRIEF.md) — visual identity and screens
- [`docs/DESIGN_HANDOFF.md`](docs/DESIGN_HANDOFF.md) — Claude Design import (Editor + Gameplay HUD)
- [`docs/PROMPTS.md`](docs/PROMPTS.md) — build/design prompts
- [`docs/BOOTSTRAP_SPEC.md`](docs/BOOTSTRAP_SPEC.md) — bootstrap spec
- [`CLAUDE.md`](CLAUDE.md) — operating contract

## Tech

Godot 4 (GDScript, optional Rust GDExtension for audio analysis) · Firebase (Auth, Firestore, Cloud Storage, Cloud Functions).

## License

MIT — see [`LICENSE`](LICENSE).
