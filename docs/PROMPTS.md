# Prompts

Two ready-to-paste prompts. The **Editor** and **Gameplay HUD** are already designed in Claude Design and imported at build time (see `DESIGN_HANDOFF.md`) — use prompt A only for the remaining screens, then use prompt B to build the game.

---

## A. Claude Design — mockups

> I'm designing **Octet**, an eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community, for Windows and macOS. I need high-fidelity UI mockups. The full visual spec is in `DESIGN_BRIEF.md` (attached) — follow it exactly for palette, typography, and feel. Do not use any other brand's colours.
>
> **Identity in short:** dark, warm, kinetic, precise — a dark stage lit by saturated warm neon, not a cold sci-fi interface. Base ink `#0C0A0F`, surfaces `#16131B`, primary accent Octet pink `#FF2D6E`, secondary amber `#FFC93C`. Lane colours are mirrored across the two hands: A/; orchid `#B14AED`, S/L pink `#FF2D6E`, D/K coral `#FF7A3C`, F/J amber `#FFC93C`. Display font Space Grotesk, UI font Inter, HUD numbers in JetBrains Mono (tabular).
>
> The **Gameplay HUD** and the **Editor** are already designed (imported separately via the Claude Design MCP — see `DESIGN_HANDOFF.md`), so skip those two. Design the remaining screens, matching that established look.
>
> **Design these screens at 1920×1080 (16:9), high fidelity:**
> 1. Main menu / home
> 2. Song select (map list + detail/preview panel + sort/filter)
> 3. Gameplay HUD — eight mirrored-colour lanes, a judgment line near the bottom, falling tap/hold/chord notes, live score + combo + accuracy in mono, a health bar, judgment popups, and the hit burst
> 4. Results screen — grade, accuracy, max combo, score, per-judgment breakdown, early/late hit-error histogram, retry/next
> 5. Calibration screen — tap-to-the-beat with metronome visual and resulting offset values
> 6. Editor — horizontal waveform + beat-grid overlay + playhead on top; vertical eight-lane note timeline; note-tool palette; snap-division selector (1/1…1/16); transport (play/scrub/speed/metronome); difficulty tabs; note/timing inspector; visible BPM + offset fields
> 7. Map hub / browser — grid of community maps with cover art, stars, downloads, ratings, search + filters; plus a map detail page with a per-map leaderboard
> 8. Profile — global rank, stats, recent plays, best scores
> 9. Sign-in — email + Google, minimal
>
> Also produce a component sheet: buttons (primary / secondary / ghost), inputs, dropdowns, sliders, tabs, cards, the health bar, and note skins in every lane colour and state (idle / hit / missed).
>
> Prioritise the **gameplay HUD** and the **editor** — they carry the product. Keep motion cues implied (gl/burst/pulse) but restrained, and assume a "reduced flash" option exists. Reinforce lane identity with position and optional shapes, not colour alone.

---

## B. Claude Code — build

> Build **Octet**, an eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community, for Windows and macOS. This repo contains the full spec — read it first: `docs/PROJECT_BRIEF.md` (what to build), `docs/DESIGN_BRIEF.md` (how it looks), `docs/DESIGN_HANDOFF.md` (pre-made designs to import), the attached mockups (visual target), `docs/BOOTSTRAP_SPEC.md`, and `CLAUDE.md` (how to operate).
>
> **Design import — the Editor and Gameplay HUD are already designed.** Connect the Claude Design MCP (endpoint `https://api.anthropic.com/v1/design/mcp`, auth via `/design-login`) and import this project: https://claude.ai/design/p/cc6f9e35-9183-4b42-8d8a-be6dfc135fe1 . Implement `Octet - Editor.dc.html` (variant **1A**) as the editor UI and the Gameplay HUD file (variant **2A**) as the HUD, matching them exactly — build the HUD design at M1 and the editor design at M2. These are Claude Design HTML mockups (`.dc.html`); **translate them into Godot 4 UI (Control nodes/scenes) — do not embed HTML in the game.** Every other screen follows `docs/DESIGN_BRIEF.md`. See `docs/DESIGN_HANDOFF.md`.
>
> **Stack:** Godot 4 (GDScript; optional Rust GDExtension for audio analysis) + Firebase (Auth, Firestore, Cloud Storage, Cloud Functions). Backend behind a thin `/net` REST client.
>
> **Critical operating rule — no version control.** Do **not** run `git init`, `git add`, `git commit`, or `git push`, and do **not** install any auto-commit/auto-push hook. I handle all version control and uploads myself. Just create and edit files in place.
>
> **Start at M0 → M1** from the milestones in the project brief:
> - M0: project scaffold, input + rebinding, one lane, a falling note, hit detection, one judgment — prove the audio "conductor" clock (drive timing from audio playback position + `AudioServer` latency compensation, not frame delta).
> - M1 (first playable): all eight lanes on the home row (A S D F / J K L ;); taps, chords, holds; the timing windows, combo, accuracy, and grade from §2; health/fail with a No-Fail toggle; a results screen; a **calibration screen** for audio/input offset; a scroll-speed setting; loading a local `.oct` chart.
>
> Follow the `.oct` / `.octet` formats in §4 exactly. Match the mockups and the design brief for all UI. Keep timing windows, health deltas, and star-rating in a config file so they're tunable. Confirm the plan and the M0/M1 scope with me before writing large amounts of code, then proceed autonomously — terse, answer-first, ask only when genuinely blocked.

---

### Handoff order

1. Editor and Gameplay HUD are already designed in Claude Design (project link in `DESIGN_HANDOFF.md`) — nothing to do here for those two.
2. (Optional) Run the Claude Design prompt (A), attaching `docs/DESIGN_BRIEF.md`, to design the remaining screens. Export them into the repo (e.g. `docs/mockups/`).
3. Open Claude Code in the project folder, attach the repo, run prompt (B). Claude Code connects the Claude Design MCP and imports the Editor + HUD designs as part of the build.
4. Build proceeds M0 → M5. You commit and upload at your own pace.
