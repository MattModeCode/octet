<!-- Generated: 2026-07-07 | Files scanned: 10 GDScript (editor/) | Token estimate: ~450 -->

# Editor codemap

## DSP pipeline (offline analysis on audio import)

```
audio_import.gd (PCM decode)
  → dsp_fft.gd (98 lines — hand-rolled radix-2 Cooley-Tukey FFT; Godot exposes no FFT to GDScript)
  → audio_analysis.gd (245 lines — AudioAnalysis.analyze(pcm) → {bpm, offset_ms, onsets[]})
  → results seed the editable BPM/offset fields in the editor UI
```
Rust GDExtension was considered and declined (no Rust toolchain available) — see note in
`audio_analysis.gd`.

## Editor shell

`editor_main.gd/.tscn` — DAW-style shell. `editor_session.gd` (autoload) holds in-memory
project state + autosave, survives scene swaps to/from playtest.

| File | Role |
|---|---|
| beat_grid.gd | beat/measure grid model, snap-to-grid math |
| note_editor.gd | note placement/selection/edit on the timeline |
| waveform_view.gd | renders the imported waveform |
| note_timeline_view.gd | renders placed notes against the beat grid |
| undo_stack.gd | command-pattern undo/redo for editor edits |

## Playtest round-trip

```
editor_main.tscn → (playtest) → game/gameplay.tscn → (return) → editor_main.tscn
```
State carried via `EditorSession` / `PlaySession` autoloads (Godot's `change_scene_to_file`
passes no payload).

## Output

Editor writes charts via `core/oct_io.gd` (.oct JSON) and exports playable bundles via
`core/octet_bundle.gd` (.octet zip) — see [data.md](data.md).

See also: [architecture.md](architecture.md).
