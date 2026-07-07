<!-- Generated: 2026-07-07 | Files scanned: project.godot + net/net_client.gd | Token estimate: ~350 -->

# Dependencies codemap

## Engine

- **Godot 4.7**, GL Compatibility renderer (`project.godot`: `config/features=PackedStringArray("4.7", "GL Compatibility")`).
- Pure GDScript — no GDExtension in use. `native/` exists but is empty; a Rust
  GDExtension for FFT/DSP was evaluated and declined (no Rust toolchain available) —
  see [editor.md](editor.md). The FFT is hand-rolled in `editor/dsp_fft.gd` instead.

## External services

| Service | Status | File |
|---|---|---|
| Map Hub (community maps) | **Live** — plain files served from `raw.githubusercontent.com` | net/net_client.gd (184 lines), docs/MAP_HUB_PUBLISHING.md |
| Firebase (Auth/Firestore/Storage) | **Hard stub** — `Net.is_online()` always returns false; no real client wired | net/net_client.gd |

Map Hub manifest: `maps/index.json`, one `.octet` bundle per map. No leaderboard
backend exists yet — Map Hub UI must present that honestly, not simulate it.

## Third-party packages

None. No `addons/` directory, no asset-library plugins in `project.godot`. All
gameplay, DSP, and networking code is hand-written GDScript against Godot's own
`HTTPRequest` / `AudioStreamPlayer` / `AudioServer` APIs.

## Build/dev tooling

- Test runner: headless Godot (`godot --headless -s tests/run_tests.gd`), no external
  test framework — hand-rolled `[PASS]/[FAIL]` assertions (GDScript has no try/catch).
- `tools/` — throwaway `SceneTree` scripts (`generate_charts.gd`, `build_bundles.gd`,
  `build_seed_bundle.gd`), not shipped with the game.
- No package manager (npm/pip/cargo) involved — this is a Godot-only project.

See also: [architecture.md](architecture.md).
