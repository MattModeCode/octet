extends Node
## DesignTokens — single source of truth for Octet's palette and type system.
##
## Mirrors docs/DESIGN_BRIEF.md §2 (palette) and §3 (typography) exactly.
## Registered as an autoload singleton in project.godot ("DesignTokens").
##
## Hard project rule: no other script or scene should hard-code hex colours.
## Reference these constants instead, e.g. `DesignTokens.COLOR_PINK`,
## `DesignTokens.lane_color(3)`.

# ---------------------------------------------------------------------------
# Core palette (DESIGN_BRIEF.md §2)
# ---------------------------------------------------------------------------

## Ink — app background. Near-black, faint warm tint.
const COLOR_INK: Color = Color("#0C0A0F")

## Surface — panels, cards.
const COLOR_SURFACE: Color = Color("#16131B")

## Surface raised — popovers, active panels.
const COLOR_SURFACE_RAISED: Color = Color("#1F1A26")

## Hairline / border — subtle dividers.
const COLOR_HAIRLINE: Color = Color("#2A2431")

## Text primary — warm off-white.
const COLOR_TEXT_PRIMARY: Color = Color("#F5F1F5")

## Text secondary — labels, metadata.
const COLOR_TEXT_SECONDARY: Color = Color("#A79FAE")

## Text muted — disabled, hints.
const COLOR_TEXT_MUTED: Color = Color("#6E6676")

## Octet Pink — primary accent. Brand accent, primary actions, combo.
const COLOR_PINK: Color = Color("#FF2D6E")

## Amber — secondary accent. Highlights, stars, perfect flash.
const COLOR_AMBER: Color = Color("#FFC93C")

## Perfect flash — hit burst on Perfect.
const COLOR_PERFECT_FLASH: Color = Color("#FFF4D6")

## Miss / inactive — missed notes, greyed states.
const COLOR_MISS: Color = Color("#4A444F")

## Danger — low health, destructive actions.
const COLOR_DANGER: Color = Color("#FF3B3B")

# ---------------------------------------------------------------------------
# Lane colours (mirrored sunset spectrum) — DESIGN_BRIEF.md §2, PROJECT_BRIEF.md §2.1
# ---------------------------------------------------------------------------
#
# Lane index | Key | Finger      | Colour
#     0      |  A  | L pinky     | Electric orchid #B14AED
#     1      |  S  | L ring      | Octet pink      #FF2D6E
#     2      |  D  | L middle    | Coral orange    #FF7A3C
#     3      |  F  | L index     | Amber gold      #FFC93C
#     4      |  J  | R index     | Amber gold      #FFC93C
#     5      |  K  | R middle    | Coral orange    #FF7A3C
#     6      |  L  | R ring      | Octet pink      #FF2D6E
#     7      |  ;  | R pinky     | Electric orchid #B14AED
#
# Mirrored pairs: (0, 7), (1, 6), (2, 5), (3, 4).

const LANE_COLOR_ORCHID: Color = Color("#B14AED")
const LANE_COLOR_PINK: Color = Color("#FF2D6E")
const LANE_COLOR_CORAL: Color = Color("#FF7A3C")
const LANE_COLOR_AMBER: Color = Color("#FFC93C")

const LANE_COLORS: Array[Color] = [
	LANE_COLOR_ORCHID, # lane 0 — A — L pinky
	LANE_COLOR_PINK,   # lane 1 — S — L ring
	LANE_COLOR_CORAL,  # lane 2 — D — L middle
	LANE_COLOR_AMBER,  # lane 3 — F — L index
	LANE_COLOR_AMBER,  # lane 4 — J — R index
	LANE_COLOR_CORAL,  # lane 5 — K — R middle
	LANE_COLOR_PINK,   # lane 6 — L — R ring
	LANE_COLOR_ORCHID, # lane 7 — ; — R pinky
]

# ---------------------------------------------------------------------------
# Judgment line
# ---------------------------------------------------------------------------

## Judgment line base colour.
const COLOR_JUDGMENT_LINE: Color = Color("#F5F1F5")

## Judgment line glow — soft Octet-pink glow per DESIGN_BRIEF.md §2.
const COLOR_JUDGMENT_GLOW: Color = Color("#FF2D6E")

# ---------------------------------------------------------------------------
# Corner radii (DESIGN_BRIEF.md §7)
# ---------------------------------------------------------------------------

## Cards: medium and consistent, 10-12px. Using the midpoint, 11px.
const CORNER_RADIUS_CARD: int = 11

## Controls: 8px.
const CORNER_RADIUS_CONTROL: int = 8

# ---------------------------------------------------------------------------
# Typography (DESIGN_BRIEF.md §3)
# ---------------------------------------------------------------------------

## Display / logo / large headings.
const FONT_FAMILY_DISPLAY: String = "Space Grotesk"

## UI / body text.
const FONT_FAMILY_UI: String = "Inter"

## HUD numerics (score, combo, accuracy, timing) — tabular figures.
const FONT_FAMILY_MONO: String = "JetBrains Mono"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the colour for the given lane index (0-7, per the eight-lane design).
## Clamps out-of-range indices into bounds and logs an error, rather than
## crashing, since this may be called from hot gameplay/render paths.
static func lane_color(lane_index: int) -> Color:
	if lane_index < 0 or lane_index > 7:
		push_error("DesignTokens.lane_color: lane_index %d out of range [0, 7]; clamping." % lane_index)
		lane_index = clampi(lane_index, 0, 7)
	return LANE_COLORS[lane_index]
