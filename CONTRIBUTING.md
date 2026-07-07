# Contributing to Octet

Octet is a Godot 4.7 (GDScript) project — no package manager, no build step beyond
the engine itself. This guide gets you from a clone to a passing test run, then
covers the conventions the codebase expects.

## Prerequisites

- **Godot 4.7** (the exact minor version matters — `project.godot` pins
  `config/features` to `4.7`; other 4.x versions may open the project with warnings
  or subtly different behaviour).
- No Rust, Node, or Python toolchain required — the project has no GDExtension and
  no build tooling outside Godot itself.

## Setup

1. Clone the repo.
2. Open `project.godot` in the Godot 4.7 editor, or run it directly:

   ```bash
   godot4 project.godot
   ```

3. Run the game from the editor (F5) — it opens on `ui/main.tscn`.

## Running the tests

Octet's test suite is headless GDScript — no external test framework. Every suite
in `tests/test_*.gd` exposes `get_tests() -> Dictionary[String, Callable]`; the
runner (`tests/run_tests.gd`, a `TestRunner extends SceneTree`) registers all of
them, waits one frame for autoload `_ready()`, runs every case, and exits with code
`1` if anything failed (CI-friendly).

```bash
godot4 --headless -s tests/run_tests.gd --path .
```

Expected output ends with a summary line:

```
Ran 63 test(s): 63 passed, 0 failed.
```

A `[FAIL]` line above the summary names the failing test; GDScript has no
try/catch, so failures print via a shared `_assert` helper rather than raising.

**Also verify the project loads clean** (catches autoload/scene-path errors the
test suite itself won't hit):

```bash
godot4 --headless --quit --path .
```

### Writing a new test

Add a new `tests/test_<system>.gd` file following the existing pattern (see
`tests/test_conductor.gd` for a small example), then register it in
`tests/run_tests.gd`'s `_register_all_tests()`. **This registration function is
shared/global state** — see "Shared files" below.

### A gotcha worth knowing

Scripts with a `class_name` cannot statically reference autoloads when run under
`-s` (the `-s` script-runner entry point doesn't have the autoload singletons
resolved at parse time the way a normal scene run does). Tests work around this
with dynamic lookups: `get_autoload("Config")` instead of `Config.foo` directly.

## Project structure

```
core/    data model + persistent state (Chart schema, .oct/.octet IO, settings, scores)
audio/   timing truth + sound (Conductor, calibration, metronome, sfx)
game/    play loop (judging, grading, gameplay scene, song select, results)
editor/  beat-mapping editor (DSP pipeline, beat grid, note editor, undo)
ui/      menus + navigation (scene_router, main menu, settings, map hub)
net/     Map Hub client + Firebase stub
songs/   bundled playable songs (audio + cover + .oct charts)
maps/    community Map Hub content (index.json + .octet bundles)
tests/   headless GDScript test suites + runner
tools/   throwaway SceneTree scripts, not shipped with the game
```

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for how these fit together and why, and
[`docs/CODEMAPS/`](docs/CODEMAPS/) for a file-level reference per domain.

## Conventions

- **Tunables live in config, not code.** Gameplay/scoring constants go in
  `config/*.tres` (read via the `Config` autoload); per-machine settings
  (calibration offsets, accessibility, scroll speed) go through `SettingsStore`.
  Never hard-code a timing window or a colour value in a scene script.
- **Design tokens, not hex codes.** Every colour reads from `core/design_tokens.gd`
  (the `DesignTokens` autoload). If you're hard-coding a `Color(...)` in a `.gd` or
  `.tscn` file, that's very likely a bug.
- **`.oct`/`.octet` formats are locked.** Don't redesign the chart schema without
  updating `core/oct_io.gd`, `core/octet_bundle.gd`, every `.oct` file under
  `songs/`, and `docs/PROJECT_BRIEF.md` §4 in the same change.
- **The Conductor clock is the only source of timing truth.** Any gameplay code
  that judges timing without going through `Conductor.song_time_ms()` is a bug —
  see [`ARCHITECTURE.md`](ARCHITECTURE.md#timing-one-clock-read-everywhere) for why.
- **No formatter or linter is configured** (`gdformat`/`gdlint` are not wired in) —
  match the style of the surrounding file.

## Shared files — coordinate before editing

A few files are touched by almost every feature and are easy to silently conflict
on if two changes land at once:

- `project.godot` — autoload registration, engine version, project settings
- `core/` source — the shared data model every domain depends on
- `config/*.tres` — shared tunables
- `tests/run_tests.gd`'s `_register_all_tests()` — test suite registration

If you're working alongside someone else (or an AI agent session broken into
subagents), keep these edits sequential, not concurrent.

## Version control

Version control on this project is manual — commits are made deliberately, not
auto-generated or auto-pushed. If you're scripting or automating any part of your
workflow, don't wire up auto-commit hooks against this repo.

## Submitting changes

1. Make your change.
2. Run both verification commands above (project loads clean + full test suite passes).
3. Open a pull request describing what changed and why, referencing the relevant
   section of [`docs/PROJECT_BRIEF.md`](docs/PROJECT_BRIEF.md) if it touches spec'd behaviour.

## License

MIT — see [`LICENSE`](LICENSE).
