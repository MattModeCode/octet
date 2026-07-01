# Octet — project brief

An eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community. Windows and macOS, built in Godot 4, backed by Firebase. This document is the source of truth for *what to build*. `DESIGN_BRIEF.md` owns *how it looks*.

Octet replaces the earlier QWERTY project. Keep the one mechanic that worked — falling notes you hit on the beat — and rebuild everything around it as a fresh, self-contained game.

---

## 1. Vision

A fast, precise, keyboard-native rhythm game. You play on the home row, notes fall down eight lanes, and you hit them the instant they cross a judgment line. Anyone can drop in a song, and the built-in editor does the tedious part — finding the tempo and the beats — so mapping is placement, not hand-syncing by ear. Finished maps upload to a shared community hub with per-map and global leaderboards.

Three pillars:

1. **Play** — tight, responsive eight-lane gameplay that feels good on any keyboard.
2. **Create** — the best-quality-of-life beat editor in its class, with automatic BPM and beat detection.
3. **Compete** — an online map community with downloads, ratings, and leaderboards.

---

## 2. Core gameplay

### 2.1 Lanes and controls

Eight lanes mapped to the home row, mirrored across the two hands:

| Lane | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|------|---|---|---|---|---|---|---|---|
| Key  | A | S | D | F | J | K | L | ; |
| Finger | L pinky | L ring | L middle | L index | R index | R middle | R ring | R pinky |

Key bindings are fully rebindable. The mirrored layout matters for both readability and note-skin colour (see design brief) — lane pairs (1&8, 2&7, 3&6, 4&5) share a colour.

### 2.2 Note types

- **Tap** — hit the lane once as it crosses the judgment line.
- **Chord** — two or more taps on the same tick across different lanes; must be hit together.
- **Hold** — press as the head crosses the line, keep held until the tail crosses it, then release. Scored on both the press and the release, with hold-tick credit in between.

### 2.3 Scroll and judgment

Notes scroll top-to-bottom toward a fixed judgment line near the bottom of the play area. Scroll speed is a player preference (a "scroll speed" / approach-rate setting), independent of the chart — it changes how far ahead notes are visible, never their timing. Judgment is based purely on the time delta between the input and the note's target time.

### 2.4 Timing windows and judgments

Windows are symmetric around the note's target time (values in milliseconds, tunable — expose them in a config file):

| Judgment | Window (±ms) | Accuracy weight |
|----------|--------------|-----------------|
| Perfect  | 25 | 100% |
| Great    | 60 | 66% |
| Good     | 110 | 33% |
| Miss     | > 110 or unhit | 0% |

Holds: the head is judged like a tap; each hold tick awards fractional credit; an early release before the tail truncates the remaining ticks as misses.

### 2.5 Scoring, combo, accuracy, grade

- **Accuracy** = weighted mean of all judgments, shown as a live percentage.
- **Combo** = consecutive non-Miss hits; drives a combo multiplier (cap it, e.g. ×4) that scales score, not accuracy. A Miss breaks combo.
- **Score** = sum of per-note base points × current multiplier. Keep it a large, satisfying number.
- **Grade** at song end from final accuracy: `SS` = 100%, `S` ≥ 95%, `A` ≥ 90%, `B` ≥ 80%, `C` ≥ 70%, `D` below. Full-combo and all-Perfect earn separate badges.

### 2.6 Health and fail

A health bar starts at 100. Suggested deltas (tunable): Perfect +1, Great +0.5, Good −1, Miss −6. If it empties, the song fails. A **No-Fail** practice toggle disables failing (and flags the score as unranked). A **Practice** mode allows starting from an arbitrary point at reduced or fixed rate.

### 2.7 Results screen

Grade, final accuracy, max combo, score, full judgment breakdown (count of each), a hit-error histogram (early/late distribution), and mean offset. Actions: retry, next, back to song select. If online and ranked, submit score and show placement.

### 2.8 Calibration (mandatory)

Rhythm games live or die on sync. Ship a **calibration screen** that measures and stores two offsets:

