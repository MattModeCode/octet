# Bootstrap spec

Phase 1 output of the `project-bootstrap` skill. Hand this to Claude Code alongside `PROJECT_BRIEF.md` when you start Phase 2.

```
=== BOOTSTRAP SPEC ===
PROJECT_NAME:    Octet
PROJECT_TAGLINE: An eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community.
REPO_NAME:       octet
GITHUB_OWNER:    MattModeCode
VAULT_PATH:      C:\Users\1chin\OneDrive\Documents\MD Files\Octet Vault (dedicated, project-specific vault)
STACK:           Godot 4 (GDScript; optional Rust GDExtension for audio analysis) + Firebase (Auth, Firestore, Cloud Storage, Cloud Functions)
FIRST_MILESTONE: Playable single-song vertical scroller — eight lanes on the home row (A S D F / J K L ;), taps, chords, and holds falling to a judgment line with timing windows, combo, and an accuracy grade on a results screen. Local chart, no online layer.
=== END SPEC ===
```

## Deviations from the standard runbook

- **No version control automation.** Do not run `git init`, `git add`, `git commit`, or `git push`, and do not install the auto-push Stop hook from `templates/settings.json`. Matthew commits and uploads the repo himself. Everything else in the runbook (writing files, wiring the read-only vault, writing `CLAUDE.md`, writing `.gitignore`) still applies — just no git operations and no hooks.
- **This repo replaces the existing QWERTY repo**, including its downloads/releases. Treat it as a fresh, standalone project, not a fork.
- **Own visual identity.** Octet does *not* use the MashuAI brand palette. Its palette and type are defined in `DESIGN_BRIEF.md` and are the single source of truth for anything visual.
- **Backend is Firebase** (not Supabase).
