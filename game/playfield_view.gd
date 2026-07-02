extends Control
## Pure-display 8-lane playfield for the gameplay HUD -- the 1a "Classic
## centered" layout imported from "Octet - Gameplay HUD.dc.html" via the
## Claude Design MCP (see docs/DESIGN_HANDOFF.md; the file actually holds
## three directions, 1a/1b/1c, same correction pattern as the editor's "2a"
## -- 1a is implemented here). Draws lane separators, the judgment line +
## glow, key labels, falling notes (tap/hold/chord as circles, matching the
## mockup), a hit burst on discrete non-Miss judgments, and the rising/
## fading judgment popup text.
##
## Pure display, like editor/waveform_view.gd and
## editor/note_timeline_view.gd -- game/gameplay.gd owns the JudgeEngine,
## the Conductor clock, and all chart/session state; this node only reads
## pushed state and draws. Sized and positioned in gameplay.tscn to exactly
## match the mockup's 640x910 playfield rect (centered, top:170 in the
## 1920x1080 design canvas) -- every local coordinate below is taken
## directly from the mockup's own pixel values, relative to that rect.

const LANE_COUNT: int = 8
const LANE_WIDTH: float = 80.0
const JUDGMENT_Y: float = 764.0
const KEY_LABEL_Y: float = 788.0
const NOTE_RADIUS: float = 28.0
const HOLD_TAIL_WIDTH: float = 24.0

## Cosmetic-only scroll rate (does not affect judgment, which is purely
## time-based against Conductor.song_time_ms back in game/gameplay.gd) --
## the same constant/approach game/vertical_slice.gd (Stage 1) established
## and the pre-1a game/gameplay.gd carried forward unchanged.
const PIXELS_PER_MS: float = 0.6

const BURST_DURATION_MS: float = 420.0
const POPUP_DURATION_MS: float = 620.0
const POPUP_RISE_PX: float = 46.0
const PULSE_PERIOD_MS: float = 1300.0

const KEY_LABELS: Array[String] = ["A", "S", "D", "F", "J", "K", "L", ";"]

const FONT_MONO: Font = preload("res://assets/fonts/font_mono.tres")
const FONT_DISPLAY: Font = preload("res://assets/fonts/font_display.tres")

var _entries: Array[Dictionary] = []
var _song_time_ms: float = 0.0
var _scroll_speed: float = 1.0
var _reduced_flash: bool = false
var _reduced_motion: bool = false

var _burst_lane: int = -1
var _burst_started_ms: float = -INF
var _popup_kind: Judgment.Kind = Judgment.Kind.PERFECT
var _popup_started_ms: float = -INF


## Precomputes per-note display data once per chart load. [param good_window_ms]
## is Config.gameplay.window_good_ms -- notes hide this long past their (or
## their hold tail's) target time, the same "the Good window elapsing means
## it has necessarily been resolved one way or another, safe to hide" rule
## the pre-1a implementation used (game/gameplay.gd's earlier handoff note).
func set_chart(notes: Array[ChartNote], good_window_ms: float) -> void:
	_entries.clear()
	for note in notes:
		var is_hold := note.type == "hold"
		var target_ms := float(note.end_time_ms if is_hold else note.time_ms)
		_entries.append({
			"note": note,
			"is_hold": is_hold,
			"target_ms": target_ms,
			"hide_after_ms": target_ms + good_window_ms,
		})
	queue_redraw()


func set_accessibility(reduced_flash: bool, reduced_motion: bool) -> void:
	_reduced_flash = reduced_flash
	_reduced_motion = reduced_motion
	queue_redraw()


## Called every frame from gameplay.gd's _process with the live Conductor
## clock -- drives note positions and every time-based animation below.
func update_state(song_time_ms: float, scroll_speed: float) -> void:
	_song_time_ms = song_time_ms
	_scroll_speed = scroll_speed
	queue_redraw()


## Discrete non-Miss judgments only (gameplay.gd doesn't call this for
## Miss, or for hold-tick credit) -- a short radial flash at the struck
## lane's receptor.
func trigger_hit_burst(lane: int) -> void:
	if _reduced_flash:
		return
	_burst_lane = lane
	_burst_started_ms = float(Time.get_ticks_msec())


## Every discrete judgment (including Miss) pops the judgment name above
## the line.
func trigger_judgment_popup(kind: Judgment.Kind) -> void:
	_popup_kind = kind
	_popup_started_ms = float(Time.get_ticks_msec())


func _draw() -> void:
	_draw_lane_separators()
	_draw_judgment_line()
	_draw_key_labels()
	_draw_notes()
	_draw_hit_burst()
	_draw_judgment_popup()


func _draw_lane_separators() -> void:
	for i in range(1, LANE_COUNT):
		var x := i * LANE_WIDTH
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), DesignTokens.COLOR_HAIRLINE, 1.0)


