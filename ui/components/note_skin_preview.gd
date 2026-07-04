extends Control
## Demo-only note-skin swatch for the Components mockup sheet ("Note
## skins": tap/hold/missed/hit-burst per lane colour).
##
## Mirrors game/playfield_view.gd's actual draw technique (glow halo +
## solid circle for taps, translucent tail + head circle for holds) at
## the same NOTE_RADIUS so the component sheet is an honest preview of
## what gameplay renders -- but this file is NOT shared code with
## playfield_view.gd. Note rendering is gameplay-agent-owned per
## CLAUDE.md's task orchestration; this is a standalone copy scoped to
## the component sheet, not a refactor target for playfield_view.gd.

enum State { TAP, HOLD, MISSED, HIT_BURST }

@export var lane_color: Color = DesignTokens.LANE_COLOR_PINK:
	set(v):
		lane_color = v
		queue_redraw()
@export var state: State = State.TAP:
	set(v):
		state = v
		queue_redraw()

## Matches game/playfield_view.gd's NOTE_RADIUS exactly, so this preview
## is drawn at the same scale as real gameplay notes.
const NOTE_RADIUS: float = 28.0
const HOLD_TAIL_WIDTH: float = 22.0
const GLOW_RADIUS_MULT: float = 1.4
const GLOW_ALPHA: float = 0.35
const TAIL_ALPHA: float = 0.4


func _draw() -> void:
	match state:
		State.HOLD:
			_draw_tail()
			_draw_note_circle(Vector2(size.x / 2.0, size.y - NOTE_RADIUS), lane_color, true)
		State.MISSED:
			draw_circle(Vector2(size.x / 2.0, size.y / 2.0), NOTE_RADIUS, DesignTokens.COLOR_MISS)
		State.HIT_BURST:
			_draw_burst(Vector2(size.x / 2.0, size.y / 2.0))
		_:
			_draw_note_circle(Vector2(size.x / 2.0, size.y / 2.0), lane_color, true)


func _draw_note_circle(center: Vector2, color: Color, with_glow: bool) -> void:
	if with_glow:
		var glow := Color(color.r, color.g, color.b, GLOW_ALPHA)
		draw_circle(center, NOTE_RADIUS * GLOW_RADIUS_MULT, glow)
	draw_circle(center, NOTE_RADIUS, color)


func _draw_tail() -> void:
	var head_y := size.y - NOTE_RADIUS
	var half_width := HOLD_TAIL_WIDTH / 2.0
	var cx := size.x / 2.0
	var transparent := Color(lane_color.r, lane_color.g, lane_color.b, 0.0)
	var translucent := Color(lane_color.r, lane_color.g, lane_color.b, TAIL_ALPHA)
	var points := PackedVector2Array([
		Vector2(cx - half_width, 0.0),
		Vector2(cx + half_width, 0.0),
		Vector2(cx + half_width, head_y),
		Vector2(cx - half_width, head_y),
	])
	var colors := PackedColorArray([transparent, transparent, translucent, translucent])
	draw_polygon(points, colors)


## Approximates the mockup's radial-gradient hit burst (bright flash
## core fading into the lane colour) with two concentric flat circles --
## no shader, but visually close at this size.
func _draw_burst(center: Vector2) -> void:
	var outer := Color(lane_color.r, lane_color.g, lane_color.b, 0.3)
	draw_circle(center, NOTE_RADIUS, outer)
	var inner := Color(DesignTokens.COLOR_PERFECT_FLASH.r, DesignTokens.COLOR_PERFECT_FLASH.g, DesignTokens.COLOR_PERFECT_FLASH.b, 0.95)
	draw_circle(center, NOTE_RADIUS * 0.5, inner)
