extends Control
## Stage 4 (M2a) editor shell. The visual layout here is deliberately plain
## Control nodes, NOT the imported 1A mockup ("Octet - Editor.dc.html") --
## that import is blocked on the Claude Design MCP connection (same
## blocker recorded against Stage 3's HUD; see docs/BUILD_PLAN.md Stage 4
## handoff). This scene covers Stage 4's functional checklist only: audio
## import, waveform + playhead, manual BPM/offset + beat-grid overlay,
## timing points, and scrub/variable-rate transport. Note placement (§3.5),
## QOL, and save/export are Stage 5 scope.

const WAVEFORM_BUCKET_COUNT: int = 800
const RATE_OPTIONS: Array[float] = [0.25, 0.5, 0.75, 1.0]

@onready var _background: ColorRect = %Background
@onready var _waveform_view: Control = %WaveformView
@onready var _import_button: Button = %ImportButton
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _play_button: Button = %PlayButton
@onready var _stop_button: Button = %StopButton
@onready var _rate_option: OptionButton = %RateOption
@onready var _bpm_spinbox: SpinBox = %BpmSpinBox
@onready var _offset_spinbox: SpinBox = %OffsetSpinBox
@onready var _timing_points_list: VBoxContainer = %TimingPointsList
@onready var _add_timing_point_button: Button = %AddTimingPointButton
@onready var _time_label: Label = %TimeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton

var _chart: Chart = Chart.new()
var _stream: AudioStream = null
var _peaks: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_apply_colours()
	_populate_rate_options()

	_import_button.pressed.connect(_on_import_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)
	_play_button.pressed.connect(_on_play_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_rate_option.item_selected.connect(_on_rate_selected)
	_bpm_spinbox.value_changed.connect(_on_bpm_changed)
	_offset_spinbox.value_changed.connect(_on_offset_changed)
	_add_timing_point_button.pressed.connect(_on_add_timing_point_pressed)
	_waveform_view.gui_input.connect(_on_waveform_gui_input)
	_back_button.pressed.connect(_on_back_pressed)

	_refresh_timing_points_ui()
	_update_bpm_offset_fields()
	_status_label.text = "Import a song to begin (MP3, OGG, or WAV)."


func _process(_delta: float) -> void:
	if _stream == null:
		return
	var song_ms := Conductor.song_time_ms()
	_waveform_view.call("set_playhead", song_ms)
	_time_label.text = "%.0f ms" % song_ms
	_play_button.text = "Pause" if Conductor.is_playing() else "Play"


func _apply_colours() -> void:
	_background.color = DesignTokens.COLOR_INK


func _populate_rate_options() -> void:
	for rate in RATE_OPTIONS:
		_rate_option.add_item("%.2fx" % rate)
	_rate_option.select(RATE_OPTIONS.find(1.0))


func _on_import_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_file_selected(path: String) -> void:
	var stream := AudioImport.load_audio_file(path)
	if stream == null:
		_status_label.text = "Failed to import %s -- see error log." % path.get_file()
		return

	_stream = stream
	_chart.audio.filename = path.get_file()
	_chart.audio.duration_ms = int(round(stream.get_length() * 1000.0))

	if _chart.timing_points.is_empty():
		var tp := TimingPoint.new()
		tp.time_ms = 0
		tp.bpm = 120.0
		tp.meter = 4
		_chart.timing_points = [tp]

	_status_label.text = "Decoding waveform for %s..." % path.get_file()
	_peaks = AudioImport.build_waveform_peaks(stream, WAVEFORM_BUCKET_COUNT)

	Conductor.play(stream)
	Conductor.pause()

	_refresh_waveform()
	_refresh_timing_points_ui()
	_update_bpm_offset_fields()
	_status_label.text = "Imported %s (%.1fs)." % [path.get_file(), stream.get_length()]


func _on_play_pressed() -> void:
	if _stream == null:
		return
	if Conductor.is_playing():
		Conductor.pause()
	else:
		Conductor.resume()


func _on_stop_pressed() -> void:
	if _stream == null:
		return
	Conductor.seek_ms(0.0)
	if Conductor.is_playing():
		Conductor.pause()
	_waveform_view.call("set_playhead", 0.0)


func _on_rate_selected(index: int) -> void:
	Conductor.set_playback_rate(RATE_OPTIONS[index])


func _on_waveform_gui_input(event: InputEvent) -> void:
	if _stream == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var time_ms: float = _waveform_view.call("x_to_time_ms", event.position.x)
		Conductor.seek_ms(time_ms)
		_waveform_view.call("set_playhead", time_ms)


func _on_bpm_changed(value: float) -> void:
	if _chart.timing_points.is_empty():
		return
	_chart.timing_points[0].bpm = value
	_refresh_waveform()


func _on_offset_changed(value: float) -> void:
	if _chart.timing_points.is_empty():
		return
	_chart.timing_points[0].time_ms = int(value)
	_refresh_waveform()


func _on_add_timing_point_pressed() -> void:
	if _stream == null or _chart.timing_points.is_empty():
		return
	var tp := TimingPoint.new()
	tp.time_ms = int(round(Conductor.song_time_ms()))
	tp.bpm = _chart.timing_points[0].bpm
	tp.meter = _chart.timing_points[0].meter
	_insert_timing_point_sorted(tp)
	_refresh_timing_points_ui()
	_refresh_waveform()


func _insert_timing_point_sorted(tp: TimingPoint) -> void:
	var points: Array[TimingPoint] = _chart.timing_points.duplicate()
	points.append(tp)
	points.sort_custom(func(a: TimingPoint, b: TimingPoint) -> bool: return a.time_ms < b.time_ms)
	_chart.timing_points = points


func _on_remove_timing_point_pressed(index: int) -> void:
	if index == 0 or index >= _chart.timing_points.size():
		return # The first timing point defines the song offset -- can't remove it.
	var points: Array[TimingPoint] = _chart.timing_points.duplicate()
	points.remove_at(index)
	_chart.timing_points = points
	_refresh_timing_points_ui()
	_refresh_waveform()


func _refresh_waveform() -> void:
	var beats := BeatGrid.beat_times_ms(_chart.timing_points, _chart.audio.duration_ms)
	_waveform_view.call("set_data", _peaks, _chart.audio.duration_ms, beats)


func _update_bpm_offset_fields() -> void:
	if _chart.timing_points.is_empty():
		return
	_bpm_spinbox.set_value_no_signal(_chart.timing_points[0].bpm)
	_offset_spinbox.set_value_no_signal(_chart.timing_points[0].time_ms)


func _refresh_timing_points_ui() -> void:
	for child in _timing_points_list.get_children():
		child.queue_free()

	for i in _chart.timing_points.size():
		var tp := _chart.timing_points[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = "%dms — %.1f BPM — %d/4" % [tp.time_ms, tp.bpm, tp.meter]
		label.custom_minimum_size = Vector2(260, 0)
		row.add_child(label)

		if i > 0:
			var remove_button := Button.new()
			remove_button.text = "Remove"
			remove_button.pressed.connect(_on_remove_timing_point_pressed.bind(i))
			row.add_child(remove_button)

		_timing_points_list.add_child(row)


func _on_back_pressed() -> void:
	Conductor.stop()
	SceneRouter.go_back()
