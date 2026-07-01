# Design handoff

The **Editor** and **Gameplay HUD** are designed in Claude Design and imported into the build via the Claude Design MCP. Every other screen follows [`DESIGN_BRIEF.md`](DESIGN_BRIEF.md).

## Claude Design project

- **Project:** https://claude.ai/design/p/cc6f9e35-9183-4b42-8d8a-be6dfc135fe1
- **Import via the Claude Design MCP:** endpoint `https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`.

## Chosen designs to implement

| Screen | Variant | File |
|--------|---------|------|
| Editor | 1A | `Octet - Editor.dc.html` |
| Gameplay HUD | 2A | `Octet - Gameplay HUD.dc.html` — *confirm exact file name* |

> Note on mapping: variants read as 1A → Editor, 2A → Gameplay HUD. Confirm the HUD file's exact name and that this pairing is right; everything else is locked.

## How Claude Code uses this

1. Connect the Claude Design MCP (`/design-login`) and import the project above.
2. When building the **gameplay HUD (M1)** and the **editor (M2)**, implement them from these imported files — variant **2A** for the HUD, variant **1A** for the editor — matching layout, hierarchy, colour, and type exactly.
3. Every other screen follows `DESIGN_BRIEF.md`.
4. Keep the Octet palette and type consistent across imported and hand-built screens.

## Important — these are design mockups, not runtime code

The files are Claude Design HTML (`.dc.html`). Octet is a **Godot 4** app. Translate each design into Godot UI (Control nodes / scenes), preserving the visual design — do **not** embed HTML in the game. The `.dc.html` files are the visual target, not literal code to drop in.
