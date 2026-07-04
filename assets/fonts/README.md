# Fonts

Octet's type system (docs/DESIGN_BRIEF.md §3) uses three families:

| Role | Family | Used for |
|------|--------|----------|
| Display | Space Grotesk (Bold) | Logo, large headings |
| UI | Inter (Regular) | UI / body text |
| Mono | JetBrains Mono (Medium) | HUD numerics — score, combo, accuracy, timing (tabular figures) |

## Current state (WP-A fidelity pass)

Real SIL-OFL binaries are checked in. Google Fonts ships all three families as
**variable fonts** (single file, `wght`/`opsz` axes), not static per-weight
files, so the resource wiring uses Godot's `FontVariation`:

```
assets/fonts/Inter-Variable.ttf            (imported as FontFile)
assets/fonts/SpaceGrotesk-Variable.ttf     (imported as FontFile)
assets/fonts/JetBrainsMono-Variable.ttf    (imported as FontFile)

assets/fonts/font_ui.tres       -> FontVariation(base_font=Inter-Variable, wght=400)
assets/fonts/font_display.tres  -> FontVariation(base_font=SpaceGrotesk-Variable, wght=700)
assets/fonts/font_mono.tres     -> FontVariation(base_font=JetBrainsMono-Variable, wght=500)
```

`font_ui.tres`/`font_display.tres`/`font_mono.tres` keep the same resource
paths they had as `SystemFont` placeholders, so `assets/theme/octet_theme.tres`
and every scene's `ext_resource` references didn't need path changes — only
the `type=` on those ext_resource lines moved from `"SystemFont"` to
`"FontVariation"` to match the new resource type.

Each role is wired to a single weight project-wide (no per-node bold/regular
split yet) — that granularity is later per-screen fidelity work (WP-G…L), not
this pass. If a specific label needs a different weight, create another
`FontVariation` wrapping the same base `FontFile` with a different
`variation_opentype` value rather than duplicating the `.ttf`.

**Licence:** all three are SIL Open Font License 1.1, redistributable.
Licence text for each family is checked in as `OFL-<Family>.txt`.

## Related fix: radial gradient background

While verifying this pass, `ui/radial_background.gd`'s `_build_radial_texture()`
had a real (pre-existing, unrelated to the font swap) bug: `Gradient.new()`
seeds two default points (black@0.0, **white@1.0**), and the function only
overwrote point 0's colour and then *added* further points rather than
replacing the existing ones — so the default white point at offset 1.0 was
never removed, and every radial background (Main Menu, Gameplay HUD, Results,
Calibration) faded to white/grey past ~60% radius instead of holding at the
intended near-black ink colour. Fixed by setting `gradient.offsets`/
`gradient.colors` wholesale instead of mutating the default point list.
Confirmed visually before/after via a headless-launched, screenshotted
instance — the bug reproduced even on the pre-fidelity-pass `project.godot`,
so it wasn't caused by this pass, just never actually screenshotted before.

## Canvas/window scale (0.667×) decision

`project.godot` keeps `window/size/viewport_width/height=1920x1080` (matching
every mockup's coordinate space exactly) with
`window/size/window_width_override=1280`/`height_override=720` — the same
override added earlier to fix the global hitbox-offset bug (see
`docs/DESIGN_HANDOFF.md`). That override was **not reverted** here: dropping
it back to a native 1920×1080 window risks reintroducing that bug on displays
where a full 1080p window doesn't fit uncropped. Instead, text sharpness at
the resulting 0.667× canvas_items scale is handled by Godot's own per-CanvasItem
font oversampling (automatic, re-rasterizes glyphs at their effective on-screen
size under the canvas transform) plus explicit `[gui]` antialiasing/hinting
settings added to `project.godot`, combined with real `FontFile`-backed fonts
instead of `SystemFont`. Verified empirically (not assumed): headless-launched
screenshots of Main Menu, Song Select, Editor, and Calibration at the real
1280×720 window all show crisp text with no visible softening.
