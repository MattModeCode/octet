extends Control
## Note timeline (PROJECT_BRIEF §3.5), rebuilt to match the imported
## "Octet - Editor.dc.html" 2a mockup: eight vertical lane columns with
## time flowing downward (not the earlier eight-horizontal-rows/
## time-flows-right placeholder -- that was a deliberate M2b simplification
## documented as blocked on the mockup import, which has since landed).
## Column x = lane, row y = time; notes are circles falling top-to-bottom;
## holds are a translucent tail plus a circle at the head; the playhead is
## a horizontal line. Column order/letters/colours match
## KeybindDefaults.DEFAULT_LANE_KEYS / DesignTokens.lane_color.
##
## Pure display + input capture -- like waveform_view.gd, all actual chart
## mutation happens in editor_main.gd via editor/note_editor.gd, keeping
## undo/redo recording centralized there. This view only emits signals for
## what the user is asking to do.
##
## Interaction: an explicit tool mode (Tap / Hold / Select -- the note-tool
## palette PROJECT_BRIEF §3.5 asked for) decides what a click/drag does.
## Right-click always deletes the note under the cursor regardless of tool.
## A free-place toggle (§3.5 "free-place (snap off) for off-grid notes")
## skips snapping when on.

signal tap_place_requested(lane: int, time_ms: int)
signal hold_place_requested(lane: int, start_ms: int, end_ms: int)
signal note_delete_requested(note: ChartNote)
signal box_select_requested(start_ms: float, end_ms: float, lane_min: int, lane_max: int)

enum Tool { TAP, HOLD, SELECT }

const LANE_COUNT: int = 8
const BEAT_GRID_MAJOR_EVERY: int = 4
## Minimum drag distance (ms) a Hold-tool drag must cover before it places
## a hold rather than being collapsed to a minimal-length hold at the
## drag's start -- keeps a near-zero-length accidental drag sane.
const MIN_HOLD_LENGTH_MS: float = 30.0
## Mouse tolerance (pixels) for hit-testing an existing note on right-click.
const HIT_TOLERANCE_PX: float = 10.0
## Background shade matching the mockup's timeline body (distinct from the
## shared theme's COLOR_SURFACE, which is a touch lighter).
const COLOR_TIMELINE_BG: Color = Color("#0F0C13")

var _notes: Array[ChartNote] = []
var _selected_notes: Array[ChartNote] = []
var _duration_ms: float = 1.0
var _beat_times_ms: Array[float] = []
var _timing_points: Array[TimingPoint] = []
var _playhead_ms: float = 0.0
var _snap_division: int = 4
var _tool_mode: Tool = Tool.TAP
var _free_place: bool = false

var _dragging: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_lane: int = -1


func set_data(notes: Array[ChartNote], duration_ms: float, beat_times: Array[float], timing_points: Array[TimingPoint]) -> void:
	_notes = notes
	_duration_ms = maxf(1.0, duration_ms)
	_beat_times_ms = beat_times
	_timing_points = timing_points
	queue_redraw()


func set_selection(selected: Array[ChartNote]) -> void:
	_selected_notes = selected
	queue_redraw()


func set_snap_division(division: int) -> void:
	_snap_division = division


func set_tool_mode(mode: Tool) -> void:
	_tool_mode = mode


func set_free_place(enabled: bool) -> void:
	_free_place = enabled


func set_playhead(time_ms: float) -> void:
	_playhead_ms = time_ms
	queue_redraw()


func _column_width() -> float:
	return size.x / LANE_COUNT


func _time_to_y(time_ms: float) -> float:
	return (time_ms / _duration_ms) * size.y


func _y_to_time(y: float) -> float:
	return clampf(y / maxf(1.0, size.y), 0.0, 1.0) * _duration_ms


func _x_to_lane(x: float) -> int:
	return clampi(int(x / _column_width()), 0, LANE_COUNT - 1)