- **Audio offset** — compensates for output latency between the audio clock and what the player hears.
- **Input offset** — compensates for the player's device/keyboard/display latency.

Calibrate via a tap-to-the-beat routine (player taps a steady metronome; average the error into the offset). Store per-machine. All judgment math applies these offsets.

### 2.9 Difficulty and star rating

Each map can hold multiple difficulties (e.g. Easy / Normal / Hard / Expert). Compute a **star rating** per difficulty from note density, chord/hold complexity, and pattern speed. Show it in song select and the hub.

---

## 3. The editor

The hardest and most important surface. Goal: let a user turn any song into a well-synced map in minutes, mostly by placing notes on a grid the tool has already found for them.

### 3.1 Audio import

Accept **MP3, OGG Vorbis, and WAV** at minimum (FLAC is a nice-to-have). On import: decode to PCM, normalise for analysis, store the original alongside the chart.

### 3.2 Automatic analysis (the key feature)

On import, run offline analysis to propose tempo and beats so the user isn't hand-linking notes to audio:

1. **Onset detection.** Frame the PCM (e.g. 1024-sample windows, 50% overlap), FFT each frame, compute a **spectral-flux** onset envelope (sum of positive magnitude differences across bins between consecutive frames). Peaks in this envelope are note onsets.
2. **Tempo (BPM) estimation.** Run autocorrelation (or a comb-filter bank) over the onset envelope; pick the strongest periodicity within a musical range (60–220 BPM); resolve octave errors (half/double tempo) by scoring candidate multiples against the envelope.
3. **Beat phase / first-beat offset.** Find the grid phase that best aligns beat positions to onset peaks.
4. **Beat grid.** From BPM + offset, generate grid lines; optionally seed notes directly onto detected onsets as a starting draft.

**Implementation path.** Recommended: a small **Rust GDExtension** (FFT + spectral flux + autocorrelation) for speed and clean cross-platform packaging. Acceptable MVP fallback: pure GDScript/C# DSP if performance on a 3–5 minute song is tolerable. Either way, expose the results (BPM, offset, onset list) as editable values.

**Set expectations honestly:** auto-detection typically gets ~90% of songs close on the first pass. Always provide fast manual correction of **BPM** and **first-beat offset**; with the waveform + beat overlay, locking a song to perfect sync should be a few-second nudge, not a chore. Variable-tempo songs need multiple timing points (§3.4).

### 3.3 Waveform and beat overlay

Render the full-song waveform on a horizontal timeline with detected beat lines overlaid, plus a playhead. This is what makes hand-verification instant: the user scrubs, sees beats sitting on transients, and nudges offset/BPM until they line up.

### 3.4 Timing points

Support multiple timing points for tempo changes: each timing point has a time, a BPM, and a meter. The first timing point defines the song offset. Grid and snapping recompute per active timing point.

### 3.5 Note placement and snapping

- A vertical lane timeline (8 lanes) synced to the audio timeline.
- **Snap divisions:** 1/1, 1/2, 1/3, 1/4, 1/6, 1/8, 1/12, 1/16 — selectable; notes snap to the nearest active subdivision.
- Click to place taps; drag to place holds (head + tail); select multiple lanes on one tick for chords.
- Free-place (snap off) for off-grid notes.

### 3.6 Quality-of-life (build all of these)

- Timeline **zoom** (time and vertical).
- **Scrub** and variable-rate playback (0.25×–1×) with the notes visible.
- Optional **metronome** click and beat tick.
- **Per-note nudge** (arrow keys move selected notes by one snap unit or by ms).
- **Select / copy / paste / duplicate**, box-select, and **mirror** (flip lanes horizontally).
- **Multiple difficulties** per song as tabs, sharing the same audio/timing.
- **Undo / redo** with full history.
- **Playtest in editor** — jump into real gameplay from the current position without leaving the editor.
- Autosave and crash recovery.

### 3.7 Save and export

Editor writes a **`.oct` chart** and packages a **`.octet` bundle** (§4). Bundles are what upload to the hub and what players download.

---

## 4. Map file format

### 4.1 `.oct` chart (JSON)

