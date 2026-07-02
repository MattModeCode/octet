# Agent prompts

One paste-ready prompt per work package from `docs/FEATURE_FIXES_BREAKDOWN.md`, in dependency
order. Give each prompt to a separate Claude Code session. Each prompt is self-contained but
intentionally terse — the depth (root causes, file paths, exact acceptance criteria) lives in the
breakdown doc, which every prompt tells the agent to read first.

Run **A** and **B** first — nearly everything else depends on one or both. **C** and **D** can run
in parallel with each other and with the fidelity passes. **G–L** (per-screen fidelity) can run in
parallel with each other once A/B are done. **M** is the largest and most independent; run it
whenever convenient after A/B.

---

## WP-A — Global render & font fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-A** section and `CLAUDE.md` first. Fonts render
> blurry throughout Octet and don't match the crisp Claude Design mockups — this is a global
> rendering-config problem, not per-screen code: the `canvas_items` stretch mode downscales the
> whole UI 0.667× (1920→1280 window override), all three font resources are `SystemFont`s with no
> real `.ttf` binaries checked in and no MSDF/oversampling, and gradient backgrounds use NEAREST
> texture filtering. Fix all three: bring in real SIL-OFL binaries for Inter/Space Grotesk/JetBrains
> Mono and switch the font resources from `SystemFont` to `FontFile`, resolve the canvas/window scale
> mismatch so mockup-pixel coordinates render crisp (without reintroducing the earlier button-hitbox
> offset bug — read `docs/DESIGN_HANDOFF.md` for that history), and fix texture filtering on the
> radial gradient backgrounds. Verify by loading a few screens headless and checking text sharpness
> and background smoothness against a freshly-fetched mockup (don't rely on memory of what a mockup
> looks like). This WP blocks nearly everything else — flag when done so screen-fidelity passes can
> start.

---

## WP-B — Global navigation, ESC/back & pause overlay

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-B** section and `CLAUDE.md` first. Two related
> problems: (1) playtesting a map from the editor and letting the song finish sends you to Song
> Select instead of back to the editor — root cause is `game/results.gd`'s Back button hardcoding
> `SceneRouter.goto_scene(SONG_SELECT_SCENE)` instead of consulting where the run came from; (2)
> there is no ESC/back convention anywhere and no pause menu in gameplay at all. Fix: add a
> playtest-origin flag that survives the editor→gameplay→results round-trip (`PlaySession` or
> `EditorSession`, both autoloads) so Results' Back returns to the editor when appropriate; wire a
> shared ESC-goes-back handler onto every screen with a back concept (Song Select, Calibration,
> Editor, Results, and the future Map Hub); and add a pause overlay in gameplay (ESC pauses via
> `Conductor.pause()`, shows Resume/Restart/Quit). Reuse the existing `SceneRouter` autoload
> (`scene_stack`, `go_back()`, `goto_scene_pushed()`) — don't build a second navigation system. This
> WP blocks most fidelity WPs that touch Back buttons (Results, Calibration, Map Hub).

---

## WP-C — Author 3 difficulty charts for the song

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-C** section first. Author 3 `.oct` charts (Easy/
> Normal/Hard) for `ThatsWhyIGaveUpOnMusic.mp3` (repo root) — without hand-placing notes in the
> in-game editor. Use the existing `editor/audio_analysis.gd` (`AudioAnalysis.analyze()`) and
> `editor/audio_import.gd` for BPM/offset/onset detection to drive an automated first pass, then
> quantize/thin/curate per difficulty so notes are actually musical (on-beat, not raw onset noise) —
> some manual tuning of timings against the audio is expected, that's fine, it just shouldn't go
> through the in-app map editor UI. Follow the exact `.oct` JSON schema in `core/chart.gd` and
> siblings (see the breakdown doc for a worked example). Place the song + charts where Song Select
> can find them, extending its scan path in `game/song_select.gd` if needed, with matching
> title/artist metadata across all 3 so they group as one song with 3 difficulty tabs. Note: these
> charts won't play against real audio until WP-F (real song playback) lands — check whether that's
> done first, or coordinate.

