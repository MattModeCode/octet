<!-- Generated: 2026-07-07 | Files scanned: 13 GDScript (audio/, game/) | Token estimate: ~550 -->

# Gameplay & timing codemap

## Conductor — timing truth (audio/conductor.gd, 162 lines, autoload)

Song time is derived from `AudioStreamPlayer` playback position on the "Music" bus,
corrected for `AudioServer.get_output_latency()` and calibration offsets, clamped monotonic.
Two pure static methods are headless-testable:

```
Conductor.compute_song_time_ms(playback_pos, latency, offset_ms) → int
Conductor.judgment_error_ms(note_time_ms, song_time_ms) → int
```

Nothing judges off `_process(delta)` — every read goes through `Conductor.song_time_ms()`.
Variable playback rate via `pitch_scale` (editor scrub, Double/Half-speed mods).

## Calibration (audio/calibration.gd, 211 lines)

Tap-to-the-beat routine against audio/metronome.gd. Averages measured error into
`input_offset_ms`, stored only in `SettingsStore.settings` (audio offset stays 0).
Consumed by Conductor on every read.

## Judge engine (game/judge_engine.gd, 296 lines)

`JudgeEngine` — pure `RefCounted`, decoupled from rendering/input for scripted-sequence testing.

```
JudgeEngine.update(song_time_ms)
JudgeEngine.on_lane_press(lane, song_time_ms)
JudgeEngine.on_lane_release(lane, song_time_ms)
  → emits: judged(note, judgment), combo_changed(combo), health_changed(health), song_failed()
```

Judgment buckets: game/judgment.gd (61 lines). Hold-note model — head judged as a tap,
per-interval ticks give Perfect-weight accuracy/score credit (no combo/health effect),
tail judged as a tap.

## Grading (game/grading.gd, 52 lines)

Pure static `Grading.grade(accuracy) → letter` (SS/S/A/B/C/D, thresholds from
`GameplayConfig` — core/gameplay_config.gd). Also computes full-combo / all-Perfect badges.

## Scene flow

```
song_select.gd (game/song_select.gd) → gameplay.gd/.tscn → playfield_view.gd (render)
  → results.gd/.tscn (Retry / Next / back to select)
gameplay_mods.gd — Double/Half speed, other run modifiers, applied via Conductor.pitch_scale
```

## Chart consumption

Gameplay reads `core/chart.gd` (Chart resource, loaded via `core/oct_io.gd`) —
see [data.md](data.md) for the note/timing schema.

See also: [architecture.md](architecture.md).
