# Design handoff

Every built screen — **Main Menu, Song Select, Gameplay HUD, Results, Calibration, Editor** — is designed in Claude Design and implemented directly from a mockup imported via the Claude Design MCP. Screens not yet built (Sign In, Map Hub, Profile — gated on Stage 7/8) will be implemented from their own mockups when those stages land. [`DESIGN_BRIEF.md`](DESIGN_BRIEF.md) is the palette/type reference underneath all of them, not a substitute for the mockup itself.

**Design-fidelity rule (CLAUDE.md §2):** any UI/visual change must be checked against the mockup re-fetched live from the Claude Design MCP — never implemented or "matched" from memory, a prose summary, or baked constants alone. This rule was added after a fidelity-pass session (below) found that several screens, including the Gameplay HUD, had drifted from their real mockups because earlier sessions built from this document's prose rather than re-fetching the `.dc.html` file.

## Claude Design project

- **Project:** https://claude.ai/design/p/cc6f9e35-9183-4b42-8d8a-be6dfc135fe1
- **Import via the Claude Design MCP:** endpoint `https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`.

## Chosen designs to implement

| Screen | Variant | File |
|--------|---------|------|
| Main Menu | (single layout) | `Octet - Main Menu.dc.html` |
| Song Select | (single layout) | `Octet - Song Select.dc.html` |
| Gameplay HUD | **1a** ("Classic centered — compact playfield, top HUD row, horizontal health bar") | `Octet - Gameplay HUD.dc.html` |
| Results | (single layout) | `Octet - Results.dc.html` |
| Calibration | (single layout) | `Octet - Calibration.dc.html` |
| Editor | **2a** ("Standard DAW layout — waveform top, tool rail left, inspector right") | `Octet - Editor.dc.html` |

> **Resolved (Stage 6):** the "1A"/"2A" shorthand below was an unconfirmed guess made before either file had actually been fetched from the Claude Design MCP. `Octet - Editor.dc.html` turned out to contain **three** layout options, internally labelled `2a`/`2b`/`2c` (not "1A") under one turn ("Editor — 3 layout directions"). **Option 2a is what's implemented** in `editor/editor_main.tscn` — it's also the file's own suggested next step ("make 2a the primary editor, add zoom controls"). The Gameplay HUD file turned out to have the exact same multi-option structure predicted above, confirmed once fetched (see next paragraph).
>
> **Resolved (Stage 6 HUD import):** `Octet - Gameplay HUD.dc.html` also contains **three** layout directions, internally labelled `1a`/`1b`/`1c` (not "2A") under one turn ("Gameplay HUD — 3 layout directions"). **Option 1a is what's implemented** in `game/gameplay.tscn`/`game/playfield_view.gd` — "Classic centered", a compact 640×910 playfield with the judgment line near the bottom, a top HUD row (title/artist/difficulty left, score centred, accuracy/combo right), and a horizontal health bar directly under the score — the conventional rhythm-game layout and the file's first/default direction, same reasoning as the editor's 2a pick. `1b` (full-bleed stream, vertical health bar) and `1c` (glass-panel HUD, segmented health) were not implemented. Everything on the *required* list — 8 mirrored lanes, judgment line, falling tap/hold/chord notes, live score/combo/accuracy in mono, health bar, judgment popups, hit burst — is implemented.
>
> Also resolved: the Claude Design MCP access was previously (incorrectly) reported as unavailable across Stages 3-5. It works fine — call `DesignSync.get_project`/`list_files`/`get_file` against the **specific project ID** (`cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`), not `list_projects` (which only lists design-system-type projects and will come back empty for a project like this one, which `get_project` confirms is `PROJECT_TYPE_PROJECT`, not `PROJECT_TYPE_DESIGN_SYSTEM`). See `docs/BUILD_PLAN.md`'s Stage 6 handoff for the full story.

## Fidelity pass (2026-07-02): global hitbox fix + full-game mockup rebuild

Triggered by two reports: buttons across the whole game had a "click lower than the visual" hitbox offset, and gameplay didn't look like the Claude mockup.

