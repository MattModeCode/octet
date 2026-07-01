extends Control
## Note timeline (PROJECT_BRIEF §3.5): eight lanes synced to the same time
## axis as the waveform above it. Simplified to eight stacked horizontal
## rows sharing the waveform's x-axis-as-time convention, rather than a
## scrolling vertical piano-roll matching the gameplay fall direction --
## a deliberate M2b simplification (documented in docs/BUILD_PLAN.md)
## since the editor shell's final layout is blocked on the 1A mockup
## import anyway; this keeps the interaction model simple and testable.
##
## Pure display + input capture -- like waveform_view.gd, all actual chart
## mutation happens in editor_main.gd via editor/note_editor.gd, keeping
## undo/redo recording centralized there. This view only emits signals for
## what the user is asking to do.
##
## Interaction: an explicit tool mode (Tap / Hold / Select -- the real
## note-tool palette PROJECT_BRIEF §3.5 asked for, replacing the Stage 5
## modifier-key stand-in now that editor_main.gd's tool rail sets this
## directly) decides what a click/drag does. Right-click always deletes
## the note under the cursor regardless of tool. A free-place toggle
## (§3.5 "free-place (snap off) for off-grid notes") skips snapping when on.

signal tap_place_requested(lane: int, time_ms: int)
signal hold_place_requested(lane: int, start_ms: int, end_ms: int)
signal note_delete_requested(note: ChartNote)
signal box_select_requested(start_ms: float, end_ms: float, lane_min: int, lane_max: int)

enum Tool { TAP, HOLD, SELECT }

const LANE_COUNT: int = 8
## Minimum drag distance (ms) a Hold-tool drag must cover before it places
## a hold rather than being collapsed to a minimal-length hold at the
## drag's start -- keeps a near-zero-length accidental drag sane.
const MIN_HOLD_LENGTH_MS: float = 30.0
## Mouse tolerance (pixels) for hit-testing an existing note on right-click.
const HIT_TOLERANCE_PX: float = 10.0

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


func _lane_height() -> float:
	return size.y / LANE_COUNT


func _time_to_x(time_ms: float) -> float:
	return (time_ms / _duration_ms) * size.x


func _x_to_time(x: float) -> float:
	return clampf(x / maxf(1.0, size.x), 0.0, 1.0) * _duration_ms


func _y_to_lane(y: float) -> int:
	return clampi(int(y / _lane_height()), 0, LANE_COUNT - 1)


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
				_drag_lane = _y_to_lane(mb.position.y)
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
	var start_time := _x_to_time(_drag_start_pos.x)
	var end_time := _x_to_time(end_pos.x)

	match _tool_mode:
		Tool.SELECT:
			var lane_b := _y_to_lane(end_pos.y)
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
	var lane := _y_to_lane(pos.y)
	var time_ms := _x_to_time(pos.x)
	var tolerance_ms := (_duration_ms / maxf(1.0, size.x)) * HIT_TOLERANCE_PX
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
	var lane_h := _lane_height()

	for lane in LANE_COUNT:
		var y := lane * lane_h
		var row_color := DesignTokens.COLOR_SURFACE if lane % 2 == 0 else DesignTokens.COLOR_SURFACE_RAISED
		draw_rect(Rect2(Vector2(0, y), Vector2(size.x, lane_h)), row_color)

	for beat_ms in _beat_times_ms:
		var x := _time_to_x(beat_ms)
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), DesignTokens.COLOR_HAIRLINE, 1.0)

	for note in _notes:
		var y := note.lane * lane_h
		var colour := DesignTokens.lane_color(note.lane)
		var x0: float
		var x1: float
		if note.type == "hold":
			x0 = _time_to_x(note.time_ms)
			x1 = _time_to_x(note.end_time_ms)
			draw_rect(Rect2(Vector2(x0, y + 2), Vector2(maxf(2.0, x1 - x0), lane_h - 4)), colour)
		else:
			x0 = _time_to_x(note.time_ms) - 3
			x1 = x0 + 6
			draw_rect(Rect2(Vector2(x0, y + 2), Vector2(6, lane_h - 4)), colour)

		if _selected_notes.has(note):
			draw_rect(Rect2(Vector2(x0 - 3, y), Vector2(x1 - x0 + 6, lane_h)), DesignTokens.COLOR_TEXT_PRIMARY, false, 2.0)

	if _dragging:
		var current := get_local_mouse_position()
		var y := _drag_lane * lane_h
		var x0 := minf(_drag_start_pos.x, current.x)
		var x1 := maxf(_drag_start_pos.x, current.x)
		var preview_colour := DesignTokens.COLOR_PINK if _tool_mode == Tool.SELECT else DesignTokens.COLOR_AMBER
		draw_rect(Rect2(Vector2(x0, y), Vector2(x1 - x0, lane_h)), preview_colour, false, 2.0)

	var playhead_x := _time_to_x(_playhead_ms)
	draw_line(Vector2(playhead_x, 0.0), Vector2(playhead_x, size.y), DesignTokens.COLOR_PINK, 2.0)
