extends Control
## Renders the horizontal waveform + beat-grid overlay + playhead
## (PROJECT_BRIEF §3.3, matching the imported 2A mockup's look): the peak
## envelope (AudioImport.build_waveform_peaks) as a smooth polyline rather
## than discrete bars, beat lines (BeatGrid.beat_times_ms) as thin
## verticals (every 4th slightly brighter, matching the mockup's grid),
## and a soft-glow playhead (layered lines of decreasing alpha, since
## Control 2D drawing has no native glow/shadow filter). Pure display --
## editor_main.gd owns all the state and just calls set_data()/set_playhead().

const BEAT_GRID_MAJOR_EVERY: int = 4
const PLAYHEAD_GLOW_LAYERS: int = 4

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
	_draw_beat_grid()
	_draw_waveform()
	_draw_playhead()


func _draw_beat_grid() -> void:
	for i in _beat_times_ms.size():
		var x := (_beat_times_ms[i] / _duration_ms) * size.x
		var is_major := i % BEAT_GRID_MAJOR_EVERY == 0
		var colour := DesignTokens.COLOR_HAIRLINE
		colour.a = 0.9 if is_major else 0.4
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), colour, 1.0 if is_major else 1.0)


## Traces the peak envelope as a smooth polyline (upper + mirrored lower)
## rather than discrete vertical bars -- closer to the imported mockup's
## continuous waveform look.
func _draw_waveform() -> void:
	if _peaks.is_empty():
		return

	var mid_y := size.y * 0.5
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	upper.resize(_peaks.size())
	lower.resize(_peaks.size())

	for i in _peaks.size():
		var x := (float(i) / _peaks.size()) * size.x
		var half_height := _peaks[i] * mid_y
		upper[i] = Vector2(x, mid_y - half_height)
		lower[i] = Vector2(x, mid_y + half_height)

	var colour := DesignTokens.COLOR_PINK
	colour.a = 0.85
	draw_polyline(upper, colour, 1.5, true)
	draw_polyline(lower, colour, 1.5, true)


## Soft-glow approximation: several progressively wider, more transparent
## lines behind a crisp center line -- there's no native shadow/glow
## filter for 2D immediate-mode drawing, so this fakes it cheaply.
func _draw_playhead() -> void:
	var playhead_x := (_playhead_ms / _duration_ms) * size.x
	var glow_colour := DesignTokens.COLOR_PERFECT_FLASH

	for layer in range(PLAYHEAD_GLOW_LAYERS, 0, -1):
		var layer_colour := glow_colour
		layer_colour.a = 0.12
		draw_line(Vector2(playhead_x, 0.0), Vector2(playhead_x, size.y), layer_colour, 2.0 + layer * 3.0)

	draw_line(Vector2(playhead_x, 0.0), Vector2(playhead_x, size.y), glow_colour, 2.0)