## Soft-glow judgment line with a slow breathing pulse (the mockup's
## octetPulseLine keyframe, .55<->1.0 opacity over 1.3s) -- same layered-
## line glow trick editor/waveform_view.gd uses for its playhead, since
## Control 2D drawing has no native glow filter. Static (no pulse) under
## reduced motion.
func _draw_judgment_line() -> void:
	var pulse := 1.0 if _reduced_motion else _pulse(0.55, 1.0, PULSE_PERIOD_MS)
	var glow := DesignTokens.COLOR_JUDGMENT_GLOW
	for layer in range(3, 0, -1):
		var layer_colour := glow
		layer_colour.a = 0.10 * pulse
		draw_line(Vector2(0.0, JUDGMENT_Y), Vector2(size.x, JUDGMENT_Y), layer_colour, 2.0 + layer * 5.0)
	var line_colour := DesignTokens.COLOR_JUDGMENT_LINE
	line_colour.a = pulse
	draw_line(Vector2(0.0, JUDGMENT_Y), Vector2(size.x, JUDGMENT_Y), line_colour, 3.0)


func _draw_key_labels() -> void:
	for lane in LANE_COUNT:
		var colour := DesignTokens.lane_color(lane)
		draw_string(FONT_MONO, Vector2(lane * LANE_WIDTH, KEY_LABEL_Y), KEY_LABELS[lane], HORIZONTAL_ALIGNMENT_CENTER, LANE_WIDTH, 13, colour)


func _draw_notes() -> void:
	for entry in _entries:
		if _song_time_ms > entry.hide_after_ms:
			continue
		var note: ChartNote = entry.note
		var colour := DesignTokens.lane_color(note.lane)
		var lane_centre_x := note.lane * LANE_WIDTH + LANE_WIDTH * 0.5

		if entry.is_hold:
			var head_y := _note_y(float(note.time_ms))
			var tail_y := _note_y(float(note.end_time_ms))
			var top_y := minf(head_y, tail_y)
			var bottom_y := maxf(head_y, tail_y)
			var tail_colour := colour
			tail_colour.a = 0.45
			draw_rect(Rect2(lane_centre_x - HOLD_TAIL_WIDTH * 0.5, top_y, HOLD_TAIL_WIDTH, bottom_y - top_y), tail_colour)
			_draw_note_circle(Vector2(lane_centre_x, head_y), colour)
			_draw_note_circle(Vector2(lane_centre_x, tail_y), colour)
		else:
			_draw_note_circle(Vector2(lane_centre_x, _note_y(entry.target_ms)), colour)


func _note_y(target_ms: float) -> float:
	return JUDGMENT_Y - (target_ms - _song_time_ms) * PIXELS_PER_MS * _scroll_speed


## A soft glow behind a solid circle -- the same "wider, more transparent
## layer behind a crisp shape" trick used for the judgment line above.
func _draw_note_circle(centre: Vector2, colour: Color) -> void:
	var glow := colour
	glow.a = 0.35
	draw_circle(centre, NOTE_RADIUS * 1.4, glow)
	draw_circle(centre, NOTE_RADIUS, colour)


## DESIGN_BRIEF.md §5: hits burst "in the lane colour" -- the mockup's
## sample burst only reads as amber because it happens to sit on lane 3
## (amber gold), not because the burst itself is hardcoded amber.
func _draw_hit_burst() -> void:
	if _burst_lane < 0:
		return
	var elapsed := float(Time.get_ticks_msec()) - _burst_started_ms
	if elapsed < 0.0 or elapsed > BURST_DURATION_MS:
		return
	var t := elapsed / BURST_DURATION_MS
	var centre := Vector2(_burst_lane * LANE_WIDTH + LANE_WIDTH * 0.5, JUDGMENT_Y)
	var colour := DesignTokens.lane_color(_burst_lane)
	colour.a = (1.0 - t) * 0.9
	draw_circle(centre, lerpf(NOTE_RADIUS * 0.6, NOTE_RADIUS * 1.8, t), colour)


func _draw_judgment_popup() -> void:
	var elapsed := float(Time.get_ticks_msec()) - _popup_started_ms
	if elapsed < 0.0 or elapsed > POPUP_DURATION_MS:
		return
	var t := elapsed / POPUP_DURATION_MS
	var colour := _popup_colour(_popup_kind)
	colour.a = clampf(1.0 - (t - 0.7) / 0.3, 0.0, 1.0) if t > 0.7 else 1.0
	var y := JUDGMENT_Y - 90.0 - POPUP_RISE_PX * t
	var text := Judgment.display_name(_popup_kind).to_upper()
	draw_string(FONT_DISPLAY, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, colour)


func _popup_colour(kind: Judgment.Kind) -> Color:
	match kind:
		Judgment.Kind.PERFECT:
			return DesignTokens.COLOR_PERFECT_FLASH
		Judgment.Kind.GREAT:
			return DesignTokens.COLOR_AMBER
		Judgment.Kind.GOOD:
			return DesignTokens.COLOR_TEXT_SECONDARY
		_:
			return DesignTokens.COLOR_DANGER


## Triangle-wave pulse between [param low] and [param high] over
## [param period_ms], driven by engine ticks (not the song clock) so it
## keeps breathing consistently regardless of Conductor pause/seek state.
func _pulse(low: float, high: float, period_ms: float) -> float:
	var phase := fmod(float(Time.get_ticks_msec()), period_ms) / period_ms
	var triangle := 1.0 - absf(phase * 2.0 - 1.0)
	return lerpf(low, high, triangle)
