# Fonts

Octet's type system (docs/DESIGN_BRIEF.md §3) uses three families:

| Role | Family | Used for |
|------|--------|----------|
| Display | Space Grotesk (Bold / Medium) | Logo, large headings |
| UI | Inter | UI / body text |
| Mono | JetBrains Mono | HUD numerics — score, combo, accuracy, timing (tabular figures) |

## Current state (Stage 0)

No font binaries are checked in yet. `font_display.tres`, `font_ui.tres`, and
`font_mono.tres` in this folder are Godot 4 `SystemFont` resources — they
render using whatever matching fonts are installed on the host OS, and
degrade to the listed generic fallback (`sans-serif` / `monospace`) if the
named family isn't present. This keeps the project loadable and legible
without shipping binaries, at the cost of not being pixel-consistent across
machines until real font files are added.

`assets/theme/octet_theme.tres` references `font_ui.tres` as the project's
default theme font. `font_display.tres` and `font_mono.tres` are not yet
wired into the theme (per-scene wiring for display/mono roles is later
Stage 3-5 work) but exist now so gameplay/HUD/editor scenes can reference a
consistent resource path (`res://assets/fonts/font_mono.tres`, etc.) instead
of duplicating `SystemFont` setup.

## TODO: add real font files

All three are open-licence (SIL Open Font Licence 1.1) and free to redistribute:

- **Space Grotesk** — SIL OFL, via Google Fonts (https://fonts.google.com/specimen/Space+Grotesk)
- **Inter** — SIL OFL, via Google Fonts (https://fonts.google.com/specimen/Inter)
- **JetBrains Mono** — SIL OFL, via JetBrains (https://www.jetbrains.com/lp/mono/)

In a later pass, download the `.ttf`/`.otf` files and drop them in as:

```
assets/fonts/SpaceGrotesk-Regular.ttf
assets/fonts/SpaceGrotesk-Medium.ttf
assets/fonts/SpaceGrotesk-Bold.ttf
assets/fonts/Inter-Regular.ttf
assets/fonts/Inter-Medium.ttf
assets/fonts/Inter-Bold.ttf
assets/fonts/JetBrainsMono-Regular.ttf
assets/fonts/JetBrainsMono-Medium.ttf
assets/fonts/JetBrainsMono-Bold.ttf
```

Then swap the `SystemFont` resources (`font_display.tres`, `font_ui.tres`,
`font_mono.tres`) for `FontFile` resources pointing at these paths, keeping
the same file paths/role names so `octet_theme.tres` and any scene
references don't need to change — only the resource contents do.

**Licence note:** the SIL OFL requires including the licence text alongside
redistributed font files. When the real `.ttf` files are added, also add
`assets/fonts/OFL.txt` (or per-family licence files) with attribution. Not
done yet — flagged here so it isn't forgotten, not a blocker for Stage 0.