---

## WP-D — Editor BPM auto-detect UX

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-D** section first. BPM/offset detection is already
> fully implemented (`editor/audio_analysis.gd`, wired manually via `editor/editor_main.gd`'s
> "Analyze" button) — this task is UX, not algorithm work: make analysis run automatically right
> after audio import instead of requiring a manual button press, immediately populate the BPM/offset
> fields and beat grid, and keep a manual re-analyze option available without silently clobbering a
> value the user has since hand-edited. Verify by importing audio in the editor headless/manually
> and confirming BPM+offset populate without an extra click.

---

## WP-E — Local best-score persistence

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-E** section first. Best-score/leaderboard tracking
> doesn't work because it was never built — not a broken read/write path. Add local persistence
> only (online leaderboard is explicitly out of scope): a `user://` store (follow the pattern in
> `core/settings_store.gd`, which already persists to `user://settings.tres`), keyed by chart
> path/difficulty, written from `game/gameplay.gd`'s `_finish()` using data already exposed by
> `game/judge_engine.gd`'s `JudgeEngine` (`score`, `accuracy()`, `grade()`, `max_combo`, ranked
> status). Read it back in `game/song_select.gd`'s "Your Best" card (currently hardcoded to `"—"`)
> and add a NEW BEST badge to `game/results.gd`. Verify by playing a chart twice and confirming the
> best score persists and displays correctly, including across an app restart.

---

