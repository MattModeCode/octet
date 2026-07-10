extends Control
## Small "time remaining in the song" pie chart for the gameplay HUD, shown
## under the COMBO value in the top-right block (game/gameplay.tscn). Empty
## at song start, a full disc when the chart ends -- driven every frame by
## game/gameplay.gd from (song_time_ms / chart_end_ms).
##
## Pure custom-draw, no class_name (same convention as
## ui/components/health_bar.gd / ui/playfield_view.gd) -- instanced as a
## packed scene. Not part of the original "1a Classic centered" Gameplay HUD
## mockup (re-checked against the Claude Design MCP project before adding --
## see CLAUDE.md's design-fidelity rule); styled fresh from DESIGN_BRIEF
## tokens rather than approximated from an existing element: a
## COLOR_SURFACE_RAISED/COLOR_HAIRLINE track ring (matching the health bar's
## track) filled with a COLOR_AMBER wedge (matching the ACC value directly
## above it in the same column).

## 0-1 song-progress fraction. Setter clamps and redraws.
@export var value01: float = 0.0:
	set(v):
		value01 = clampf(v, 0.0, 1.0)
		queue_redraw()

## Degrees per triangle-fan step when building the wedge polygon -- small
## enough to read as a smooth arc at this control's size.
const _ARC_STEP_DEG: float = 5.0
## Fraction at/above which the wedge is drawn as a full solid disc, so
## floating-point error near 1.0 never leaves a hairline seam unfilled.
const _FULL_THRESHOLD: float = 0.999


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	if radius <= 0.0:
		return
	var center := size / 2.0

	draw_circle(center, radius, DesignTokens.COLOR_SURFACE_RAISED)
	draw_arc(center, radius - 0.5, 0.0, TAU, 48, DesignTokens.COLOR_HAIRLINE, 1.0, true)

	var fraction := clampf(value01, 0.0, 1.0)
	if fraction <= 0.0:
		return
	if fraction >= _FULL_THRESHOLD:
		draw_circle(center, radius, DesignTokens.COLOR_AMBER)
		return

	draw_polygon(_wedge_points(center, radius, fraction), PackedColorArray([DesignTokens.COLOR_AMBER]))


## Builds a triangle-fan polygon for a pie wedge starting at 12 o'clock and
## sweeping clockwise through [param fraction] of the full circle.
func _wedge_points(center: Vector2, radius: float, fraction: float) -> PackedVector2Array:
	var sweep_deg := 360.0 * fraction
	var step_count := maxi(1, int(ceil(sweep_deg / _ARC_STEP_DEG)))

	var points := PackedVector2Array([center])
	for i in range(step_count + 1):
		var deg := minf(sweep_deg, i * (sweep_deg / step_count))
		# 12 o'clock = -90 deg in Godot's standard (0 deg = +x/east) convention;
		# clockwise sweep is +deg from there.
		var angle := deg_to_rad(deg - 90.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
