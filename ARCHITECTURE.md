# Architecture

Octet is a single-player-first, Godot 4.7 (GDScript) rhythm game with three
subsystems bolted onto one autoload spine: a play loop, a beat-mapping editor, and
a file-hosted map community. This document explains how they fit together and why
the load-bearing pieces are shaped the way they are. For a token-lean file-by-file
map, see [`docs/CODEMAPS/`](docs/CODEMAPS/) — this document covers the *why*.

## The problem

A rhythm game has one hard requirement everything else depends on: **the note that
falls past the judgment line and the millisecond that decides its grade must be the
same millisecond**, on every machine, regardless of frame rate, audio driver
latency, or how fast the player's speakers actually emit sound. Get this wrong and
every other feature — editor, scoring, leaderboards — inherits the drift.

The second-hardest requirement: **mapping a song shouldn't require hand-syncing
notes to a beat by ear.** That's slow and error-prone, and Octet's pitch is that
placement, not synchronization, is the mapper's job.

## The approach

### Timing: one clock, read everywhere

`audio/conductor.gd` (`Conductor`, autoload) is the single source of truth for "what
time is it in the song." It derives song time from the actual `AudioStreamPlayer`
playback position on the "Music" bus — not `_process(delta)` accumulation, which
drifts under frame-rate variance — corrected for `AudioServer.get_output_latency()`
and a per-machine calibration offset:

```
song_time_ms = compute_song_time_ms(playback_position, output_latency, calibration_offset)
```

`JudgeEngine` (`game/judge_engine.gd`) never touches the audio player or the frame
clock directly. It only ever calls `Conductor.song_time_ms()`. This is the load-bearing
invariant of the whole gameplay system: **if code judges timing without going
through Conductor, it's a bug**, because it will drift on the one machine whose
audio stack behaves differently from the dev machine.

Two of Conductor's methods (`compute_song_time_ms`, `judgment_error_ms`) are pure
static functions with no engine dependencies, specifically so timing math can be
unit-tested headless without spinning up an `AudioStreamPlayer` — see
`tests/test_conductor.gd`.

### Calibration: closing the gap between "what plays" and "what's heard"

Output latency reported by the OS/driver is not the same as what a human perceives,
because speakers, Bluetooth audio, and USB DACs all add their own delay the OS
doesn't know about. `audio/calibration.gd` runs a tap-to-the-beat routine against a
metronome, averages the player's measured timing error, and stores it as
`input_offset_ms` in `SettingsStore` — consumed by Conductor on every read. This is
why calibration is a first-run screen, not an optional settings toggle: without it,
Conductor's clock is only as accurate as the OS's latency report, which is often wrong
by 30-80ms — enough to turn a Perfect into a Miss.

### Judging: decoupled from rendering, on purpose

`JudgeEngine` (`game/judge_engine.gd`) is a plain `RefCounted`, not a `Node`. It
takes `song_time_ms` and lane press/release events as explicit method arguments and
emits signals (`judged`, `combo_changed`, `health_changed`, `song_failed`) — it does
not read input or draw anything itself. The reason: this lets the test suite drive
a full scripted play-through headlessly (`tests/test_gameplay.gd`), feeding synthetic
timestamps instead of requiring a running game window and real keypresses. Judgment
buckets live in `game/judgment.gd`; grading (letter grades, full combo/all-Perfect)
is `game/grading.gd`, another pure static module.

### Hold notes: three judgments folded into one

A hold note's head is judged as a tap. While held, evenly-spaced ticks along its
length award Perfect-weight accuracy/score credit without touching combo or health —
so a slightly-early or slightly-late release doesn't retroactively wreck an
otherwise-clean hold. The tail is judged as a tap on release. This three-part model
(head / ticks / tail) is why `ChartNote` carries both `time_ms` and `end_time_ms`
rather than being a single timestamp.

### Beat detection: DSP in pure GDScript, by necessity

