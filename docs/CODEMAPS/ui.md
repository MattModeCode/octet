<!-- Generated: 2026-07-07 | Files scanned: 13 GDScript (ui/) | Token estimate: ~500 -->

# UI & routing codemap

## SceneRouter (ui/scene_router.gd, 55 lines, autoload)

Thin wrapper over `change_scene_to_file`. Godot passes no payload between scenes, so
`PlaySession` / `EditorSession` autoloads carry state across swaps.

```
SceneRouter.goto_scene(path)         # hard jump, clears history
SceneRouter.goto_scene_pushed(path)  # reversible, pushes to scene_stack
SceneRouter.go_back()                # pops, plays back-SFX
```
Guards missing scenes instead of crashing.

## Scene graph

```
ui/main.tscn (start)
├── game/song_select.tscn
│     ├── game/gameplay.tscn → game/results.tscn (Retry / Next / back to select)
│     └── ui/modifiers.tscn
├── editor/editor_main.tscn ⇄ game/gameplay.tscn (playtest round trip)
├── ui/map_hub.tscn
├── ui/profile.tscn
└── ui/settings.tscn
      ├── ui/rebind_panel.tscn
      └── audio/calibration.tscn
```

## Reusable components (ui/components/)

| File | Role |
|---|---|
| pill_tab_bar.gd | tab navigation widget |
| health_bar.gd | gameplay health bar |
| accent_slider.gd | accent-colour picker |
| note_skin_preview.gd | note skin preview swatch |
| component_sheet.gd / component_styles.gd | design-system component gallery + shared styles |

## Screen owners

`ui/main.gd` (main menu), `ui/settings.gd` + `ui/rebind_panel.gd` (keybind rebinding),
`ui/profile.gd` (player profile), `ui/map_hub.gd` (community browse/download — reads `Net`
autoload), `ui/modifiers.gd` (gameplay run modifiers), `ui/radial_background.gd` (shared
background effect).

See also: [architecture.md](architecture.md).
