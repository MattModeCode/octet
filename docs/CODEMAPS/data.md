<!-- Generated: 2026-07-07 | Files scanned: 13 GDScript (core/) + sample .oct | Token estimate: ~550 -->

# Data & chart-format codemap

## Chart resource (core/chart.gd, 13 lines — composition root)

```
Chart (Resource)
├── format_version: int
├── metadata: ChartMetadata   (core/chart_metadata.gd)
├── audio: ChartAudio         (core/chart_audio.gd)
├── timing_points: Array[TimingPoint]  (core/timing_point.gd)
└── notes: Array[ChartNote]   (core/chart_note.gd)
```

`ChartNote` = `{ lane: 0-7, time_ms: int, type: "tap"|"hold", end_time_ms: int }`.
Chords are just multiple `ChartNote`s sharing the same `time_ms`.

## .oct file — on-disk chart (core/oct_io.gd, 189 lines, stateless `OctIO`)

Plain JSON mirroring the Chart resource. Example (`songs/one-voice/easy.oct`, field names verified):

```json
{
  "format_version": 1,
  "audio": { "filename": "OneVoice.mp3", "duration_ms": 161588 },
  "metadata": {
    "title": "One Voice", "artist": "Rokudenashi", "difficulty_name": "Easy",
    "mapper": "Octet Team", "preview_time_ms": 78623, "star_rating": 2.2,
    "tags": ["auto-generated", "signature:long_holds"]
  },
  "notes": [ { "lane": 2, "time_ms": 15348, "type": "tap" } ]
}
```

API: `OctIO.load_oct(path)`, `OctIO.save_oct(path, chart)`, plus string variants
`chart_from_json(str)` / `chart_to_json(chart)` (used by the bundle reader).

## .octet bundle — distributable package (core/octet_bundle.gd, 171 lines, `OctetBundle`)

A zip containing:
```
song.ogg | song.mp3 | song.wav
chart_<difficulty>.oct   (one or more)
cover.jpg (optional)
background.jpg (optional)
manifest.json             (metadata, checksums, chart list)
```
Full read/write API exists; cover-art packing is supported but not yet wired into the
editor's export UI.

## Song storage (core/song_library.gd, 98 lines)

`SongLibrary` recursively scans `res://songs/` (bundled) and `user://songs/` (downloaded
Map Hub content):
```
songs/<slug>/
  <Audio>.mp3        # referenced by audio.filename in the .oct
  cover.jpg|.png      # resolved via COVER_FILENAMES
  <difficulty>.oct    # very_easy | easy | normal | hard | very_hard
```
Six bundled songs ship today: a-thousand-years, drowning-love, one-voice,
story-of-a-warrior, thats-why-i-gave-up-on-music, unravel-tokyo-ghoul.
`tests/fixtures` is excluded from the playable pool.

## Persisted local state (user://)

- `SettingsStore` (core/settings_store.gd) — per-user settings incl. calibration offsets.
- `ScoreStore` (core/score_store.gd) — best-score-per-chart (`user://scores.tres`).

See also: [architecture.md](architecture.md), [gameplay.md](gameplay.md), [editor.md](editor.md).