Godot exposes no FFT to GDScript. `editor/dsp_fft.gd` implements a radix-2
Cooley-Tukey FFT by hand; `editor/audio_analysis.gd` layers onset detection and
tempo estimation on top of it to produce `{bpm, offset_ms, onsets[]}` from a decoded
PCM buffer. A Rust GDExtension was considered for this (FFT is exactly the kind of
hot loop native code is good at) and explicitly declined — no Rust toolchain was
available in the build environment — so the FFT trades some raw speed for zero
build-toolchain dependency. `tests/test_audio_analysis.gd` includes a performance
benchmark test (a 30s clip analyzes in ~2.2s) to keep this trade-off honest as the
codebase changes.

### Chart data: one schema, two encodings

`core/chart.gd` (`Chart`) is the in-memory schema: metadata, timing points, and a
flat list of `ChartNote { lane, time_ms, type, end_time_ms }`. Chords are not a
distinct note type — they're just multiple `ChartNote`s sharing a `time_ms`. This
keeps the note representation uniform: judging code never special-cases "is this a
chord," it just processes whatever notes land at the current song time.

Two on-disk encodings exist for two different jobs:
- **`.oct`** (`core/oct_io.gd`) — plain JSON, one difficulty per file. This is the
  format a mapper edits and the format gameplay loads directly.
- **`.octet`** (`core/octet_bundle.gd`) — a zip of audio + one-or-more `.oct` files +
  optional cover/background art + a `manifest.json`. This is the *distribution* unit:
  what gets uploaded to and downloaded from Map Hub.

Splitting these was deliberate — a mapper iterating in the editor round-trips `.oct`
files constantly (fast, no zip overhead); a finished map is packaged into `.octet`
exactly once, at export/publish time.

### Map Hub: a real client in front of a stubbed backend

`net/net_client.gd` (`Net`, autoload) is split cleanly along a line that matters:
Map Hub (browse/download community maps) is **live today**, served as plain files
from this repo's `maps/` directory over `raw.githubusercontent.com` — no backend
required, see [`docs/MAP_HUB_PUBLISHING.md`](docs/MAP_HUB_PUBLISHING.md). Firebase
(accounts, leaderboards) is a **hard stub** — `Net.is_online()` always returns
`false`, and no real Auth/Firestore/Storage client exists yet. This isn't an
oversight; it's a sequencing choice: a game with local play and downloadable
community maps is a complete, honest product on its own, and the UI treats
leaderboards as "coming soon" rather than fabricating scores against a backend that
doesn't exist (`docs/MAP_HUB_PUBLISHING.md` calls this out explicitly). Online
accounts are Roadmap milestone M4.

## Data flow (at a glance)

```
Play:    song_select → PlaySession → gameplay.tscn
           → Conductor.song_time_ms() → JudgeEngine.update()
           → judged/combo/health signals → playfield_view (render)
           → Grading.grade(accuracy) → results.tscn

Map:     editor_main → audio_import (PCM) → dsp_fft → audio_analysis (bpm/offset)
           → note_editor + beat_grid (placement) → oct_io (save .oct)
           → octet_bundle (export .octet)

Hub:     map_hub.gd → Net.fetch_map_manifest() → maps/index.json (GitHub raw)
           → Net.download_map() → .octet → user://songs/<id>/ → SongLibrary rescans
```

## Trade-offs

- **Frame-rate-independent timing over simplicity.** Reading playback position
  instead of accumulating `delta` is more code and requires the calibration screen
  to exist at all — but it's the only approach that doesn't drift.
- **Hand-rolled FFT over a native dependency.** Slower than a GDExtension would be,
  but ships without requiring every contributor to have a Rust toolchain.
- **`.oct`/`.octet` split over one format.** Two formats to maintain, but each is
  optimized for its actual access pattern (constant local edits vs. one-time export).
- **Map Hub shipped, Firebase stubbed, rather than both-or-nothing.** Means the
  online layer is honestly partial today; the alternative (blocking Map Hub on
  Firebase) would have delayed a working community feature on an unrelated
  dependency.

## Related

- [`docs/CODEMAPS/`](docs/CODEMAPS/) — file-level reference for every domain
- [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) — full functional spec
- [`docs/MAP_HUB_PUBLISHING.md`](docs/MAP_HUB_PUBLISHING.md) — map manifest schema and publishing flow
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — dev setup, running tests, project conventions