```json
{
  "format_version": 1,
  "metadata": {
    "title": "Song Title",
    "artist": "Artist",
    "mapper": "username",
    "difficulty_name": "Expert",
    "star_rating": 5.2,
    "tags": ["electronic", "stream"],
    "preview_time_ms": 42000
  },
  "audio": {
    "filename": "song.ogg",
    "duration_ms": 210000
  },
  "timing_points": [
    { "time_ms": 812, "bpm": 174.0, "meter": 4 }
  ],
  "notes": [
    { "lane": 0, "time_ms": 812, "type": "tap" },
    { "lane": 3, "time_ms": 812, "type": "tap" },
    { "lane": 5, "time_ms": 1156, "type": "hold", "end_time_ms": 1500 }
  ]
}
```

Lanes are 0–7 (left to right). `type` is `tap` or `hold`; a chord is simply multiple notes sharing a `time_ms`.

### 4.2 `.octet` bundle

A zip containing everything needed to play a map:

```
song.ogg            # or .mp3 / .wav
chart_easy.oct
chart_normal.oct
chart_hard.oct
cover.jpg           # optional square art
background.jpg      # optional
manifest.json       # bundle-level metadata, checksums, list of charts
```

---

## 5. Online layer (Firebase)

Full online: accounts, a community map hub with upload/download, and leaderboards.

### 5.1 Auth

**Firebase Auth** with email/password plus at least one OAuth provider (Google). A user has a unique username, display name, and profile.

### 5.2 Firestore data model

```
users/{uid}
  username, displayName, joinedAt, country
  stats: { totalScore, rankedPlays, averageAccuracy, globalRankCached }

maps/{mapId}
  title, artist, mapperUid, mapperName, createdAt, updatedAt
  bundlePath (Storage), coverPath, previewTime
  difficulties: [ { name, starRating, chartPath, noteCount } ]
  tags, downloads, playCount, ratingSum, ratingCount, ratingAvg
  status: published | pending | flagged

maps/{mapId}/scores/{uid}
  uid, username, score, accuracy, maxCombo, grade, mods, playedAt, replayPath?
  # one best-score doc per user per map (overwrite on improvement)
```

