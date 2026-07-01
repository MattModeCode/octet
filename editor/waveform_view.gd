extends Control
## Renders the horizontal waveform + beat-grid overlay + playhead
## (PROJECT_BRIEF §3.3): the peaks (AudioImport.build_waveform_peaks) as
## vertical bars, beat lines (BeatGrid.beat_times_ms) as thin verticals,
## and a playhead line at the current song time. Pure display -- editor
## editor_main.gd owns all the state and just calls set_data()/set_playhead().

var _peaks: PackedFloat32Array = PackedFloat32Array()
var _duration_ms: float = 1.0
var _beat_times_ms: Array[float] = []
var _playhead_ms: float = 0.0


func set_data(peaks: PackedFloat32Array, duration_ms: float, beat_times: Array[float]) -> void:
	_peaks = peaks
	_duration_ms = maxf(1.0, duration_ms)
	_beat_times_ms = beat_times
	queue_redraw()


func set_playhead(time_ms: float) -> void:
	_playhead_ms = time_ms
	queue_redraw()


## Converts a local x pixel coordinate on this control back to a song time
## in ms -- used by editor_main.gd to turn a click/drag into a seek.
func x_to_time_ms(x: float) -> float:
	return clampf(x / maxf(1.0, size.x), 0.0, 1.0) * _duration_ms


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DesignTokens.COLOR_SURFACE)

	if not _peaks.is_empty():
		var bar_width := size.x / _peaks.size()
		var mid_y := size.y * 0.5
		for i in _peaks.size():
			var half_height := _peaks[i] * mid_y
			if half_height < 1.0:
				continue
			var x := i * bar_width
			draw_line(Vector2(x, mid_y - half_height), Vector2(x, mid_y + half_height), DesignTokens.COLOR_TEXT_SECONDARY, bar_width)

	for beat_ms in _beat_times_ms:
		var x := (beat_ms / _duration_ms) * size.x
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), DesignTokens.COLOR_HAIRLINE, 1.0)

	var playhead_x := (_playhead_ms / _duration_ms) * size.x
	draw_line(Vector2(playhead_x, 0.0), Vector2(playhead_x, size.y), DesignTokens.COLOR_PINK, 2.0)
