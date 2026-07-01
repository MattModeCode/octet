# Design handoff

The **Editor** and **Gameplay HUD** are designed in Claude Design and imported into the build via the Claude Design MCP. Every other screen follows [`DESIGN_BRIEF.md`](DESIGN_BRIEF.md).

## Claude Design project

- **Project:** https://claude.ai/design/p/cc6f9e35-9183-4b42-8d8a-be6dfc135fe1
- **Import via the Claude Design MCP:** endpoint `https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`.

## Chosen designs to implement

| Screen | Variant | File |
|--------|---------|------|
| Editor | **2a** ("Standard DAW layout — waveform top, tool rail left, inspector right") | `Octet - Editor.dc.html` |
| Gameplay HUD | 2A | `Octet - Gameplay HUD.dc.html` — *confirm exact file name* |

> **Resolved (Stage 6):** the "1A"/"2A" shorthand below was an unconfirmed guess made before either file had actually been fetched from the Claude Design MCP. `Octet - Editor.dc.html` turned out to contain **three** layout options, internally labelled `2a`/`2b`/`2c` (not "1A") under one turn ("Editor — 3 layout directions"). **Option 2a is what's implemented** in `editor/editor_main.tscn` — it's also the file's own suggested next step ("make 2a the primary editor, add zoom controls"). If the Gameplay HUD file turns out to have the same multi-option structure when it's eventually fetched, expect its real option ID to need the same kind of correction here.
>
> Also resolved: the Claude Design MCP access was previously (incorrectly) reported as unavailable across Stages 3-5. It works fine — call `DesignSync.get_project`/`list_files`/`get_file` against the **specific project ID** (`cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`), not `list_projects` (which only lists design-system-type projects and will come back empty for a project like this one, which `get_project` confirms is `PROJECT_TYPE_PROJECT`, not `PROJECT_TYPE_DESIGN_SYSTEM`). See `docs/BUILD_PLAN.md`'s Stage 6 handoff for the full story.

## How Claude Code uses this

1. Connect the Claude Design MCP (`/design-login`) and import the project above.
2. When building the **gameplay HUD (M1)** and the **editor (M2)**, implement them from these imported files — variant **2A** for the HUD, variant **1A** for the editor — matching layout, hierarchy, colour, and type exactly.
3. Every other screen follows `DESIGN_BRIEF.md`.
4. Keep the Octet palette and type consistent across imported and hand-built screens.

## Important — these are design mockups, not runtime code

The files are Claude Design HTML (`.dc.html`). Octet is a **Godot 4** app. Translate each design into Godot UI (Control nodes / scenes), preserving the visual design — do **not** embed HTML in the game. The `.dc.html` files are the visual target, not literal code to drop in.
