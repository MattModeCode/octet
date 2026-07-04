extends Control
## Reusable health bar (Components mockup "Health bar": a rounded pill
## track, filled with a pink->amber gradient at healthy values or a solid
## danger red below `danger_threshold`).
##
## Pure custom-draw, no class_name (same convention as
## ui/radial_background.gd / game/playfield_view.gd) -- instanced as a
## packed scene.
##
## Fixes the sliver bug documented in docs/DESIGN_HANDOFF.md: the
## existing gameplay.tscn health bar clips a plain rectangular
## TextureRect fill inside a rounded-cornered Panel via
## `clip_contents = true` -- but Control clipping is always to the
## bounding *rectangle*, not to the StyleBoxFlat's rounded silhouette,
## so a hairline-scale square corner of the fill can poke out past the
## rounded track. Here the fill is drawn as its own rounded shape
## (circle end-caps + a vertex-coloured rect middle for the gradient),
## the same capsule technique game/playfield_view.gd already uses for
## hold-note tails, so there is nothing to clip in the first place.

## 0-1 health fraction. Setter clamps and redraws.
@export var value01: float = 1.0:
	set(v):
		value01 = clampf(v, 0.0, 1.0)
		queue_redraw()
## At or below this fraction, the fill switches from the pink->amber
## gradient to a solid danger red (matches the mockup's second example
## bar, shown at 22%).
@export var danger_threshold: float = 0.3

const _TRACK_RADIUS: int = 20
const _INSET: float = 1.0

var _gradient: Gradient


func _ready() -> void:
	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array([0.0, 1.0])
	_gradient.colors = PackedColorArray([DesignTokens.COLOR_PINK, DesignTokens.COLOR_AMBER])
	queue_redraw()


func _draw() -> void:
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	track_style.border_width_left = 1
	track_style.border_width_top = 1
	track_style.border_width_right = 1
	track_style.border_width_bottom = 1
	track_style.border_color = DesignTokens.COLOR_HAIRLINE
	track_style.set_corner_radius_all(_TRACK_RADIUS)
	draw_style_box(track_style, Rect2(Vector2.ZERO, size))

	var inner_origin := Vector2(_INSET, _INSET)
	var inner_size := size - Vector2(_INSET * 2.0, _INSET * 2.0)
	var fraction := clampf(value01, 0.0, 1.0)
	var fill_width := inner_size.x * fraction
	if fill_width <= 0.0 or inner_size.y <= 0.0:
		return

	var danger := value01 <= danger_threshold
	var start_color := DesignTokens.COLOR_DANGER if danger else _gradient.sample(0.0)
	var end_color := DesignTokens.COLOR_DANGER if danger else _gradient.sample(fraction)

	var radius := inner_size.y / 2.0
	var start_x := inner_origin.x
	var end_x := inner_origin.x + fill_width
	var mid_y := inner_origin.y + radius

	if fill_width <= radius * 2.0:
		draw_circle(Vector2(start_x + minf(radius, fill_width / 2.0), mid_y), minf(radius, fill_width / 2.0), start_color)
		return

	draw_circle(Vector2(start_x + radius, mid_y), radius, start_color)
	draw_circle(Vector2(end_x - radius, mid_y), radius, end_color)

	var rect_left := start_x + radius
	var rect_right := end_x - radius
	var points := PackedVector2Array([
		Vector2(rect_left, inner_origin.y),
		Vector2(rect_right, inner_origin.y),
		Vector2(rect_right, inner_origin.y + inner_size.y),
		Vector2(rect_left, inner_origin.y + inner_size.y),
	])
	var colors := PackedColorArray([start_color, end_color, end_color, start_color])
	draw_polygon(points, colors)