## Snaps [param time_ms] unless free-place is on, in which case it's
## returned unchanged (rounded to the nearest ms) -- §3.5's "free-place
## (snap off) for off-grid notes".
func _snap(time_ms: float) -> int:
	if _free_place or _timing_points.is_empty():
		return int(round(time_ms))
	return int(round(BeatGrid.snap_time_ms(time_ms, _timing_points, _snap_division)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_pos = mb.position
				_drag_lane = _x_to_lane(mb.position.x)
			elif _dragging:
				_finish_drag(mb.position)
				_dragging = false
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var note := _note_near(mb.position)
			if note != null:
				note_delete_requested.emit(note)
	elif event is InputEventMouseMotion and _dragging:
		queue_redraw() # live-update the drag preview.


func _finish_drag(end_pos: Vector2) -> void:
	var start_time := _y_to_time(_drag_start_pos.y)
	var end_time := _y_to_time(end_pos.y)

	match _tool_mode:
		Tool.SELECT:
			var lane_b := _x_to_lane(end_pos.x)
			box_select_requested.emit(
				minf(start_time, end_time), maxf(start_time, end_time),
				mini(_drag_lane, lane_b), maxi(_drag_lane, lane_b)
			)
		Tool.HOLD:
			var snapped_start := _snap(start_time)
			var snapped_end := _snap(end_time)
			if snapped_start > snapped_end:
				var tmp := snapped_start
				snapped_start = snapped_end
				snapped_end = tmp
			if snapped_end - snapped_start < MIN_HOLD_LENGTH_MS:
				snapped_end = snapped_start + int(MIN_HOLD_LENGTH_MS)
			hold_place_requested.emit(_drag_lane, snapped_start, snapped_end)
		Tool.TAP, _:
			tap_place_requested.emit(_drag_lane, _snap(start_time))


func _note_near(pos: Vector2) -> ChartNote:
	var lane := _x_to_lane(pos.x)
	var time_ms := _y_to_time(pos.y)
	var tolerance_ms := (_duration_ms / maxf(1.0, size.y)) * HIT_TOLERANCE_PX
	for note in _notes:
		if note.lane != lane:
			continue
		if note.type == "hold":
			if time_ms >= note.time_ms - tolerance_ms and time_ms <= note.end_time_ms + tolerance_ms:
				return note
		elif absf(time_ms - note.time_ms) <= tolerance_ms:
			return note
	return null


func _draw() -> void:
	var col_w := _column_width()

	draw_rect(Rect2(Vector2.ZERO, size), COLOR_TIMELINE_BG)

	for lane in LANE_COUNT:
		var x := lane * col_w
		if lane > 0:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), DesignTokens.COLOR_HAIRLINE, 1.0)
		var key := KeybindDefaults.DEFAULT_LANE_KEYS[lane]
		var font := ThemeDB.fallback_font
		var text_size := font.get_string_size(key, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string(font, Vector2(x + (col_w - text_size.x) * 0.5, 20.0), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DesignTokens.lane_color(lane))

	for i in _beat_times_ms.size():
		var y := _time_to_y(_beat_times_ms[i])
		var is_major := i % BEAT_GRID_MAJOR_EVERY == 0
		var colour := DesignTokens.COLOR_HAIRLINE
		colour.a = 0.9 if is_major else 0.4
		draw_line(Vector2(0.0, y), Vector2(size.x, y), colour, 1.0)

	for note in _notes:
		_draw_note(note, col_w)

	if _dragging:
		_draw_drag_preview(col_w)

	var playhead_y := _time_to_y(_playhead_ms)
	draw_line(Vector2(0.0, playhead_y), Vector2(size.x, playhead_y), DesignTokens.COLOR_PERFECT_FLASH, 2.0)


func _draw_note(note: ChartNote, col_w: float) -> void:
	var colour := DesignTokens.lane_color(note.lane)
	var cx := note.lane * col_w + col_w * 0.5
	var radius := minf(col_w * 0.5 - 6.0, 22.0)
	var head_y := _time_to_y(note.time_ms)

	if note.type == "hold":
		var tail_y := _time_to_y(note.end_time_ms)
		var tail_colour := colour
		tail_colour.a = 0.35
		var tail_rect := Rect2(Vector2(cx - radius * 0.3, head_y), Vector2(radius * 0.6, tail_y - head_y))
		draw_rect(tail_rect, tail_colour)

	var glow_colour := colour
	glow_colour.a = 0.35
	draw_circle(Vector2(cx, head_y), radius * 1.3, glow_colour)
	draw_circle(Vector2(cx, head_y), radius, colour)

	if _selected_notes.has(note):
		draw_arc(Vector2(cx, head_y), radius + 4.0, 0.0, TAU, 24, DesignTokens.COLOR_TEXT_PRIMARY, 2.0, true)


func _draw_drag_preview(col_w: float) -> void:
	var current := get_local_mouse_position()
	var y0 := minf(_drag_start_pos.y, current.y)
	var y1 := maxf(_drag_start_pos.y, current.y)
	var preview_colour := DesignTokens.COLOR_PINK if _tool_mode == Tool.SELECT else DesignTokens.COLOR_AMBER

	if _tool_mode == Tool.SELECT:
		var lane_b := _x_to_lane(current.x)
		var x0 := mini(_drag_lane, lane_b) * col_w
		var x1 := (maxi(_drag_lane, lane_b) + 1) * col_w
		draw_rect(Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0)), preview_colour, false, 2.0)
	else:
		var x := _drag_lane * col_w
		draw_rect(Rect2(Vector2(x, y0), Vector2(col_w, y1 - y0)), preview_colour, false, 2.0)
