# Feature fixes breakdown

Working list of everything raised in the 2026-07-02 fidelity/bug pass, broken into independent
work packages (WPs) so separate Claude Code sessions can each pick one up with full context. Each
WP below is self-contained: problem, root cause, scope, files, mockup (if visual), acceptance
criteria, dependencies.

Companion doc: `docs/AGENT_PROMPTS.md` has one ready-to-paste prompt per WP, in the order below.

**Design-fidelity rule applies to every visual WP** (CLAUDE.md §2): always re-fetch the mockup live
from the Claude Design MCP — project `cc6f9e35-9183-4b42-8d8a-be6dfc135fe1` — via
`DesignSync.get_project` / `list_files` / `get_file` against that project ID. Never build from
memory or a prose summary. `list_projects` returns empty for this project (it's a regular project,
not a design-system project) — go straight to `get_file` with the exact path.

**Correction on scope:** the user referenced `Octet - Index.dc.html` for the community "browse
maps" hub. That file is only the **mockup gallery contact sheet** — a page of cards linking to
every other mockup, not a screen to implement. The real target for the community hub is
**`Octet - Map Hub.dc.html`**, which contains the grid browser + map detail + leaderboard. See WP-M.

## Suggested execution order

1. **WP-A** (render/fonts) — do first, unblocks all visual work
2. **WP-B** (navigation/ESC/pause) — do first, unblocks playtest and every screen's back button
3. **WP-F** (real audio playback)
4. **WP-E** (local score persistence)
5. **WP-C** (3 difficulty charts) and **WP-D** (editor BPM UX) — parallel, both depend on WP-F/nothing resp.
6. **WP-G … WP-L** (per-screen fidelity passes) — parallel, each depends on WP-A/WP-B and sometimes WP-E/WP-F
7. **WP-M** (Map Hub / GitHub community hub)
8. **WP-N** (component sheet) — optional, supports consistency across WP-G…L

| WP | Title | Depends on |
|----|-------|------------|
| A | Global render & font fidelity | — |
| B | Global navigation, ESC/back & pause overlay | — |
| C | Author 3 difficulty charts for the song | F |
| D | Editor BPM auto-detect UX | — |
| E | Local best-score persistence | — |
| F | Audio/music playback expansion | — |
| G | Gameplay HUD + playfield fidelity | A |
| H | Song Select fidelity | A, E, F |
| I | Main Menu fidelity | A, M (button wiring) |
| J | Results fidelity | A, B, E |
| K | Calibration fidelity | A, B |
| L | Editor fidelity | A |
| M | Browse Maps: GitHub-hosted community hub | A, B |
| N | Component sheet (optional) | — |

---

## WP-A — Global render & font fidelity

