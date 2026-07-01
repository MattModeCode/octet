# Octet — design brief

The single source of truth for how Octet looks and feels. This is a standalone identity — it does **not** use the MashuAI brand. Hand this to Claude Design to produce high-fidelity mockups, then to Claude Code as the visual spec.

---

## 1. Brand snapshot

- **Name:** Octet
- **Tagline:** An eight-lane keyboard rhythm game with a built-in beat editor and an online map community.
- **Personality:** fast, warm, kinetic, precise. Keyboard-native and competitive, but inviting — not clinical, not corporate. High-energy without being loud or cluttered.
- **Deliberate contrast:** the old QWERTY identity was cold blue and futuristic. Octet goes the other way — a dark stage lit by warm, saturated colour. Think neon at night, not a spaceship interface.

---

## 2. Palette

Dark base, warm high-energy accents. Use accents for energy and focus; keep the surrounding UI calm.

| Role | Hex | Notes |
|------|-----|-------|
| Ink (app background) | `#0C0A0F` | Near-black, faint warm tint |
| Surface | `#16131B` | Panels, cards |
| Surface raised | `#1F1A26` | Popovers, active panels |
| Hairline / border | `#2A2431` | Subtle dividers |
| Text primary | `#F5F1F5` | Warm off-white |
| Text secondary | `#A79FAE` | Labels, metadata |
| Text muted | `#6E6676` | Disabled, hints |
| **Octet Pink** (primary accent) | `#FF2D6E` | Brand accent, primary actions, combo |
| **Amber** (secondary accent) | `#FFC93C` | Highlights, stars, perfect flash |
| Perfect flash | `#FFF4D6` | Hit burst on Perfect |
| Miss / inactive | `#4A444F` | Missed notes, greyed states |
| Danger | `#FF3B3B` | Low health, destructive actions |

### Lane colours (mirrored sunset spectrum)

Lane pairs share a colour, spreading warm hues from the pinkies inward to the index fingers:

| Lanes | Keys | Colour | Hex |
|-------|------|--------|-----|
| 1 & 8 | A / ; | Electric orchid | `#B14AED` |
| 2 & 7 | S / L | Octet pink | `#FF2D6E` |
| 3 & 6 | D / K | Coral orange | `#FF7A3C` |
| 4 & 5 | F / J | Amber gold | `#FFC93C` |

Judgment line is `#F5F1F5` with a soft Octet-pink glow. Hold bodies use a translucent tint of their lane colour.

---

## 3. Typography

- **Display / logo / large headings:** Space Grotesk (Bold / Medium). Distinctive, geometric, a little offbeat.
- **UI / body:** Inter. Clean and legible at small sizes.
- **HUD numerics (score, combo, accuracy, timing):** JetBrains Mono, tabular figures. A deliberate keyboard/monospace nod, and stops the score from jittering as digits change.

Use sentence case for UI labels and headings. Numbers are the loudest text on the gameplay screen.

---

## 4. Logo / wordmark

Minimal wordmark, "Octet," in Space Grotesk. Optional mark riffs on *eight*: eight tally marks / lane ticks, or the "O" built from eight segments. Keep it flat — no heavy gradients, no bevels. Works on the ink background and inverts cleanly.

---

## 5. Motion and feel

The screen should feel alive to the music without becoming noisy:

- Notes fall smoothly; hits emit a short burst in the lane colour (Perfect = amber/cream, bright; lower judgments dimmer).
- A subtle pulse on the beat (playfield edges, logo) — restrained, never seizure-y.
- Combo number scales up on milestones; judgment text pops briefly above the line ("Perfect / Great / Good / Miss").
- Transitions are quick and snappy (rhythm players are impatient). Nothing that delays getting into a song.

Include an epilepsy-safety note: keep flashing under safe thresholds and offer a "reduced motion / reduced flash" toggle.

---

## 6. Screens to mock up

Deliver high-fidelity mockups of each. Target desktop 16:9 at 1920×1080.

1. **Main menu / home** — logo, primary entry points (Play, Editor, Browse maps, Profile), quiet ambient beat pulse.
2. **Song select** — scrollable list of installed maps; each row shows title, artist, mapper, difficulties, star rating; a detail/preview panel; sort and filter controls.
3. **Gameplay HUD** — the core screen. Eight lanes with mirrored colours, judgment line near the bottom, falling taps/holds/chords, live score + combo + accuracy (mono), a health bar, judgment popups, and the hit burst. Show tap, hold, and chord note skins.
4. **Results screen** — big grade, final accuracy, max combo, score, per-judgment breakdown, a hit-error histogram (early/late), and retry / next / back.
5. **Calibration screen** — tap-to-the-beat routine with a clear metronome visual and the resulting audio/input offset values.
6. **Editor** — the flagship surface. Horizontal waveform + beat-grid overlay + playhead along the top; a vertical eight-lane note timeline; a note-tool palette (tap / hold / select); snap-division selector (1/1…1/16); transport controls (play, scrub, speed, metronome); difficulty tabs; and an inspector for the selected note / timing point. Show BPM + offset fields with the "detected" values.
7. **Map hub / browser** — grid of community maps with cover art, title, mapper, stars, downloads, rating; search bar and filters; and a map detail page with difficulties, preview, download, and the per-map leaderboard.
8. **Profile** — user stats (global rank, performance, average accuracy), recent plays, and best scores.
9. **Auth / sign-in** — email + Google, minimal.

Also deliver a small **component sheet**: buttons (primary / secondary / ghost), inputs, dropdowns, sliders (scroll speed, offset), tabs, cards, the health bar, and note skins in every lane colour and state (idle / hit / missed).

---

## 7. Layout and components

- Generous dark negative space; content on `#16131B` surfaces over the `#0C0A0F` ink.
- Corner radius: medium and consistent (e.g. 10–12px on cards, 8px on controls).
- Borders are hairline `#2A2431`; use accent glow sparingly for focus and active states, never as everyday decoration.
- Primary actions in Octet pink; secondary as ghost/outline; destructive in danger red.
- Clear states for hover / active / focus / disabled on every control.

---

## 8. Accessibility

- **Colourblind safety:** never rely on lane colour alone. The mirrored *position* already disambiguates lanes; reinforce with optional per-lane note-skin shapes and a colourblind palette option.
- Maintain readable contrast for all text on dark surfaces.
- Expose scroll speed, reduced motion/flash, and note-skin/colour options in settings.

---

## 9. What to deliver

High-fidelity mockups of all nine screens above at 1920×1080, plus the component sheet, in the Octet palette and type. Prioritise the **gameplay HUD** and the **editor** — those two carry the product.
