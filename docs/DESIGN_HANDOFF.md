# Design handoff

The **Editor** and **Gameplay HUD** are designed in Claude Design and imported into the build via the Claude Design MCP. Every other screen follows [`DESIGN_BRIEF.md`](DESIGN_BRIEF.md).

## Claude Design project

- **Project:** https://claude.ai/design/p/cc6f9e35-9183-4b42-8d8a-be6dfc135fe1
- **Import via the Claude Design MCP:** endpoint `https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`.

## Chosen designs to implement

| Screen | Variant | File |
|--------|---------|------|
| Editor | **2a** ("Standard DAW layout — waveform top, tool rail left, inspector right") | `Octet - Editor.dc.html` |
| Gameplay HUD | **1a** ("Classic centered — compact playfield, top HUD row, horizontal health bar") | `Octet - Gameplay HUD.dc.html` |

> **Resolved (Stage 6):** the "1A"/"2A" shorthand below was an unconfirmed guess made before either file had actually been fetched from the Claude Design MCP. `Octet - Editor.dc.html` turned out to contain **three** layout options, internally labelled `2a`/`2b`/`2c` (not "1A") under one turn ("Editor — 3 layout directions"). **Option 2a is what's implemented** in `editor/editor_main.tscn` — it's also the file's own suggested next step ("make 2a the primary editor, add zoom controls"). The Gameplay HUD file turned out to have the exact same multi-option structure predicted above, confirmed once fetched (see next paragraph).
>
> **Resolved (Stage 6 HUD import):** `Octet - Gameplay HUD.dc.html` also contains **three** layout directions, internally labelled `1a`/`1b`/`1c` (not "2A") under one turn ("Gameplay HUD — 3 layout directions"). **Option 1a is what's implemented** in `game/gameplay.tscn`/`game/playfield_view.gd` — "Classic centered", a compact 640×910 playfield with the judgment line near the bottom, a top HUD row (title/artist/difficulty left, score centred, accuracy/combo right), and a horizontal health bar directly under the score — the conventional rhythm-game layout and the file's first/default direction, same reasoning as the editor's 2a pick. `1b` (full-bleed stream, vertical health bar) and `1c` (glass-panel HUD, segmented health) were not implemented. One deliberate scope cut from the mockup: the background's radial gradient + breathing vignette was dropped (flat `COLOR_INK`, matching every other screen) — it's decorative and not on `DESIGN_BRIEF.md`'s required HUD element list, and layering it correctly under the opaque background would have needed an extra draw layer for a purely cosmetic win. The health bar's gradient fill is approximated as solid `COLOR_PINK` for the same reason (`ColorRect` has no gradient fill). Everything on the *required* list — 8 mirrored lanes, judgment line, falling tap/hold/chord notes, live score/combo/accuracy in mono, health bar, judgment popups, hit burst — is implemented.
>
> Also resolved: the Claude Design MCP access was previously (incorrectly) reported as unavailable across Stages 3-5. It works fine — call `DesignSync.get_project`/`list_files`/`get_file` against the **specific project ID** (`cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`), not `list_projects` (which only lists design-system-type projects and will come back empty for a project like this one, which `get_project` confirms is `PROJECT_TYPE_PROJECT`, not `PROJECT_TYPE_DESIGN_SYSTEM`). See `docs/BUILD_PLAN.md`'s Stage 6 handoff for the full story.

## How Claude Code uses this

1. Connect the Claude Design MCP (`/design-login`) and import the project above.
2. When building the **gameplay HUD (M1)** and the **editor (M2)**, implement them from these imported files — variant **1a** for the HUD, variant **2a** for the editor — matching layout, hierarchy, colour, and type exactly.
3. Every other screen follows `DESIGN_BRIEF.md`.
4. Keep the Octet palette and type consistent across imported and hand-built screens.

## Important — these are design mockups, not runtime code

The files are Claude Design HTML (`.dc.html`). Octet is a **Godot 4** app. Translate each design into Godot UI (Control nodes / scenes), preserving the visual design — do **not** embed HTML in the game. The `.dc.html` files are the visual target, not literal code to drop in.