**Problem (issue #8):** fonts render blurry throughout the app and don't match the crisp mockup
type; backgrounds look washed out.

**Root cause (confirmed, not per-screen code):** three global settings in `project.godot` and
`assets/fonts/`:
1. `[display] window/stretch/mode="canvas_items"` renders the whole UI at the 1920×1080 design
   canvas, then downscales into the 1280×720 window override (`window_width_override`/
   `window_height_override`) — a uniform 0.667× shrink of everything, including all text.
2. `assets/fonts/font_ui.tres`, `font_display.tres`, `font_mono.tres` are all Godot `SystemFont`
   resources (`font_names = ("Inter","sans-serif")` etc.) with **no `.ttf` binaries checked in**
   (confirmed by `assets/fonts/README.md` — documented as a known temporary state). No MSDF, no
   oversampling anywhere in `project.godot` (no `[gui]` section at all).
3. `[rendering] textures/canvas_textures/default_texture_filter=0` (NEAREST) on the radial-gradient
   backgrounds (`ui/radial_background.gd`'s `GradientTexture2D`s), contributing to a washed-out/
   stepped look.

**Scope & approach:**
- Download the SIL-OFL binaries for Inter, Space Grotesk, and JetBrains Mono; check them into
  `assets/fonts/` and swap each `SystemFont` resource to a `FontFile` pointing at the binary.
- Enable font oversampling / consider MSDF for crisp text at the downscaled window size.
- Resolve the canvas-vs-window scale mismatch: either match viewport size to window size 1:1 (no
  downscale) or use an integer-friendly stretch/scale so mockup-pixel coordinates land on real
  pixels. Whatever is chosen must not reintroduce the earlier hitbox-offset bug (see
  `docs/DESIGN_HANDOFF.md`'s note on the window-override fix).
- Set texture filtering on the gradient backgrounds to linear (or bake at target resolution) so
  they aren't stair-stepped.

**Files:** `project.godot` (`[display]`, `[rendering]`), `assets/fonts/font_ui.tres`,
`font_display.tres`, `font_mono.tres`, `assets/fonts/README.md` (update once binaries land),
`assets/theme/octet_theme.tres` (default font wiring), `ui/radial_background.gd`.

**Mockup:** none directly — this is a rendering-infrastructure fix, verify against any screen mockup
(e.g. `Octet - Main Menu.dc.html`) for text crispness/size after the change.

**Acceptance:** text renders sharp (no bilinear softening) at the 1280×720 window; font look is
consistent across machines regardless of installed system fonts; header/label text sizes read
clearly at a glance, matching mockup proportions; gradient backgrounds look smooth, not washed out
or banded; no regression of the hitbox-offset fix.

---

## WP-B — Global navigation, ESC/back & pause overlay

**Problem (issue #2):** playtesting a map in the editor drops you at map selection instead of back
in the editor; there's no way to get back to the main menu from most screens; no ESC/back
convention anywhere; no pause in gameplay.

**Root cause (confirmed):**
- Navigation runs through one autoload, `SceneRouter` (`ui/scene_router.gd`): `goto_scene(path)`,
  `goto_scene_pushed(path)` (pushes current scene onto `scene_stack`), `go_back()` (pops the
  stack). This part works correctly everywhere it's used as designed.
- **The playtest round-trip bug:** `editor/editor_main.gd:_on_playtest_pressed()` does
  `SceneRouter.goto_scene_pushed("res://game/gameplay.tscn")` (stack: `[editor_main]`). Gameplay
  finishing does `SceneRouter.goto_scene_pushed(results)` (stack: `[editor_main, gameplay]`,
  `game/gameplay.gd:136`). But **Results' Back button ignores the stack entirely**:
  `game/results.gd:250` hardcodes `SceneRouter.goto_scene(SONG_SELECT_SCENE)`. So after a playtest
  finishes, Back always lands on Song Select, never the editor. (Quitting mid-playtest instead of
  finishing does work correctly today via `go_back()`, because it only pops one frame.)
  A correct fix needs more than swapping in `go_back()` — even a stack pop would land on
  `gameplay.tscn` (the top of the stack after the push in step 2), not the editor, and by then
  `PlaySession.pending_chart` / `pending_audio_stream` have already been consumed once. Add an
  explicit "playtest origin" flag/path to `PlaySession` (or `EditorSession`, which already survives
  scene changes) that Results' Back checks first, before falling back to the hardcoded Song Select
  destination.
- **No ESC/back anywhere:** confirmed zero hits for `ui_cancel`/`KEY_ESCAPE`/pause-menu handling
  across the whole codebase. Every screen except Main Menu has an on-screen Back/Quit/Done button
  only; none respond to Escape. There is no pause menu in gameplay at all (existing `pause` hits in
  the codebase are all `Conductor.pause()` audio calls, unrelated).

**Scope & approach:**
- Add a shared ESC/`ui_cancel` handler (a small reusable pattern or a base script) that calls
  `SceneRouter.go_back()` on every screen: Song Select, Calibration, Editor, Results, and the new
  Map Hub (WP-M). Main Menu's ESC can be a no-op or a "confirm quit" — decide when implementing;
  either is acceptable since Main Menu is the root.
- Fix Results' Back to route to the editor when the run originated as an editor playtest (via the
  new origin flag), otherwise keep today's Song Select destination.
- Add a gameplay pause overlay: ESC during gameplay calls `Conductor.pause()` and shows a
  Resume / Restart / Quit overlay (reuse `game/gameplay.tscn`'s existing structure; a new child
  scene/overlay is fine). Resume unpauses and resumes audio from the same position; Restart reloads
  the current chart from the top; Quit behaves like the existing Quit button (`go_back()`).

**Files:** `ui/scene_router.gd`, `core/play_session.gd` (or `editor/editor_session.gd`) for the
origin flag, `game/results.gd`, `game/gameplay.gd` (+ a new pause-overlay scene), and each screen
controller (`game/song_select.gd`, `audio/calibration.gd`, `editor/editor_main.gd`) for the ESC
binding.

**Mockup:** none exists yet for a pause overlay — design it consistent with `DESIGN_BRIEF.md`'s
palette/type (dark surface panel, Space Grotesk headline, pink primary action) rather than
inventing an unrelated style. Flag this as a deviation-needing-confirmation if a dedicated pause
mockup surfaces later.

**Acceptance:** ESC goes back on every screen that has a "back" concept; editor playtest → song
finishes → Results → Back returns to the editor (not Song Select) with editor state intact; ESC
during gameplay pauses audio and shows Resume/Restart/Quit; each of those three options behaves
correctly.

---

## WP-C — Author 3 difficulty charts for the song

**Problem (issue #1):** need 3 difficulties of the same song as playable maps, without using the
in-game editor to place notes by hand, and they must actually match the song's beat/rhythm.

**Song:** `ThatsWhyIGaveUpOnMusic.mp3` (repo root, currently untracked/git-ignored).

**Root cause / current state:** the chart format is plain JSON with a `.oct` extension
(`core/oct_io.gd` load/save, schema in `core/chart.gd` + `core/chart_metadata.gd` +
`core/chart_audio.gd` + `core/timing_point.gd` + `core/chart_note.gd`). Example schema (see
`tests/fixtures/gameplay_fixture.oct`):
```json
{
  "format_version": 1,
  "metadata": { "title": "...", "artist": "...", "mapper": "...", "difficulty_name": "Normal", "star_rating": 1.0, "tags": [], "preview_time_ms": 1000 },
  "audio": { "filename": "song.mp3", "duration_ms": 0 },
  "timing_points": [ { "time_ms": 0, "bpm": 120.0, "meter": 4 } ],
  "notes": [ { "lane": 0, "time_ms": 1000, "type": "tap" }, { "lane": 3, "time_ms": 2000, "type": "hold", "end_time_ms": 2250 } ]
}
```
Lanes are 0–7 (left→right); a chord is just multiple notes sharing `time_ms` on different lanes.
`editor/audio_analysis.gd` (`AudioAnalysis.analyze(pcm, sample_rate)`) already implements BPM +
offset + onset detection (spectral flux → adaptive-threshold onset picking → autocorrelation BPM
with octave-error resolution → offset histogram) — this is the tool to drive note placement, not
something to build from scratch. `editor/audio_import.gd` decodes mp3 to PCM
(`decode_full_pcm()`).

**Scope & approach:**
1. Run `AudioAnalysis.analyze()` (or an equivalent offline script using the same class) against the
   mp3 to get BPM, first-beat offset, and the onset list.
2. Generate three `.oct` files programmatically from the onsets/beat grid: filter/thin the onset
   list per difficulty (Easy = sparse, on-beat only; Normal = eighths + some syncopation; Hard =
   sixteenths + chords/holds), quantizing to the detected beat grid so notes actually land on the
   rhythm rather than raw onset noise.
3. Curate/listen and hand-adjust the generated note timings — automated onset detection is a
   starting point, not a guarantee of a musical chart; some manual pass against the audio is
   expected and fine (this doesn't require using the in-app editor).
4. Place the song + 3 charts where Song Select can find them — today `game/song_select.gd`
   `_scan_charts()` only scans `res://tests/fixtures` and `user://songs`. Add a proper location
   (e.g. `res://songs/thats-why-i-gave-up-on-music/`) and extend the scan path, or drop the trio
   into `user://songs` if that's acceptable for a first pass. Songs group by `title + artist` via
   `_group_songs()`, so all 3 difficulties need matching `title`/`artist` metadata to appear as one
   song with 3 difficulty tabs.

**Depends on WP-F:** gameplay currently plays a synthesized metronome click track, not real song
audio (`game/gameplay.gd:_build_backing_track()`, explicitly commented as a Stage-4+ placeholder).
These charts won't actually be playable against the real song until WP-F wires real audio into
`Conductor` during gameplay.

**Files:** new chart files under `res://songs/...` (or `user://songs`), no engine code changes
required beyond the scan-path addition in `game/song_select.gd` if a new `res://songs/` directory
is introduced.

**Acceptance:** the song appears once in Song Select with 3 difficulty entries (Easy/Normal/Hard or
similar naming); each difficulty's notes are audibly on-beat when played against the real track
(after WP-F); `star_rating` ordering is sane (Easy < Normal < Hard).

---

## WP-D — Editor BPM auto-detect UX

**Problem (issue #3):** editor should auto-detect BPM to make beatmapping easier.

**Root cause / current state:** **detection is already fully implemented**, just not automatic.
`editor/audio_analysis.gd` (`AudioAnalysis.analyze()`) does FFT-based spectral flux onset detection
(`editor/dsp_fft.gd` backs it) and autocorrelation BPM estimation with octave-error correction, plus
offset estimation. It's wired at `editor/editor_main.gd:_on_analyze_pressed()` (~line 351): runs on
a background thread, then writes the result into editable `SpinBox` fields for BPM and offset
(~lines 371–393). Today this only runs when the user manually presses an "Analyze" button.

**Scope & approach:** change the trigger from manual-only to **automatic on audio import** — run
the same background-thread analysis right after `AudioImport.load_audio_file()` succeeds in the
editor, populate the BPM/offset SpinBoxes and the beat grid (`editor/beat_grid.gd`) immediately, and
keep the manual "Analyze"/"Re-detect" button available for re-runs (e.g. after trimming audio, or if
the user disagrees with the detected value — spectral/autocorrelation BPM detection is not
infallible, especially on complex tracks). Consider a small confidence indicator or a "detected
BPM: X — looks right?" prompt rather than silently overwriting a value the user may have already
tuned by hand.

**Files:** `editor/editor_main.gd` (import flow + analyze wiring), `editor/editor_session.gd` (if
state needs to track "auto-detected vs. user-edited" to avoid clobbering manual edits).

**Acceptance:** importing a new audio file auto-populates BPM and first-beat offset without an
extra click, and the beat grid immediately reflects it; manual re-analyze still works; a
user-edited BPM value isn't silently overwritten by a later automatic pass (e.g. only auto-run once
per fresh import).

---

## WP-E — Local best-score persistence

**Problem (issue #4):** leaderboard/score tracking doesn't work — no way to see your best score for
a map.

**Scope decision (confirmed with user):** local best-score per chart only, persisted to disk.
Online leaderboard stays out of scope (blocked on Firebase/Stage 7 per `net/net_client.gd`, which is
a hard stub — `is_online()` always `false`).

**Root cause / current state:** score persistence **does not exist at all** — this isn't a broken
read/write path, it was never built. Confirmed by full-repo grep:
- `game/results.gd` (~line 14 comment): *"No 'NEW BEST' badge either — no score-persistence layer
  exists to compare against."* `_finish()` in `game/gameplay.gd` only sets `PlaySession.last_engine`
  and routes to Results; nothing is written to disk.
- `game/song_select.gd` (~line 467): the "Your Best" card is hardcoded to `"—"` for score/acc/grade
  with the same comment.
- The scoring engine itself is complete and exposes everything needed:
  `game/judge_engine.gd`'s `JudgeEngine` has `score`, `accuracy()`, `grade()` (via
  `game/grading.gd`), `max_combo`, `is_full_combo()`, `is_all_perfect()`; mods gate ranked status.

**Scope & approach:**
- Add a small local store, e.g. `user://scores.json` (or a `ConfigFile`/`.tres` Resource, matching
  the existing pattern in `core/settings_store.gd`'s `user://settings.tres` via `ResourceSaver`),
  keyed by chart identity (chart path + difficulty, or title+artist+difficulty — chart path is
  simplest and matches how Song Select already identifies entries).
- Write on song finish: `game/gameplay.gd:_finish()` (or `game/results.gd`'s `_ready()`), compare
  the new run's score against the stored best; only overwrite if higher (or track best-per-metric
  if that's simpler — best score is the minimum requirement).
- Read back in `game/song_select.gd`'s "Your Best" card (replace the hardcoded `"—"`), and add a
  "NEW BEST" badge to `game/results.gd` when the just-finished run beat the previous best (or is the
  first recorded run).
- Gate on `mods.is_ranked()` if unranked mods shouldn't count toward best score (matches existing
  ranked-mod concept already in `JudgeEngine`/mods).

**Files:** new `core/score_store.gd` (or similar, following the `settings_store.gd` pattern),
`game/gameplay.gd`, `game/results.gd`, `game/song_select.gd`.

**Acceptance:** playing a chart and finishing records a best score to disk; replaying and beating it
updates the store and shows a NEW BEST badge on Results; Song Select's "Your Best" card shows the
persisted score/accuracy/grade instead of `"—"`; restarting the game preserves the best (real disk
persistence, not just in-memory).

---

## WP-F — Audio/music playback expansion

**Problem (issue #5, plus a gameplay-accuracy gap):** no music cycling on the home screen; Song
Select doesn't preview the selected song; and — found during exploration — **gameplay itself
doesn't play the real song**, it plays a synthesized metronome click track standing in for it.

**Root cause / current state:**
- `game/gameplay.gd:_build_backing_track()` (~line 117) generates a click track via
  `audio/metronome.gd` sized to the chart's last note at the first timing point's BPM. The code
  comment marks real audio import as "Stage 4 scope" — i.e. this was always meant to be replaced.
  `Conductor` (`audio/conductor.gd`, the timing-authority autoload) already supports playing an
  arbitrary `AudioStream` via `play(stream, from_ms)` and derives song time from actual playback
  position + latency compensation — it isn't metronome-specific.
- `editor/audio_import.gd` (`AudioImport`) already loads wav/mp3/ogg into an `AudioStream` — this is
  the same utility that should feed both the editor and gameplay.
- Home screen and Song Select have **no** `AudioStreamPlayer` at all today; no ambient music, no
  preview. `ChartMetadata.preview_time_ms` exists in the schema but is unused.

**Scope & approach:**
1. **Real song in gameplay:** replace `_build_backing_track()`'s metronome generation with loading
   the chart's actual audio (`ChartAudio.filename`, resolved relative to the chart/bundle) via
   `AudioImport`, and hand that stream to `Conductor.play()`. Keep the metronome path only as an
   optional/legacy fallback (e.g. missing audio file) if useful, but the primary path must be real
   audio — this directly unblocks WP-C (charts are meaningless against a metronome that doesn't
   match the song's actual audio).
2. **Home screen ambient music:** add a simple `AudioStreamPlayer` on `ui/main.tscn`/`ui/main.gd`
   that cycles through available songs (e.g. the same pool Song Select scans) at low volume,
   looping or advancing to the next track on finish.
3. **Song Select preview:** on selecting a song, play a preview of its audio starting at
   `preview_time_ms` (looping within a short window is a reasonable default), stopping when
   selection changes or the screen is left. Reuse `Conductor` or a dedicated lightweight
   `AudioStreamPlayer` — decide based on whether `Conductor`'s calibration-focused clock is
   overkill for a simple preview (likely a plain `AudioStreamPlayer` is enough here, since precise
   sync isn't required for a preview).

**Files:** `game/gameplay.gd`, `audio/conductor.gd` (if any API additions needed),
`editor/audio_import.gd` (reuse, likely no changes), `ui/main.tscn`/`ui/main.gd`,
`game/song_select.tscn`/`.gd`.

**Acceptance:** gameplay plays the actual song audio (metronome click track no longer the primary
gameplay audio); home screen cycles ambient music from available tracks; selecting a song in Song
Select plays a preview of that song's audio; switching songs or leaving the screen stops the
preview cleanly (no overlapping audio).

---

## WP-G — Gameplay HUD + playfield fidelity

**Problem (issue #6, the attached screenshot):** the main game screen doesn't match the mockup at
all — washed-out radial background, tiny illegible header text, notes rendered as plain flat
circles, HUD elements not matching mockup proportions/typography.

**Mockup:** `Octet - Gameplay HUD.dc.html`, variant **1a** ("Classic centered") — re-fetch live, do
not rely on this document's description.

**Root cause / current state:** `game/gameplay.tscn` already implements the 1a layout structurally
(top-left title/artist/difficulty pill, centered score block, right-aligned acc/combo block, health
bar, `PlayfieldView` control) with baked literal `Color(...)` values matching the design tokens.
`game/playfield_view.gd` is a pure custom-`_draw` layer: lanes, judgment line (with a breathing
glow-pulse), key labels, notes-as-circles (glow halo + solid circle; holds as a translucent tail
rect), hit bursts, judgment popups. The screenshot mismatch is caused mostly by **WP-A's global
rendering issues** (the 0.667× canvas downscale shrinking the 22px title down to ~15px effective,
etc.) plus the washed-out background from NEAREST texture filtering on `ui/radial_background.gd`'s
gradients. What's left after WP-A is genuine layout/detail fidelity: confirm note appearance
(tap/hold/chord skins) matches what the mockup actually shows (the mockup may specify richer note
skins than plain circles — verify by re-fetching, don't assume circles are correct just because
that's what's implemented), spacing/proportions, and the health bar's rounded-corner sliver issue
noted in `DESIGN_HANDOFF.md`.

**Files:** `game/gameplay.tscn`, `game/gameplay.gd`, `game/playfield_view.gd`,
`ui/radial_background.tscn`/`.gd`.

**Depends on:** WP-A (do the render/font fix first — much of the visible gap disappears once that
lands; don't duplicate effort re-tuning sizes that WP-A will change).

**Acceptance:** side-by-side with the freshly-fetched `Octet - Gameplay HUD.dc.html` (1a), the
running scene matches layout, type, colour, and note rendering; no washed-out background; header
text legible at a glance.

---

## WP-H — Song Select fidelity

**Problem (issue #7 example given by user):** the Filters button doesn't look like the mockup, and
the text below the preview on the right side is different from the mockup.

**Mockup:** `Octet - Song Select.dc.html` — re-fetch live.

**Scope & approach:** compare the running `game/song_select.tscn` against the freshly-fetched
mockup control-by-control — filter button style (shape, colour, icon/label), and the detail-panel
copy/typography under the preview. Wire the "Your Best" card to real data once WP-E lands, and the
preview to real audio once WP-F lands (both were previously stubbed — don't reintroduce the "—"
placeholder as if it were a design choice).

**Files:** `game/song_select.tscn`, `game/song_select.gd`.

**Depends on:** WP-A (render fidelity), WP-E (Your Best data), WP-F (preview audio).

**Acceptance:** matches the mockup's filter button and detail-panel text exactly; Your Best card
shows real persisted data; preview plays audio for the selected song.

---

## WP-I — Main Menu fidelity

**Mockup:** `Octet - Main Menu.dc.html` — re-fetch live.

**Root cause / current state:** `ui/main.gd` already references `BROWSE_MAPS_SCENE` and
`PROFILE_SCENE` paths that don't exist yet (`res://ui/map_hub.tscn`, `res://ui/profile.tscn`) — the
router's `ResourceLoader.exists` guard silently no-ops on press today rather than crashing, but
those buttons are effectively dead until WP-M (Map Hub) lands. Profile has a mockup
(`Octet - Profile.dc.html`) but is explicitly out of scope for this pass (Stage 7/8, gated on
Firebase) — leave its button wired to nothing or route to a "coming soon" state, don't build the
full Profile screen here.

**Scope & approach:** fidelity pass on layout/type/colour/ambient-pulse background against the
mockup; wire "Browse Maps" to the new Map Hub once WP-M exists.

**Files:** `ui/main.tscn`, `ui/main.gd`.

**Depends on:** WP-A (render fidelity), WP-M (for the Browse Maps button target).

**Acceptance:** matches mockup; Play/Editor/Browse Maps navigate correctly; Profile button doesn't
error (either hidden, disabled, or a clear "coming soon" state — confirm choice if ambiguous).

---

## WP-J — Results fidelity

**Mockup:** `Octet - Results.dc.html` — re-fetch live.

**Scope & approach:** fidelity pass (grade/accuracy/combo/judgment breakdown/histogram layout,
type, colour per mockup) plus the two functional pieces that land here: the Back-button fix (WP-B)
and the NEW BEST badge (WP-E). Don't treat those as separate work if this WP is picked up after
B and E are done — just verify they're wired.

**Files:** `game/results.tscn`, `game/results.gd`.

**Depends on:** WP-A, WP-B (Back fix), WP-E (NEW BEST data).

**Acceptance:** matches mockup exactly (histogram gradient, judgment breakdown layout); Back
returns to the correct screen (editor or Song Select per WP-B's origin logic); NEW BEST badge shows
when applicable.

---

## WP-K — Calibration fidelity

**Mockup:** `Octet - Calibration.dc.html` — re-fetch live.

**Root cause / current state:** `audio/calibration.gd` was already rebuilt to match this mockup in
the prior fidelity pass (circular metronome, StyleBoxFlat pip styling, RichTextLabel subtitle) per
`DESIGN_HANDOFF.md`'s Jul 2 notes — this WP is primarily about re-verifying against a live mockup
fetch (things may have drifted) and adding the ESC binding from WP-B, not a from-scratch rebuild.

**Files:** `audio/calibration.tscn`, `audio/calibration.gd`.

**Depends on:** WP-A, WP-B (ESC).

**Acceptance:** matches freshly-fetched mockup; ESC returns to Song Select (where calibration is
entered from).

---

## WP-L — Editor fidelity

**Mockup:** `Octet - Editor.dc.html`, variant **2a** ("Standard DAW layout") — re-fetch live.

**Root cause / current state:** transport buttons were already styled to match in the prior pass
(icon-square pattern per `DESIGN_HANDOFF.md`). This WP covers the rest of the DAW layout: waveform +
beat-grid overlay + playhead, vertical 8-lane note timeline, note-tool palette, snap-division
selector, difficulty tabs, note/timing inspector, BPM/offset fields (which also gets the WP-D
auto-detect UX treatment).

**Files:** `editor/editor_main.tscn`, `editor/editor_main.gd`, `editor/waveform_view.gd`,
`editor/note_timeline_view.gd`, `editor/beat_grid.gd` (rendering only, not logic).

**Depends on:** WP-A.

**Acceptance:** matches freshly-fetched 2a mockup across waveform, timeline, palette, snap
selector, transport, tabs, and inspector.

---

## WP-M — Browse Maps: GitHub-hosted community hub

**Problem (issue #7, community hub):** "Browse Maps" needs to be a real community map browser, not
a stub — maps get uploaded somewhere (a GitHub repo, per the user's direction) and the in-game
screen pulls from there and downloads maps.

**Mockup:** **`Octet - Map Hub.dc.html`** — re-fetch live. (Not `Octet - Index.dc.html`, which is
only the mockup gallery's contact-sheet page linking to every screen — it is not itself a UI to
build. This correction matters: building "Index" instead of "Map Hub" would produce the wrong
screen entirely.) Map Hub contains two views in one file: a **grid browser** (search bar,
Top-rated/Newest/Most-played tabs, a Filters button, a 5-column grid of map cards each with cover
art, title, mapper, star rating, download count) and a **map detail + leaderboard view** (large
cover/preview, title/artist/mapper/BPM, difficulty chips, rating/downloads/plays stats,
Download/Preview buttons, and a per-map top-5 leaderboard with avatar/name/accuracy/score rows).

**Root cause / current state:** `ui/main.gd` already has a `BROWSE_MAPS_SCENE` constant pointing at
`res://ui/map_hub.tscn`, which does not exist — this screen has never been built. There is no
backend at all today: `net/net_client.gd` (`Net` autoload) is a hard stub (`is_online()` always
`false`). `core/octet_bundle.gd` (`OctetBundle`) already implements reading `.octet` bundles (zip
containing `song.<ext>`, `chart_<difficulty>.oct` per difficulty, optional cover art, and
`manifest.json`) — this is the format to distribute over the hub, don't invent a new one.

**Scope & approach:**
1. **Hosting:** a GitHub repo (can be a new repo or a folder in this one, decide when implementing)
   holding an `index.json` manifest (list of maps: title, artist, mapper, star ratings per
   difficulty, cover art path, download count/rating if tracked) and one `.octet` bundle per map
   (as a repo file or a GitHub Release asset — Release assets avoid bloating repo history with
   binary audio and are the more conventional choice for versioned downloadable content).
2. **In-game fetch:** build the `map_hub.tscn`/`.gd` screen; use Godot's `HTTPRequest` node to fetch
   `index.json` from the GitHub raw/API URL, populate the grid browser. Selecting a card opens the
   detail view (still matching the mockup) with a Download button that fetches the corresponding
   `.octet` bundle and calls `OctetBundle`'s existing read path to unpack it into `user://songs/`
   (matching how `game/song_select.gd` already scans `user://songs`, so a downloaded map appears in
   Song Select automatically — reuse that scan, don't build a second one).
3. **Upload/publish flow:** document (in this repo, e.g. a `docs/MAP_HUB_PUBLISHING.md` or a
   section here) how a mapper gets their chart onto the hub — realistically a manual PR or a
   GitHub Release upload to start; a fully automated in-app publish flow is a stretch goal, not
   required for this WP's acceptance.
4. **Leaderboard column:** the mockup's per-map leaderboard is inherently a community/server-side
   feature — there's no backend to source live standings from yet. For this WP, either populate it
   from static seed data in the map's manifest (clearly a placeholder) or omit/stub the panel with a
   "leaderboard coming soon" state — do not silently fabricate live-looking scores. Flag this
   explicitly rather than treating it as done.

**Files:** new `ui/map_hub.tscn`, `ui/map_hub.gd`, `net/net_client.gd` (extend past the stub for
the GitHub fetch), reuse `core/octet_bundle.gd`, `game/song_select.gd` (scan path already covers
`user://songs`).

**Depends on:** WP-A (render fidelity), WP-B (ESC/back).

**Acceptance:** Browse Maps screen matches the Map Hub mockup (browser + detail); it lists maps
pulled from the GitHub-hosted index (not hardcoded placeholder cards); clicking Download actually
downloads and unpacks a `.octet` bundle such that the map then appears in Song Select; the
leaderboard panel's data-source limitation is explicitly called out, not silently faked.

---

## WP-N — Component sheet (optional)

**Mockup:** `Octet - Components.dc.html` — buttons (primary/secondary/ghost), inputs, dropdowns,
sliders, tabs, cards, health bar, note skins in every lane colour and state.

**Scope & approach:** optional shared-primitive pass extracting common controls into reusable
`ui/` components/theme entries so WP-G…L don't each reinvent button/card styling by hand. Can be
deferred; not required to unblock any other WP, but doing it earlier reduces rework across the
per-screen passes.

**Files:** new components under `ui/`, `assets/theme/octet_theme.tres`.

**Acceptance:** a running scene or test harness demonstrating each component/state matching the
mockup; other screens visibly reuse these instead of duplicating StyleBoxFlat definitions inline.