**Leaderboard caveat.** Firestore is fine for *per-map* leaderboards: query `maps/{mapId}/scores` ordered by `score` desc with cursor pagination, one best-score doc per user to avoid duplicates. **Global** ranking across all players is where Firestore is weak — do not try to sort every score live. Instead maintain a cached `globalRank` on each user, recomputed periodically by a scheduled Cloud Function that aggregates ranked scores (or use a performance-points model summing each user's top-N ranked plays). Document this limitation in code; it's the main reason a SQL backend is usually preferred here, but Firebase is workable with aggregation.

### 5.3 Cloud Storage

Bundles and assets live in **Cloud Storage for Firebase**:

```
maps/{mapId}/bundle.octet
maps/{mapId}/cover.jpg
replays/{mapId}/{uid}/{scoreId}.replay   # optional, later
```

Audio can be several MB per map — mind bandwidth and set sensible size limits and storage rules.

### 5.4 Cloud Functions

- **Publish pipeline** — on upload, validate the bundle (well-formed charts, audio present, size limits), extract metadata into the `maps` doc, generate a thumbnail, set `status`.
- **Score submission** — validate a submitted score server-side (basic sanity: accuracy vs. judgment counts, achievable combo, mods) before writing; overwrite only if better than the user's existing best.
- **Rank aggregation** — scheduled job to recompute cached global ranks / performance points.
- **Moderation hooks** — flagging and takedown.

### 5.5 Map hub / browser (in-client)

Browse and search published maps: sort by newest / most played / highest rated / difficulty; filter by tag, star range, and length; free-text search on title/artist/mapper. Each map has a detail view with difficulties, cover, preview playback, download button, and its per-map leaderboard. Downloads cache locally and appear in song select.

### 5.6 Leaderboards

- **Per-map, per-difficulty** — ranked by score, showing accuracy, combo, grade, mods, and date; highlight the local user.
- **Global** — from cached ranks / performance points.
- Only **ranked** plays (no mods that trivialise, no No-Fail) submit to leaderboards.

### 5.7 Anti-cheat (phased)

v1: server-side sanity validation of submitted scores (§5.4). Later: record and upload **replays** (input event stream) and validate server-side or via community replay review. Note this as a known future need, not an MVP blocker.

---

## 6. Architecture and tech

### 6.1 Engine and structure

Godot 4, GDScript primary. Suggested layout:

```
project.godot
/game        # gameplay scenes: playfield, lanes, notes, judgment, HUD, results
/editor      # editor scenes: timeline, waveform, note tools, inspector
/audio       # conductor, calibration, analysis bindings
/net         # Firebase client wrappers (auth, firestore, storage, functions)
/ui          # menus, song select, hub, profile, shared components
/core        # chart model, bundle IO, scoring, star-rating, settings
/native      # optional Rust GDExtension (audio analysis)
/assets      # fonts, note skins, sfx, icons
```

### 6.2 Audio sync (the conductor pattern)

Drive all timing from the audio playback position, not from frame delta. Track song time using the audio stream's playback position plus `AudioServer` output-latency compensation, corrected by the stored calibration offsets. Notes are positioned and judged against this conductor clock. This is the standard approach for tight Godot rhythm timing — implement it once, centrally, and route everything through it.

### 6.3 Audio analysis binding

Prefer a Rust GDExtension exposing `analyze(pcm) -> { bpm, offset_ms, onsets[] }`. Fallback: GDScript DSP. Keep the interface identical so the backend can be swapped without touching the editor.

### 6.4 Firebase integration

Godot has no official Firebase SDK. Use the **Firebase REST APIs** (Auth REST, Firestore REST, Storage REST) via `HTTPRequest`, wrapped in a thin `/net` client, or a maintained community Godot-Firebase addon if it meets needs. Keep all Firebase access behind `/net` so callers never touch transport details. Web config keys are not secret; the service account key and any admin credentials are — keep those server-side in Functions only.

### 6.5 Packaging and distribution

Export native builds with Godot export templates for **Windows (.exe / installer)** and **macOS (.dmg, notarised)**. Distribute via **GitHub Releases** on this repo. Note macOS signing/notarisation as a required step for a smooth install. Bundle the export presets but keep signing secrets out of the repo.

---

## 7. Milestones

- **M0 — Skeleton.** Project scaffold, input + rebinding, one lane, a note falling, hit detection, a single judgment. Proves the conductor clock.
- **M1 — Core gameplay.** All 8 lanes; taps, chords, holds; timing windows; combo, accuracy, grade; health/fail; results screen; **calibration screen**; scroll-speed setting. Loads a local `.oct`. This is `FIRST_MILESTONE`.
- **M2 — Editor v1.** Load audio; waveform; manual BPM/offset; snapped note placement; timing points; holds/chords; core QOL (zoom, scrub, undo/redo, metronome, difficulties); save `.oct` + `.octet`; playtest-in-editor.
- **M3 — Auto-analysis.** Onset detection + BPM estimation + beat-grid overlay; seed-draft notes; manual nudge. Ship the Rust GDExtension (or GDScript fallback).
- **M4 — Online core.** Firebase Auth; publish/upload bundles; map hub browse/search/download; per-map leaderboards; score submission + validation.
- **M5 — Community + polish.** Global ranks / performance points; profiles; ratings; anti-cheat (replays) groundwork; packaging, installers, and releases.

Ship M1 as the first playable. Everything after is additive.

---

## 8. Out of scope for v1

Mobile/touch, controller/MIDI input, real-time multiplayer/versus, in-game chat, seasons/tournaments, monetisation. Design the data model so these are possible later, but don't build them now.

---

## 9. Deferred decisions

- Exact timing windows, health deltas, and star-rating formula — start with the values above, tune with playtesting.
- Rust GDExtension vs. GDScript DSP for analysis — decide at M3 based on measured performance.
- Community Godot-Firebase addon vs. hand-rolled REST client — spike at M4.
- Licence (repo currently ships MIT — change if desired).
