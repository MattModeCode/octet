<!-- Generated: 2026-07-07 | Files scanned: 57 GDScript | Token estimate: ~650 -->

# Octet — system architecture

Godot 4.7 (GL Compatibility), pure GDScript. Entry scene: `res://ui/main.tscn`.

## Domain map

```
core/    data model + persistent state (Chart schema, .oct/.octet IO, settings, scores)
audio/   timing truth + sound (Conductor, calibration, metronome, sfx)
game/    play loop (judging, grading, gameplay scene, song select, results)
editor/  beat-mapping editor (DSP pipeline, beat grid, note editor, undo)
ui/      menus + navigation (scene_router, main menu, settings, map hub)
net/     Map Hub client + Firebase stub
songs/   bundled playable songs (audio + cover + .oct charts)
maps/    community Map Hub content (index.json + .octet bundles)
tests/   headless GDScript test suites + runner
```

## Autoload graph (registration order — later reads earlier in `_ready()`)

```
Config → DesignTokens → SettingsStore → LaneInput → PlaySession →
ScoreStore → EditorSession → Conductor → SceneRouter → Net → Sfx
```

| Autoload | File | Role |
|---|---|---|
| Config | core/config.gd | loads gameplay.tres / scoring.tres |
| DesignTokens | core/design_tokens.gd | colours, lane palette |
| SettingsStore | core/settings_store.gd | persisted per-user settings (user://) |
| LaneInput | core/lane_input.gd | registers lane_0..lane_7 InputMap actions |
| PlaySession | core/play_session.gd | song-select → gameplay → results handoff |
| ScoreStore | core/score_store.gd | local best scores (user://scores.tres) |
| EditorSession | editor/editor_session.gd | editor in-memory state + autosave |
| Conductor | audio/conductor.gd (162 lines) | single source of timing truth |
| SceneRouter | ui/scene_router.gd (55 lines) | scene navigation |
| Net | net/net_client.gd (184 lines) | Map Hub client / Firebase stub |
| Sfx | audio/sfx.gd | UI sound effects |

## Data flow — a play session

```
song_select.gd → PlaySession (chart path) → gameplay.tscn
  → Conductor.song_time_ms() (audio-driven clock)
  → JudgeEngine.update(song_time_ms) + on_lane_press/release
  → judged / combo_changed / health_changed signals → playfield_view.gd (render)
  → song_failed OR song end → Grading.grade(accuracy) → results.tscn
```

## Data flow — mapping a song (editor)

```
editor_main.tscn → audio_import.gd (PCM decode)
  → dsp_fft.gd (radix-2 FFT) → audio_analysis.gd (bpm, offset_ms, onsets[])
  → editable BPM/offset seed values → note_editor.gd + beat_grid.gd (placement)
  → oct_io.gd (save .oct) / octet_bundle.gd (export .octet zip)
```

## Data flow — Map Hub

```
ui/map_hub.gd → Net.fetch_map_manifest() → GET maps/index.json (raw.githubusercontent.com)
  → manifest_fetched signal → Net.download_map() → .octet bundle → user://cache
  → unpack → user://songs/<id>/ → map_downloaded signal → SongLibrary rescans
```

See also: [gameplay.md](gameplay.md), [editor.md](editor.md), [ui.md](ui.md), [data.md](data.md), [dependencies.md](dependencies.md).