## WP-F — Audio/music playback expansion

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-F** section first. Three related audio gaps: (1)
> gameplay currently plays a synthesized metronome click track instead of the real song
> (`game/gameplay.gd`'s `_build_backing_track()`, marked in comments as a placeholder) — replace it
> with loading the chart's actual audio via `editor/audio_import.gd` and playing it through the
> `Conductor` autoload (which already supports arbitrary streams and derives timing from real
> playback position, not frame delta — don't bypass it); (2) add ambient music cycling through
> available songs on the home screen (`ui/main.tscn`/`.gd`); (3) add song preview playback on Song
> Select when a song is selected, using `ChartMetadata.preview_time_ms` (currently unused). Verify by
> running gameplay and confirming the actual song plays in sync with notes, and that Song Select
> previews audio on selection without overlapping tracks when switching songs.

---

## WP-G — Gameplay HUD + playfield fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-G** section and `CLAUDE.md` §2 (design-fidelity
> rule) first. Confirm WP-A (global render/font fix) has landed — most of the reported mismatch
> (washed-out background, tiny text) traces to that, not to this screen's own layout code. **Before
> touching anything, re-fetch `Octet - Gameplay HUD.dc.html` variant 1a live** from the Claude Design
> MCP (project `cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`, via `DesignSync.get_file` — never build from
> memory or this document's description). Compare the running `game/gameplay.tscn` /
> `game/playfield_view.gd` against it pixel-for-pixel: note rendering (confirm whether the mockup
> actually wants plain circles or richer note skins — don't assume), header/score/combo/health layout
> and typography, judgment line, hit bursts. Fix any remaining gaps after the WP-A render fix. Flag
> any element that genuinely can't be replicated in Godot rather than silently approximating it.

---

## WP-H — Song Select fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-H** section and `CLAUDE.md` §2 first. Re-fetch
> `Octet - Song Select.dc.html` live from the Claude Design MCP (project
> `cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`) before touching code. Known specific gaps: the Filters
> button doesn't match the mockup's style, and the text under the right-side preview panel is
> different from the mockup — fix both, then check the rest of the screen for drift too. If WP-E
> (best-score persistence) and WP-F (song preview audio) are done, wire the "Your Best" card and
> preview playback to real data instead of the current placeholders. Confirm every element matches
> the freshly-fetched mockup before considering this done.

---

## WP-I — Main Menu fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-I** section and `CLAUDE.md` §2 first. Re-fetch
> `Octet - Main Menu.dc.html` live before touching code. Fidelity-check layout/type/colour/ambient
> background against it. `ui/main.gd` already references a Browse Maps target
> (`res://ui/map_hub.tscn`) that doesn't exist yet — if WP-M (Map Hub) is done, wire it up; if not,
> leave it as-is (the router already no-ops safely rather than crashing) and note it as pending.
> Profile is out of scope (Stage 7/8, gated on Firebase) — don't build it, just make sure its button
> doesn't error; a disabled or "coming soon" state is fine, confirm with the user if truly ambiguous.

---

## WP-J — Results fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-J** section and `CLAUDE.md` §2 first. Re-fetch
> `Octet - Results.dc.html` live before touching code — check grade/accuracy/combo/judgment
> breakdown/histogram layout, type, and colour against it. This screen also depends on two other
> WPs: confirm WP-B (Back button should return to the editor after a playtest, not always Song
> Select) and WP-E (best-score persistence, for a NEW BEST badge) are done, and wire/verify both are
> correctly connected here rather than re-solving them from scratch.

---

## WP-K — Calibration fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-K** section and `CLAUDE.md` §2 first. This screen
> was already rebuilt to match its mockup in a prior pass (see `docs/DESIGN_HANDOFF.md`'s Jul 2
> notes) — re-fetch `Octet - Calibration.dc.html` live anyway and re-verify nothing has drifted,
> then add the ESC-goes-back binding from WP-B if it isn't already wired here.

---

## WP-L — Editor fidelity

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-L** section and `CLAUDE.md` §2 first. Re-fetch
> `Octet - Editor.dc.html` variant **2a** live before touching code. Transport button styling was
> already fixed in a prior pass — check the rest of the DAW layout against the fresh mockup:
> waveform + beat-grid + playhead, vertical 8-lane note timeline, note-tool palette, snap-division
> selector, difficulty tabs, note/timing inspector, BPM/offset field placement (which also gets the
> WP-D auto-detect UX separately — coordinate if both are in flight).

---

## WP-M — Browse Maps: GitHub-hosted community hub

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-M** section and `CLAUDE.md` §2 first. Build the
> missing "Browse Maps" screen as a community map hub backed by a GitHub repo (index manifest +
> downloadable `.octet` bundles via repo files or Release assets — your call which). **The mockup to
> implement is `Octet - Map Hub.dc.html`, re-fetched live from the Claude Design MCP — not
> `Octet - Index.dc.html`, which is only a gallery contact-sheet linking to every mockup, not a real
> screen.** Build the grid browser (search, sort tabs, filters, map cards) and the detail+leaderboard
> view it also contains. Fetch the manifest via `HTTPRequest`; on download, reuse the existing
> `core/octet_bundle.gd` bundle-reading code to unpack into `user://songs/` so downloaded maps
> automatically show up in Song Select (which already scans that folder — don't build a second scan
> path). Document the publish/upload flow for mappers (a manual GitHub PR/Release upload is
> acceptable for v1; full in-app publishing is a stretch goal). The mockup's per-map leaderboard has
> no real backend yet — stub it with an explicit "coming soon" state or clearly-labeled placeholder
> data rather than fabricating live-looking scores, and call that out when reporting back.

---

## WP-N — Component sheet (optional)

> Read `docs/FEATURE_FIXES_BREAKDOWN.md`'s **WP-N** section and `CLAUDE.md` §2 first. Re-fetch
> `Octet - Components.dc.html` live. Extract shared button/input/dropdown/slider/tab/card/health-bar/
> note-skin styling into reusable `ui/` components and/or `assets/theme/octet_theme.tres` entries, so
> the per-screen fidelity passes (WP-G through WP-L) can consume shared primitives instead of each
> duplicating StyleBoxFlat definitions inline. Optional — only pick this up if the other WPs are
> covered or you're explicitly asked to reduce duplication across them.
