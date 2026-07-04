# Map Hub publishing (v1)

The Map Hub (WP-M, `ui/map_hub.tscn`/`.gd`) browses and downloads community maps hosted as plain
files in this repo under `maps/`. This doc covers the manifest schema and how a mapper gets a new
map onto the hub today. It does **not** cover the leaderboard — there is no backend to source real
standings from, and `maps/index.json` deliberately has no leaderboard field. The UI must stub that
honestly (a "coming soon" state or clearly-labeled placeholder), not fabricate scores.

## Hosting

`maps/index.json` (the manifest) and one `.octet` bundle per map live as ordinary files in this
repo, served over `raw.githubusercontent.com` once committed and pushed by the repo owner. This
avoids the extra step of publishing a GitHub Release, which needs explicit human authorization.
See "Future: GitHub Releases" below for when to reconsider this.

## `maps/index.json` schema

```json
{
  "maps": [
    {
      "id": "thats-why-i-gave-up-on-music",
      "title": "That's Why I Gave Up On Music",
      "artist": "Unknown Artist",
      "mapper": "Auto (WP-C onset pipeline)",
      "bpm": 126,
      "bundle_url": "https://raw.githubusercontent.com/MattModeCode/octet/master/maps/thats-why-i-gave-up-on-music.octet",
      "cover_url": "",
      "difficulties": [
        {"name": "Easy", "star_rating": 1.8},
        {"name": "Normal", "star_rating": 3.2},
        {"name": "Hard", "star_rating": 4.7}
      ],
      "download_count": 0,
      "rating": 0.0,
      "updated_at": "2026-07-03"
    }
  ]
}
```

Top-level: a single `"maps"` array. Each entry:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Stable, URL/filename-safe slug. Doubles as the bundle's filename stem (`maps/<id>.octet`) and the unpacked folder name under `user://songs/<id>/`. Must be unique across the manifest. |
| `title` | string | Song title, from the chart metadata. |
| `artist` | string | Song artist, from the chart metadata. |
| `mapper` | string | Chart author/credit, from the chart metadata. |
| `bpm` | number | Display BPM (rounded), from the chart's timing points. |
| `bundle_url` | string | Absolute URL to the `.octet` bundle. Currently always a `raw.githubusercontent.com` repo-file URL; see the migration note below. |
| `cover_url` | string | Absolute URL to cover art, or `""` if none. Not yet produced by the editor's export flow (no cover-art picker built) — expect this to be empty for the foreseeable future. |
| `difficulties` | array of `{name, star_rating}` | One entry per difficulty in the bundle, in the same order the bundle stores them. Mirrors `manifest.json`'s `difficulties` list inside the bundle itself, minus `chartPath`/`noteCount` (those are internal to the bundle, not needed by the browse grid). |
| `download_count` | number | Times downloaded. Not tracked server-side yet — always `0` until there's a backend to increment it. |
| `rating` | number | Average community rating. Not tracked server-side yet — always `0.0` until there's a backend. |
| `updated_at` | string | ISO date (`YYYY-MM-DD`) the entry was last published/updated. |

There is intentionally no `leaderboard` field. Don't add one without a real backend behind it.

## Publishing a new map (v1 — manual PR)

1. Build the bundle the same way the editor's export flow does: call
   `OctetBundle.write_bundle(bundle_path, audio_path, charts, manifest)` (see `core/octet_bundle.gd`)
   with the map's `Chart` objects and source audio. `tools/build_seed_bundle.gd` is a worked example
   of this for the repo's one seed map — copy its shape for a new map rather than writing the zip by
   hand.
2. Save the result as `maps/<id>.octet`, where `<id>` matches the manifest entry's `id`.
3. Add a new entry to `maps/index.json`'s `"maps"` array following the schema above. Pull the
   `title`/`artist`/`mapper`/`bpm`/star ratings from the charts themselves — don't hand-type numbers
   that drift from the actual chart data.
4. Open a PR adding both files. Once merged to `master`, the manifest and bundle URLs resolve
   automatically (they already point at `master`) — no separate publish/release step needed.

There is no in-app publishing flow yet; that's a stretch goal, not required for v1.

## Future: GitHub Releases

As the number of maps and total bundle size grows, storing every `.octet` as a tracked repo file
will bloat repo history (zips don't diff well, and `git clone` gets slower forever). At that point,
migrate to attaching bundles as **GitHub Release assets** instead — `bundle_url` in the manifest
would point at a release download URL rather than `raw.githubusercontent.com`, and `maps/index.json`
would keep living in the repo as the lightweight index. This is a future migration, not something
built now; the current repo-files approach is simplest for the first real batch of maps.
