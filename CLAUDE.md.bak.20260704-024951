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
- **Design fidelity — always work from the Claude design mockup.** Any UI/visual change must be checked against the corresponding mockup re-fetched live from the Claude Design MCP (project `cc6f9e35-9183-4b42-8d8a-be6dfc135fe1`; use `DesignSync.get_project`/`list_files`/`get_file` against that specific project ID — `list_projects` alone returns empty for it, since it's scoped to design-system-type projects and this is a regular project). Never implement or "match" a mockup from memory, a prose summary, or baked constants alone — always re-fetch first. Screens must look **exactly** like the sketches. If an element genuinely cannot or should not be implemented as designed, flag the deviation explicitly and get it confirmed — never silently cut or approximate it.
- Keep tunables (timing windows, health deltas, star-rating, offsets) in config, not scattered through code.

## 3. The self-improvement loop

At the end of a working session, capture what was learned: patterns that worked, dead ends, and any decision that changes how future work should proceed. Fold durable lessons back into the vault, `CLAUDE.md`, or the relevant skill so the next session starts smarter. The project should get easier to work on over time, not harder.

## 4. gStack

Use gStack for planning and execution. Run `/autoplan` for detailed, milestone-level planning rather than over-planning by hand up front — the project brief sets direction; gStack sequences the work. Follow gStack protocols for tasks, checkpoints, and progress.

## 5. Version control

**Manual — handled by Matthew.** Do **not** run `git init`, `git add`, `git commit`, or `git push`. Do **not** install any auto-commit or auto-push hook (no `Stop` hook). Do not create or modify git configuration. Just create and edit files in place; Matthew commits and uploads the repository himself, at his own pace. A `.gitignore` is present for hygiene when he does.

## 6. Task orchestration

Five persistent subagents live in `.claude/agents/`: **gameplay** (`game/` + `audio/` — play loop, `Conductor`, judging/grading, calibration), **editor** (`editor/` — audio analysis/DSP/FFT, beat grid, chart authoring against `core/chart.gd`'s schema, opus model for the algorithm-heavy work), **ui-screens** (`ui/` + all `.tscn` scenes + theme — owns the Claude Design MCP mockup-fidelity workflow), **netcode** (`net/` + Firebase + the Map Hub community backend), and **test-runner** (read-only — runs the headless suite, no Edit/Write). Use them as follows:

- **Decompose before acting.** Break a multi-part request into subtasks and classify each as independent or dependent before dispatching anything.
- **Independent subtasks → parallel dispatch.** Launch the relevant subagents in a single batch, and be explicit about how many you're launching and each one's file scope.
- **Dependent subtasks → sequential chain.** Run one agent, then pass its summary as input to the next rather than re-deriving context yourself.
- **Never let two subagents write the same file concurrently.** Check file scope before any parallel dispatch. Shared/global files — `project.godot`, autoload registration in it, `core/` source, `config/*.tres`, and the test registration in `tests/run_tests.gd`'s `_register_all_tests()` — are integrated by the **main session only**, never handed to a subagent for concurrent edits. Domain agents read `core/` freely but report needed changes upward instead of editing it.
- **Summaries only.** Subagents return a concise summary of what changed and verify results — never a full transcript or full file/test output — to protect main-session context.
- **Default agent per work type:** gameplay bugs/scoring/timing → `gameplay`; beat-mapping editor, BPM/offset detection, `.oct` chart authoring → `editor`; menu/screen layout, navigation, mockup-fidelity passes → `ui-screens`; online features, Firebase, Map Hub backend → `netcode`; "did this break anything" / running the suite → `test-runner`.
- **Stay in the main session** for judgment calls, quick one-file edits, and tightly-coupled cross-file changes — especially anything touching the shared zone above or a `core/` data model whose change ripples across domains. Don't dispatch a subagent for work that's faster and safer to just do directly.
- **Subagents cannot spawn subagents.** All decomposition and dispatch decisions stay in the main session; an agent that hits a subtask outside its scope reports back rather than delegating further.