**Hitbox root cause — global, not per-scene.** `project.godot`'s `[display]` block opened the window at the full 1920×1080 design-canvas size with no `window_size/window_*_override`. On any display where 1080p doesn't fully fit (title bar, taskbar, OS display scaling), the OS-resized window and the render canvas ended up scaled/shifted relative to the input transform — a uniform offset on every Control in every scene. This is a different bug from Stage 6's editor-only fixed-row-height hitbox fix (`docs/BUILD_PLAN.md`'s Stage 6 section) — that one was per-scene layout; this one is the window/display config. Fixed by adding `window_width_override=1280`/`window_height_override=720` (same 16:9 aspect, so the 1920×1080 mockup coordinate space stays exact) — the window now opens at a size every display can actually show uncropped, giving a clean uniform scale with no OS-driven shift.

**Root cause of the visual drift — built from prose, not the mockup.** Every built screen except the editor (Main Menu, Song Select, Gameplay HUD, Results, Calibration) had been implemented from this document's prose summaries and `DESIGN_BRIEF.md`, not from the actual `.dc.html` files. The Gameplay HUD's previously-recorded "scope cuts" (radial background gradient + breathing vignette dropped; health-bar gradient fill approximated as solid) are the clearest symptom — those elements exist in the real mockup and are not actually hard to build in Godot. All five non-editor screens were rebuilt from mockups re-fetched fresh in this session; the editor (already genuinely mockup-driven since Stage 6) was audited against a re-fetched `Octet - Editor.dc.html` and got one residual fix (Play/Stop transport buttons now use the same rounded icon-square treatment as the tool rail, matching 2a's top bar). This is also what prompted the new design-fidelity rule in `CLAUDE.md` §2, above.

**New shared component:** `ui/radial_background.gd`/`.tscn` — a reusable radial top-glow + breathing pink vignette background, instanced by Main Menu, Gameplay HUD, Results, and Calibration (all four mockups share this exact treatment; Song Select and the Editor use a flat background, matching their mockups).

**Known, deliberate deviations from the mockups** (Godot UI capability gaps, not oversights — flagged per the design-fidelity rule rather than silently approximated):
- Godot `Control`s have no CSS `mask-image`/blur/`backdrop-filter` equivalent without a custom shader: the main menu's ambient lane-columns have no left-edge feather mask; text "glow" (wordmark, grade) is approximated via an animated font outline, not a true blurred shadow.
- No rounded-circle gradient fill without a shader: the main menu's profile avatar is a flat `COLOR_PINK` circle, not the mockup's diagonal pink→orchid gradient.
- `StyleBoxFlat` corner rounding is a draw style, not a clip mask, so a rectangular fill inset inside a very thin rounded pill (the gameplay health bar) can show a hairline-scale square sliver past the rounded end-cap; the health-bar glow (CSS `box-shadow`) has no cheap equivalent at that scale and was skipped.
- Cover-art / preview swatches (Song Select) are square-cornered, not rounded, for the same reason; the diagonal-stripe "no cover art" placeholder is approximated with a hand-built tileable texture rather than a literal CSS `repeating-linear-gradient`.
- Sample data shown in the mockups (song titles, "kayvox / RANK #1,204", "YOUR BEST" scores, "NEW BEST" badge) is never faked — screens show honest placeholder/empty states until the real data source exists (profile system: Stage 7/8; score persistence: not yet built).

## How Claude Code uses this

1. Connect the Claude Design MCP (`/design-login`) and import the project above.
2. When building the **gameplay HUD (M1)** and the **editor (M2)**, implement them from these imported files — variant **1a** for the HUD, variant **2a** for the editor — matching layout, hierarchy, colour, and type exactly.
3. Every other screen follows `DESIGN_BRIEF.md`.
4. Keep the Octet palette and type consistent across imported and hand-built screens.

## Important — these are design mockups, not runtime code

The files are Claude Design HTML (`.dc.html`). Octet is a **Godot 4** app. Translate each design into Godot UI (Control nodes / scenes), preserving the visual design — do **not** embed HTML in the game. The `.dc.html` files are the visual target, not literal code to drop in.
