# Octet — Claude Code operating contract

**Project:** Octet
**What it is:** An eight-lane keyboard rhythm game with a built-in beat-mapping editor and an online map community.

This is the operating contract for working on Octet in Claude Code. Read `docs/PROJECT_BRIEF.md` for what to build and `docs/DESIGN_BRIEF.md` for how it looks.

---

## 1. Obsidian + Graphify

The Obsidian vault is the read-only source of truth for context, notes, and decisions. Read from it freely; treat vault files as reference, not something to rewrite as part of a task. Keep vault paths out of the repo. Graphify links notes to the work — when a session produces a durable decision or learning, surface it so it can be captured in the vault, not buried in code comments.

## 2. How to operate

- **Answer-first, terse.** Lead with the result or the change. No preamble, minimal ceremony.
- **Autonomous.** Confirm the plan and scope on anything large, then proceed without hand-holding. Ask a clarifying question only when genuinely blocked — not to hedge.
- **Canadian spelling**, sentence case for headings and labels.
- **Design system is `docs/DESIGN_BRIEF.md`** — Octet's own palette and type. This project does **not** use the MashuAI brand. Never guess at colours or layout; apply the brief.
- Keep tunables (timing windows, health deltas, star-rating, offsets) in config, not scattered through code.

## 3. The self-improvement loop

At the end of a working session, capture what was learned: patterns that worked, dead ends, and any decision that changes how future work should proceed. Fold durable lessons back into the vault, `CLAUDE.md`, or the relevant skill so the next session starts smarter. The project should get easier to work on over time, not harder.

## 4. gStack

Use gStack for planning and execution. Run `/autoplan` for detailed, milestone-level planning rather than over-planning by hand up front — the project brief sets direction; gStack sequences the work. Follow gStack protocols for tasks, checkpoints, and progress.

## 5. Version control

**Manual — handled by Matthew.** Do **not** run `git init`, `git add`, `git commit`, or `git push`. Do **not** install any auto-commit or auto-push hook (no `Stop` hook). Do not create or modify git configuration. Just create and edit files in place; Matthew commits and uploads the repository himself, at his own pace. A `.gitignore` is present for hygiene when he does.
