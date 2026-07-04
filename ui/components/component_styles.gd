class_name ComponentStyles
## Shared StyleBoxFlat factories for patterns that need a per-instance
## parameter (an accent colour, an active/inactive flag) and so can't be
## expressed as a single static Theme type variation the way
## PrimaryButton/CardSelected/etc. in assets/theme/octet_theme.tres are.
##
## Generalizes the hand-rolled `_chip_style_normal()`/`_segment_style()`/
## `_difficulty_tab_style()` helpers duplicated across
## game/song_select.gd and editor/editor_main.gd (per the WP-N survey) --
## new pill-tab/chip UI should call these instead of redefining the same
## StyleBoxFlat shape locally. Existing screens are not migrated by this
## pass; that's for whichever per-screen fidelity WP (G...L) touches them
## next, per docs/FEATURE_FIXES_BREAKDOWN.md's WP-N scope note.

const _CORNER_RADIUS_PILL: int = 6
const _CORNER_RADIUS_CHIP: int = 8


## Segmented pill tab (Components mockup "Tabs": active = accent-coloured
## fill + ink text, inactive = transparent + muted text -- text colour is
## the caller's job via font_color overrides, this only returns the box).
static func pill_tab(active: bool, accent: Color = DesignTokens.COLOR_AMBER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent if active else Color.TRANSPARENT
	style.set_corner_radius_all(_CORNER_RADIUS_PILL)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


## Difficulty/filter chip (Components mockup implies via card/tab
## treatment): inactive = hairline border, selected = pink border +
## raised surface. Matches song_select.gd's existing chip proportions.
static func chip(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_SURFACE_RAISED if active else DesignTokens.COLOR_SURFACE
	style.border_width_left = 2 if active else 1
	style.border_width_top = 2 if active else 1
	style.border_width_right = 2 if active else 1
	style.border_width_bottom = 2 if active else 1
	style.border_color = DesignTokens.COLOR_PINK if active else DesignTokens.COLOR_HAIRLINE
	style.set_corner_radius_all(_CORNER_RADIUS_CHIP)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
