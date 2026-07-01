# Octet — build plan

Living roadmap for the staged build. **Read this file first in every new chat** — it tells you exactly where the build stands. One stage per chat: read this file + the briefs, decompose into subagents, integrate, verify, update this file, report done, stop.

Full stage rationale lives in the original Claude Code plan; this file is the working checklist + handoff notes that survive context resets.

---

## Status

**Current stage: 3 (M1b — HUD, results, calibration, song select) — IN PROGRESS. Non-HUD parts (results, calibration, song select, gameplay flow) COMPLETE and verified. HUD-from-2A import BLOCKED — see below.**
**Stage 2 (M1a — Core gameplay systems) — COMPLETE, verified headless under Godot 4.7.**
**Stage 1 (M0 — Conductor clock & one-lane vertical slice) — COMPLETE, verified headless under Godot 4.7.**
**Stage 0 (Foundation & design system) — COMPLETE, verified headless under Godot 4.7.**

Godot install: `C:\Users\1chin\OneDrive\Desktop\Godot_v4.7-stable_win64.exe` (not on PATH — pass the full path to bash, or add it to PATH). Verified via:
```
"<path-to-godot>" --headless --quit --path .          # project loads clean
"<path-to-godot>" --headless -s tests/run_tests.gd --path .   # test suite
```

---

## Operating rules (every stage)

- **No version control actions** — never `git init/add/commit/push`, no auto-commit hooks. Matthew commits himself.
- **Design system is `docs/DESIGN_BRIEF.md`** — Octet palette/type only, never MashuAI. Everything reads `core/design_tokens.gd` (the `DesignTokens` autoload) — never hard-code hex in scenes/scripts.
- **Tunables live in `config/*.tres`** via the `Config` autoload (static tuning: gameplay/scoring) or `SettingsStore` autoload (per-machine: calibration offsets, accessibility, scroll speed) — not scattered through code.
- **Conductor clock is central** (Stage 1 builds it) — all timing/judgment derives from audio playback position + latency/calibration offsets, never frame delta.
- **`.oct`/`.octet` formats exactly** per PROJECT_BRIEF §4 — locked, don't redesign.
- **Answer-first, terse, autonomous, Canadian spelling, sentence case.**

## Cross-chat protocol

