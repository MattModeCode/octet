# Changelog

All notable changes to Octet are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] — 2026-07-07

First playable release. Eight-lane rhythm gameplay, a full beat-mapping editor, and a
working (file-hosted) map community, built on Godot 4.7.

### Added

- **Eight-lane play** on the home row (`A S D F` / `J K L ;`) with taps, chords, and
  holds, tiered timing windows, combo, live accuracy, and letter grades (SS/S/A/B/C/D).
- **Audio-driven Conductor clock** — timing derived from playback position, corrected
  for output latency and per-machine calibration, never frame delta.
- **Calibration screen** — tap-to-the-beat routine measures and stores audio/input
  offset so judging matches what the player actually hears and feels.
- **Built-in beat-mapping editor** — waveform view, snap-to-grid beat grid, note
  placement/selection, undo/redo, multiple difficulties, and playtest-in-editor.
- **Automatic BPM and beat detection** — a hand-rolled FFT (`editor/dsp_fft.gd`) and
  onset/tempo analysis (`editor/audio_analysis.gd`) seed BPM/offset on audio import,
  so mapping starts from placement, not hand-syncing by ear.
- **`.oct` chart format and `.octet` bundles** — JSON charts (metadata, timing points,
  notes) packaged with audio and cover art into a distributable zip.
- **Six bundled songs** across 2–3 difficulties each, plus cover art support.
- **Map Hub community screen** — browse, download, and play community maps, served
  today as files from this repo over `raw.githubusercontent.com` (no backend required).
- **Settings screen** — rebindable keys, scroll speed, accessibility options, audio
  buses (Music/SFX), all persisted per machine via `SettingsStore`.
- **Player profile screen** and **local best-score tracking** per chart.
- **Windows, macOS, and Linux** native builds via Godot 4.7 (GL Compatibility
  renderer). Windows/macOS builds are unsigned/un-notarised for this release —
  see the Download section in `README.md` for the install workaround.
- Full UI fidelity pass — fonts, rendering, and mockup rebuilds across every screen,
  matched against the Claude Design mockups (main menu, song select, gameplay HUD,
  results, calibration, editor).

### Known limitations

- **Online accounts and global leaderboards are not live** — Firebase (Auth,
  Firestore, Storage) is scaffolded but stubbed (`Net.is_online()` always false).
  Per-map and global leaderboards are UI-stubbed as "coming soon," not simulated.
  This is Roadmap milestone M4.

[1.0.0]: https://github.com/MattModeCode/octet/releases/tag/v1.0.0