1. Read this file, `CLAUDE.md`, `docs/PROJECT_BRIEF.md`, `docs/DESIGN_BRIEF.md`, and (HUD/editor stages) `docs/DESIGN_HANDOFF.md`.
2. Confirm the stage's entry preconditions below.
3. Decompose into the listed subagents, run independent slices in parallel, integrate on the main thread yourself (don't let parallel agents fight over shared files like `project.godot`).
4. Run headless verification (`godot --headless --quit` + the test runner) and any manual-in-Godot checks.
5. Update this file: tick the checklist, add/refresh handoff notes, flip the status line.
6. Report done to the user with the handoff summary. Stop.

---

## Stage 0 — Foundation & design system — ✅ COMPLETE

### What's built
- `project.godot` + folder layout: `game/ editor/ audio/ net/ ui/ core/ native/ assets/ config/ tests/`.
- **Design tokens**: `core/design_tokens.gd` (`DesignTokens` autoload) — full palette, mirrored lane colours (0–7: orchid/pink/coral/amber/amber/coral/pink/orchid), corner radii, font family names, `lane_color(i)` helper. `assets/theme/octet_theme.tres` (Theme resource: Button + Panel styles, hairline borders, pink focus glow). `assets/fonts/font_{ui,display,mono}.tres` — `SystemFont` fallbacks (Inter/Space Grotesk/JetBrains Mono by name, generic fallback); **no real font binaries yet** — see `assets/fonts/README.md` for the swap-in procedure when `.ttf` files are sourced (SIL OFL licensed).
- **Chart data model**: `core/chart.gd` (`Chart`) + `core/{timing_point,chart_note,chart_metadata,chart_audio}.gd` — one `class_name` per file (GDScript requires this; the original task brief assumed one file, which isn't possible). `core/oct_io.gd` (`OctIO.load_oct/save_oct`) — round-trip verified against the exact PROJECT_BRIEF §4.1 example. `core/octet_bundle.gd` (`OctetBundle`) — `read_manifest()` fully works; `write_bundle()` is a documented stub (manifest only) pending Stage 5.
- **Config**: `core/{gameplay,scoring,settings}_config.gd` + `config/{gameplay,scoring,settings}.tres` with PROJECT_BRIEF §2.4–2.6/§2.9 default values. `core/config.gd` (`Config` autoload, loads gameplay/scoring at `_ready()`). `core/settings_store.gd` (`SettingsStore` autoload, persists `SettingsConfig` to `user://settings.tres`). `core/keybind_defaults.gd` (`KeybindDefaults.DEFAULT_LANE_KEYS`, A S D F J K L ;).
- **Shell**: `ui/scene_router.gd` (`SceneRouter` autoload — `goto_scene`, `goto_scene_pushed`/`go_back`, real implementation not a stub). `audio/conductor.gd` (`Conductor` — placeholder, `get_song_time_ms()` stub returning 0.0, Stage 1 replaces). `net/net_client.gd` (`Net` — placeholder, `is_online()` stub, Stage 7 replaces). `ui/main.tscn` + `ui/main.gd` — themed placeholder main menu (wordmark, ambient pulse, Play/Editor/Browse maps/Profile buttons routing to not-yet-built scenes with graceful missing-scene errors).
- `assets/icons/icon.svg` — minimal placeholder (referenced by `project.godot`, was missing until integration pass).
- **Headless test runner**: `tests/run_tests.gd` (`TestRunner`, `extends SceneTree`) + `tests/test_oct_io.gd` (3 tests) + `tests/test_config_load.gd` (2 tests). All 5 pass.

### Gotchas found during integration (read before writing more GDScript/tests)

1. **`Callable` bound to a `RefCounted` does NOT keep it alive.** It resolves the target by `ObjectID` at call time, not a strong reference. If you build a `Callable` from a local `RefCounted` instance and let that local variable go out of scope, the callable later fails with `Attempt to call function '...' on a null instance`. Fix: keep a persistent strong reference (e.g. an array on the owning object) for as long as the callable might be invoked. See `TestRunner._suites` in `tests/run_tests.gd`.
2. **`class_name`-declared scripts are eagerly compiled into the global class cache before `[autoload]` singletons are registered**, under `godot --headless -s`. A *static* identifier reference to an autoload (e.g. `Config.gameplay`) inside a `class_name` script fails to compile: `Identifier not found: Config`. Fix: dynamic lookup via `TestRunner.get_autoload("Config")` (walks `Engine.get_main_loop().root`) instead of a bare static reference, in any `class_name`-declared script that needs an autoload. Regular (non-`class_name`) scripts loaded through the normal scene/autoload boot path (confirmed via `--headless --quit`) do not hit this — it's specific to the `-s` test-runner entry point's compile ordering.
3. **Autoload `_ready()` has not run yet at `_initialize()` time** under `godot --headless -s` (the node exists under the tree root, but its `_ready()` — where `Config` loads its `.tres` resources — hasn't fired). Fix: `await process_frame` once at the top of `_initialize()` before touching any autoload state. Already applied in `tests/run_tests.gd`.

None of the three fixes above touch gameplay code — they're specific to the `-s` headless test-runner path. `godot --headless --quit` (normal boot through `run/main_scene`) had zero errors from the start.

### Verification run (Godot 4.7.stable)
```
Ran 5 test(s): 5 passed, 0 failed.
```
`godot --headless --quit --path .` — clean, no autoload/resource errors.

### What Stage 1 assumes
- `Conductor` autoload exists at `res://audio/conductor.gd` with a stub `get_song_time_ms()` — replace its contents with the real conductor clock (§6.2), keep the autoload registration in `project.godot` as-is.
- `Config.gameplay` / `KeybindDefaults.DEFAULT_LANE_KEYS` are available for timing windows and default key bindings.
- `SettingsStore.settings` is available for calibration offset storage (audio_offset_ms/input_offset_ms fields already exist on `SettingsConfig`).
- If Stage 1 adds more headless tests referencing autoloads, apply gotchas #2 and #3 above from the start.

---

## Stage 1 — M0: Conductor clock & one-lane vertical slice — ✅ COMPLETE

### What's built
- **Conductor clock** (`audio/conductor.gd`, real implementation replacing the Stage 0 stub): owns an `AudioStreamPlayer` child. `song_time_ms()` = pure static `compute_song_time_ms(raw_stream_sec, output_latency_sec, audio_offset_ms)` (`(raw - latency) * 1000 + offset`), fed live from `player.get_playback_position() + AudioServer.get_time_since_last_mix()` and `AudioServer.get_output_latency()`, clamped monotonic non-decreasing while playing (guards against mix-timing jitter stepping the clock backward). `judgment_error_ms(tap_ms, target_ms, input_offset_ms)` = `(tap_ms + input_offset_ms) - target_ms`. **Sign convention** (documented in the file): both calibration offsets are pure additive, "positive = shift the corresponding clock later" — simplest self-consistent convention, matches e.g. osu!'s universal-offset model. Reads `SettingsStore.settings.audio_offset_ms`/`input_offset_ms` defensively (safe if `SettingsStore` isn't ready). `play/stop/pause/resume/seek_ms/is_playing` round out the instance API.
- **Lane input** (`core/lane_input.gd`, new `LaneInput` autoload, registered in `project.godot` *after* `SettingsStore`): registers InputMap actions `lane_0`..`lane_7` from `SettingsStore.settings.lane_keys` (new field on `SettingsConfig`, empty = fall back to `KeybindDefaults.DEFAULT_LANE_KEYS`, so existing saved settings stay valid with no migration). `binding_for(lane)`, `current_key_string(lane)`, `rebind(lane, keycode)` (persists via `SettingsStore.save()`). Uses `OS.find_keycode_from_string` / `OS.get_keycode_string` to convert between the `KeybindDefaults` key-string convention and Godot's `Key` enum.
- **Rebind panel foundation** (`ui/rebind_panel.tscn` + `.gd`): builds 8 rows (lane-colour swatch via `DesignTokens.lane_color`, label, current-key button) procedurally in `_ready()`; click a key button then press a key to rebind via `LaneInput.rebind`. Foundation only, not the final settings screen (that's Stage 3, §2.8).
- **Vertical slice** (`game/vertical_slice.tscn` + `.gd`): one lane (index 0), one note, a judgment line, driven entirely by `Conductor.song_time_ms()` — `note_y = judgment_y - (target_ms - song_time_ms) * PIXELS_PER_MS * scroll_speed`. `scroll_speed` (from `SettingsStore.settings.scroll_speed`) scales approach distance only; judgment math never reads it. Hit detection on the `lane_N` action bucket `abs(judgment_error_ms(...))` against `Config.gameplay.window_perfect_ms/great_ms/good_ms` → Perfect/Great/Good/Miss, shown with signed ms error (early/late). Auto-Miss if a note goes unhit past `window_good_ms + MISS_GRACE_MS`.
- **Fixture** (`game/fixture_click_track.gd`, `FixtureClickTrack`): procedurally builds a mono 16-bit `AudioStreamWAV` click track in memory (4 bars @ 120 BPM default) — no committed audio binary, fully reproducible. `beat_target_ms(beat_index, bpm)` gives the alignment anchor the slice uses for its note's target time.
- **Tests**: `tests/test_conductor.gd` (`TestConductor`) — 5 cases covering `compute_song_time_ms` and `judgment_error_ms` (basic, zero-offset, late, early, on-time-with-offset), calling the statics via `load("res://audio/conductor.gd")`. `tests/test_lane_input.gd` (`TestLaneInput`) — 2 cases confirming all 8 actions register and `rebind` actually swaps the bound key (restores the original binding afterward so it doesn't leave global state mutated). Both registered in `tests/run_tests.gd._register_all_tests()`.

### Gotcha found during integration (read before adding more `class_name` scripts)

**A brand-new `class_name`-declared script is invisible to both `godot --headless --quit` and `godot --headless -s` until the editor's global script-class cache (`.godot/global_script_class_cache.cfg`) has been regenerated at least once.** Adding `tests/test_conductor.gd` (`TestConductor`), `tests/test_lane_input.gd` (`TestLaneInput`), and `game/fixture_click_track.gd` (`FixtureClickTrack`) and referencing them from `tests/run_tests.gd` initially failed with `Identifier "TestConductor" not declared in the current scope` under `-s`, even though `--headless --quit` had already run clean. Fix: run `godot --headless --editor --quit --path .` once after adding/renaming any `class_name` script — this forces the "Registering global classes..." editor pass and rewrites the cache file — then the normal headless entry points pick the new class up. Not needed for non-`class_name` scripts (autoloads like `LaneInput`, plain scene scripts like `vertical_slice.gd`) since those are resolved by path, not by the global class cache.

### Design decision worth carrying to the vault (per CLAUDE.md §1/§3)
Calibration offset sign convention was deliberately simplified to "both offsets are pure additive, positive = shift later" rather than trying to encode an asymmetric "forgive hardware lateness" story per-offset — the asymmetric framing didn't actually hold up under the additive formula and would have been a silent correctness bug. Keep this convention when Stage 3 builds the real calibration screen; the tap-to-the-beat routine should compute `stored_offset = -average_measured_error` (or however it's derived) with this additive convention in mind, not the other way around.

### Verification run (Godot 4.7.stable)
```
Ran 12 test(s): 12 passed, 0 failed.
```
`godot --headless --quit --path .` — clean. In-editor smoke test (`--headless --path . res://game/vertical_slice.tscn --quit-after 60` and same for `res://ui/rebind_panel.tscn`) — both run without script errors; full manual in-editor play (F6) still recommended before Stage 2 sign-off if not already done live.

### What Stage 2 assumes
- `Config.gameplay` timing windows and `Conductor.judgment_error_ms`/`song_time_ms` are the judgment primitives — Stage 2's 8-lane note/scoring systems should call these directly rather than re-deriving timing math.
- `LaneInput.binding_for(lane)` / `current_key_string(lane)` are the lane-input surface; extend, don't duplicate, when wiring all 8 lanes.
- `game/vertical_slice.gd` is a disposable M0 proving ground, not a component to extend in place — Stage 2 builds the real multi-lane note/scoring scene fresh, reusing the same Conductor/LaneInput/Config calls it validated.

## Stage 2 — M1a: Core gameplay systems — ✅ COMPLETE

### What's built
- **Judgment/scoring engine** (`game/judge_engine.gd`, `JudgeEngine`): pure, time-driven core, deliberately decoupled from rendering/real input/the live Conductor — driven by explicit `update(song_time_ms)` + `on_lane_press/release(lane, song_time_ms)`, mirroring Stage 1's "pure math behind a Node" split (`Conductor.compute_song_time_ms`). Handles tap, chord (multiple `ChartNote`s sharing `time_ms`, no separate type — matches the `.oct` model as-is), and hold (head judged like a tap; ticks every `hold_tick_interval_ms` while held, credited to accuracy/score only; tail judged like a tap against `end_time_ms` at release time — an early release naturally buckets to Miss via the same window logic, no special-cased branch needed). Exposes `score`, `combo`/`max_combo`, `accuracy()`, `health`, `judgment_counts`, `hit_errors` (ms, signed — ready for Stage 3's histogram), `grade()`, `is_full_combo()`/`is_all_perfect()`, `is_failed()`/`is_ranked()`, `current_multiplier()`, and signals `judged`/`combo_changed`/`health_changed`/`song_failed` for HUD wiring.
- **`game/judgment.gd`** (`Judgment.Kind` enum + `bucket/weight/health_delta/display_name`) and **`game/grading.gd`** (`Grading.grade_for` + full-combo/all-Perfect badge checks) — single source of truth for the window→judgment and judgment→weight/health/grade mappings, all reading `Config.gameplay` thresholds.
- **`game/gameplay_mods.gd`** (`GameplayMods`): `no_fail`/`practice` value object; No-Fail disables the fail flag and flags the run unranked (`is_ranked() == false`). Practice-mode playback behaviour (arbitrary start point, reduced rate) is plumbing-only, deferred.
- **Two new tunables** on `GameplayConfig`/`config/gameplay.tres`: `combo_multiplier_step: int = 10` (multiplier = `1 + floor(combo / step)`, capped at the existing `combo_multiplier_cap`) and `hold_tick_interval_ms: float = 100.0`.
- **`game/play_field.tscn`/`.gd`** — minimal 8-lane playable scene (logic-first, minimal visuals per the stage brief): loads the fixture chart via `OctIO.load_oct`, builds a `JudgeEngine` against `Config.gameplay`/`Config.scoring`, plays `FixtureClickTrack.build()` through `Conductor`, feeds `LaneInput`-bound presses/releases into the engine, positions falling note rects the same way `vertical_slice.gd` did (now for all 8 lanes, holds drawn as a stretched rect from head to tail), and shows score/combo/accuracy/health/grade as plain `Label`s. Note visuals hide on a pure time threshold (past the note's — or hold tail's — Good window) rather than correlating back to the `judged` signal, since by definition that note has necessarily been resolved (hit or auto-Missed) by then.
- **Fixture** `tests/fixtures/m1a_fixture.oct` (new, committed): a chord (lanes 0 & 4 @ 1000ms), a tap (lane 2 @ 1500ms), and a hold (lane 3, 2000-2250ms) — small enough to auto-play exactly in tests, aligned to `FixtureClickTrack`'s 120 BPM clicks for manual play_field verification.
- **Tests** `tests/test_gameplay.gd` (`TestGameplay`, 9 cases, registered in `run_tests.gd`): all-Perfect run, one missed note, chord hit/missed, hold held-fully vs. early-release (exact score/combo/accuracy/health arithmetic asserted), No-Fail draining health to 0 without failing/ranking, grade-threshold boundaries, and one full round-trip loading the committed fixture through the real `OctIO` path. Unlike `TestConductor`/`TestLaneInput`, this suite needs no `TestRunner.get_autoload()` at all — `JudgeEngine`/`GameplayConfig`/`ScoringConfig`/`GameplayMods`/`Chart`/`ChartNote` are plain classes with zero autoload dependency, so fresh instances reproduce the `.tres` defaults directly.

### Gotchas found during integration
1. **GDScript's static type checker treats the global `floor()` built-in's return as `Variant`, not `float`**, because it's overloaded across int/float/vector — `var steps := floor(x)` fails to compile under this project's "warnings as errors" setting with "The variable type is being inferred from a Variant value." Fix: use the type-specific global `floorf(x: float) -> float` instead of `floor()` when the result is immediately assigned with `:=`. Same likely applies to `ceil`/`round` — prefer `ceilf`/`roundf` inside `:=` assignments.
2. Same class-cache gotcha as Stage 1 (`godot --headless --editor --quit` after adding new `class_name` scripts) applied again for `Judgment`, `Grading`, `GameplayMods`, `JudgeEngine`, `TestGameplay`.

### Design decisions worth carrying to the vault (per CLAUDE.md §1/§3)
- **Hold ticks intentionally do not touch combo or health** — only accuracy and score. This keeps "combo" meaning "notes hit in a row" (head/tail/tap events only) rather than a per-100ms counter during holds, and keeps health tied to discrete note outcomes. Flagged as a simplification to revisit at playtest if holds feel under- or over-weighted.
- **Early hold release needed no special-case branch**: judging the tail via the same `abs(error) → window bucket` logic used for taps naturally produces a Miss when released far before `end_time_ms`, since the error simply exceeds the Good window. One code path serves both "released on time" and "released too early."
- **Note-visual hide timing in `play_field.gd` is purely time-based**, not signal-correlated — simpler and just as correct, since a note's Good window elapsing means it has necessarily been resolved one way or another.

### Verification run (Godot 4.7.stable)
```
Ran 21 test(s): 21 passed, 0 failed.
```
`godot --headless --quit --path .` — clean. `godot --headless --path . res://game/play_field.tscn --quit-after 90` — runs ~1.5s of real gameplay (past the fixture's chord/tap windows) with no script errors. Manual in-editor F6 playtest (actually pressing the lane keys) still recommended before Stage 3 sign-off.

### What Stage 3 assumes
- `JudgeEngine`'s public state getters + signals (`judged`, `combo_changed`, `health_changed`, `song_failed`) are the HUD/results data surface — build the real HUD (2A) and results screen (§2.7, incl. `hit_errors` for the histogram) against these directly rather than re-deriving judgment state.
- `game/play_field.gd` is a disposable M1a proving ground (like Stage 1's `vertical_slice.gd`) — Stage 3 builds the real gameplay scene fresh around the same `JudgeEngine`/`Conductor`/`LaneInput` calls it validated, styled from the imported 2A mockup.
- Calibration screen (§2.8) writes to `SettingsStore.settings.audio_offset_ms/input_offset_ms`, which `Conductor` already reads — no engine-side changes needed, just the UI.

## Stage 3 — M1b: HUD, results, calibration, song select — first playable — 🟡 IN PROGRESS

### BLOCKED: Gameplay HUD from imported 2A mockup
- [ ] Gameplay HUD from 2A (Godot Control nodes, not HTML). **Precondition unmet: the Claude Design MCP (`https://api.anthropic.com/v1/design/mcp`, `/design-login`) is not connected in this Claude Code installation** — `/design-login` isn't an available command/skill, and the only design-related tool present (`DesignSync`) is a different mechanism (design-system component-library sync for `/design-sync`, confirmed via `list_projects` returning zero projects) — not the arbitrary `.dc.html` mockup import `DESIGN_HANDOFF.md` describes. **Before attempting this piece, confirm with Matthew whether that MCP/plugin is actually installed for this Claude Code setup** (it may need enabling outside this session, or the docs may describe a different Claude Code version/plugin). Until then, `game/gameplay.gd`'s plain-Label HUD (below) stands in.

### What's built (everything else in Stage 3, verified)
- **`core/play_session.gd`** (new `PlaySession` autoload, registered after `LaneInput`/before `Conductor` in `project.godot`): the scene-to-scene handoff `change_scene_to_file` doesn't provide — `chart_list`/`chart_index` (song select's ordered picks, for Results' "Next"), `mods` (chosen at song select), and `last_engine` (the finished `JudgeEngine`, read by results). A RefCounted autoload field survives scene changes fine since autoloads persist.
- **`game/song_select.gd`/`.tscn`**: scans `res://tests/fixtures/*.oct` (bundled demo content) and `user://songs/*.oct` (the real per-machine convention, auto-created if missing — a stand-in for real chart installation until Stage 4/5's audio import and `.octet` bundle unpacking exist) via `OctIO.load_oct`, lists title/artist/mapper/difficulty/star rating, a No-Fail checkbox, and Play/Calibrate/Back. Matches `ui/main.gd`'s pre-existing `PLAY_SCENE` constant (`res://game/song_select.tscn`) exactly — no change needed there.
- **`game/gameplay.gd`/`.tscn`** — supersedes Stage 2's `game/play_field.gd`/`.tscn` (which was explicitly documented there as disposable). Loads whichever chart `PlaySession` queued (falls back to the Stage 2 fixture when run standalone with nothing queued, so F6 still works during dev), builds the backing click track long enough to cover the chart's last note (`Metronome.build`, sized off the chart's own first timing point's BPM), and on completion (song time past the last note's Good window) hands the finished engine to `PlaySession.last_engine` and routes to results. Same Conductor/LaneInput/JudgeEngine wiring as `play_field.gd` — only the surrounding flow and chart-loading changed. Added a Quit button (`SceneRouter.go_back()`) as a safety valve, not specified by the brief but reasonable UX.
- **`game/results.gd`/`.tscn`** (§2.7): grade (big, amber), final accuracy, max combo, score, per-judgment breakdown, badges (Full combo / All Perfect / Unranked / FAILED), a hit-error histogram built from `JudgeEngine.hit_errors` (9 bars bucketed across the observed range — at least the Good window, wider if any early-hold-release outlier exceeded it — bottom-aligned via `SIZE_SHRINK_END` so they read as a growing-up bar chart), mean offset, and Retry/Next/Back. "Next" advances `PlaySession.chart_index` via `advance_to_next_chart()`. Online score submission (§2.7's "if online and ranked, submit score and show placement") is explicitly deferred — `Net.is_online()` is still Stage 7's unimplemented stub, so there's nothing to submit yet.
- **`audio/calibration.gd`/`.tscn`** (§2.8) — placed under `/audio` per PROJECT_BRIEF's own folder map ("`/audio` — conductor, calibration, analysis bindings"), not `/ui`. Tap-to-the-beat routine: plays a metronome (`Metronome.build`), flashes a pulse indicator on each beat, records the signed error of each tap (Godot's built-in `ui_accept` action — Space/Enter — reused rather than adding a dedicated InputMap action) after a warmup period, averages the error, and stores `-average_error` into `SettingsStore.settings.input_offset_ms` (sign flipped per the additive "positive = shift later" convention `Conductor` already uses — see decision note below). `audio_offset_ms` is deliberately left untouched.
- **Promoted `game/fixture_click_track.gd` → `audio/metronome.gd`** (`FixtureClickTrack` → `Metronome`): its click-track generator stopped being test-only the moment the calibration screen needed a real metronome to tap along to, so it moved out of `/game` test-fixture territory into `/audio` alongside `Conductor` as a first-class production utility. Updated its one other caller, `game/vertical_slice.gd`. No behavioural change, added `beat_interval_ms()`.

### Gotchas found during integration
1. **GDScript's static type checker can't infer the element type of a `for` loop over an untyped array literal** (`for x in [a, b]:` leaves `x` typed `Variant` even when `a`/`b` are both `String` constants), which then poisons any `:=` assignment built from it ("Cannot infer the type... because the value doesn't have a set type"). Fix: assign the literal to an explicitly typed `Array[String]` variable first, then loop over that. Hit in `game/song_select.gd`'s directory-scan loop.
2. **Headless `--headless -s`/`--quit` runs use the dummy audio driver, and playback position does not advance meaningfully under it** (per the Stage 0 handoff note) — so a live gameplay scene never naturally reaches its "song finished" transition in a headless smoke test. To verify `game/results.gd`'s populated code path (histogram/badges/breakdown) without a real audio device, a throwaway `SceneTree` script built a `JudgeEngine` directly, set `PlaySession.last_engine`, instantiated `results.tscn` manually, and checked for runtime errors — then was deleted. Worth remembering as the pattern for verifying any scene that depends on a finished play session, until real audio output is available to test against.
3. Same global-script-class-cache gotcha as Stages 1-2 applied again for `Metronome` after the rename.

### Design decisions worth carrying to the vault (per CLAUDE.md §1/§3)
- **Calibration cannot separate audio-latency bias from input-latency bias from a single tap-to-beat test** — they're confounded into one measured number. This screen attributes the whole measured average to `input_offset_ms` only, leaving `audio_offset_ms` at 0/user-set. If a future stage wants to disambiguate the two, it'll need a second, different routine (e.g. a known-latency audio loopback test) — this one routine can't do it alone.
- **`game/gameplay.gd`'s chart-end detection and backing-track sizing derive entirely from the chart's own data** (last note's time, first timing point's BPM) rather than a fixed duration, so it works for any `.oct`, not just the Stage 2 fixture — this is the seam Stage 4's real audio import should slot into (swap the `Metronome.build()` call for loading `chart.audio.filename` when it exists next to the chart).

### Verification run (Godot 4.7.stable)
```
Ran 21 test(s): 21 passed, 0 failed.
```
(No new automated tests added this stage — Stage 3's non-HUD pieces are UI flow, not new judgment logic, so they were verified via headless scene smoke tests instead: `godot --headless --quit` clean boot; `godot --headless --path . res://game/song_select.tscn --quit-after 30`, `res://game/gameplay.tscn --quit-after 90`, `res://audio/calibration.tscn --quit-after 30` all run error-free; `results.tscn`'s populated path verified via the throwaway script described above.) Manual in-editor playthrough (song select → gameplay → results, and the calibration routine with real taps) still recommended — headless dummy audio couldn't exercise real timing end-to-end.

### What's still needed before Stage 3 can be marked fully complete
- Confirm Design MCP availability and import HUD variant 2A into `game/gameplay.gd`'s visuals (replacing the plain Labels — the Conductor/LaneInput/JudgeEngine wiring underneath stays as-is).
- A manual in-editor playthrough with real audio timing (song select → play → results; calibration with real taps) to confirm feel, not just absence of script errors.

## Stage 4 — M2a: Editor shell, audio import, waveform, timing — ⬜ not started
- Precondition: Design MCP connected, import `Octet - Editor.dc.html` (1A).
- [ ] Editor shell from 1A. Audio import (MP3/OGG/WAV → PCM). Waveform + playhead. Manual BPM/offset + beat-grid overlay. Timing points. Transport (scrub, 0.25×–1×).
- Subagents: (1) Editor shell, (2) Audio import + waveform, (3) Timing model.
- Done when: import a song, see waveform, set BPM/offset, beat grid snaps, scrub at variable rate.

## Stage 5 — M2b: Note editing, QOL, save/export, playtest — ⬜ not started
- [ ] Note timeline, snap 1/1–1/16, chords/holds/free-place.
- [ ] QOL: zoom, metronome, nudge, select/copy/paste/duplicate/mirror, difficulty tabs, undo/redo, autosave.
- [ ] Save `.oct` + package `.octet` (completes `OctetBundle.write_bundle` stub from Stage 0).
- [ ] Playtest-in-editor (bridges to Stage 2/3 gameplay).
- Subagents: (1) Placement & snapping, (2) QOL & undo/redo, (3) Save/export + playtest bridge.
- Done when: author a map, save/package, reopen, playtest-in-editor, clean undo/redo.

## Stage 6 — M3: Automatic analysis — ⬜ not started
- [ ] Onset detection (FFT → spectral flux), tempo estimation (autocorrelation, 60–220 BPM, octave-error resolution), beat-phase, seed-draft notes.
- [ ] Fixed interface `analyze(pcm) -> { bpm, offset_ms, onsets[] }`. Decide Rust GDExtension vs GDScript DSP fallback based on measured perf.
- Subagents: (1) DSP core, (2) Editor integration.
- Done when: fixture song detection lands close; results editable; headless BPM-tolerance test passes.

## Stage 7 — M4: Online core — ⬜ not started
- [ ] `/net` REST client (Firebase Auth/Firestore/Storage/Functions via `HTTPRequest`).
- [ ] Auth (email/password + Google). Publish/upload. Map hub browse/search/download. Per-map leaderboards. Score submission + server-side validation Cloud Function.
- Subagents: (1) `/net` + Auth, (2) Publish + hub, (3) Leaderboards + Cloud Functions.
- Done when: sign in → upload → hub → download → play → submit score → see on leaderboard, against a dev Firebase project.

## Stage 8 — M5: Community, polish, packaging — ⬜ not started
- [ ] Global ranks/performance-points (scheduled Cloud Function). Profiles. Ratings. Anti-cheat groundwork (replay capture scaffolding).
- [ ] Star-rating formula finalized (§2.9). Accessibility pass (colourblind, reduced motion/flash, contrast).
- [ ] Packaging: Windows `.exe`/installer + macOS `.dmg` notarised, GitHub Releases.
- Subagents: (1) Ranks/profiles/ratings, (2) Star-rating + accessibility, (3) Packaging + release prep.
- Done when: global ranks recompute; profiles/ratings live; accessibility toggles work; signed builds export.

---

## Design import notes (Stages 3, 4, 5)
HUD (2A) and Editor (1A) come from the Claude Design MCP (`https://api.anthropic.com/v1/design/mcp`, `/design-login`), project `cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`. **Translate `.dc.html` into Godot Control nodes — never embed HTML.** Consume Stage 0's `DesignTokens`/`octet_theme.tres` so imported and hand-built screens stay consistent. All other screens follow `DESIGN_BRIEF.md` directly.

## Risks / dependencies
- Design MCP connectivity blocks Stages 3–5 fidelity — connect before those chats.
- Rust toolchain availability decides Stage 6 backend — probe at Stage 6.
- Firebase project + web config needed before Stage 7.
- macOS signing/notarisation needs Apple credentials at Stage 8 (kept out of repo).
