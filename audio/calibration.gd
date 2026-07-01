extends Control
## Calibration screen (PROJECT_BRIEF §2.8): a tap-to-the-beat routine
## against a steady metronome (audio/metronome.gd), averaging the measured
## error into a stored calibration offset. Lives under audio/ per
## PROJECT_BRIEF's own folder map ("/audio # conductor, calibration,
## analysis bindings").
##
## A single tap test can't separate audio-latency bias from input-latency
## bias -- they're confounded into one measured number. This screen
## attributes the whole measured average to input_offset_ms and leaves
## audio_offset_ms untouched (0 by default), which is an honest, documented
## simplification consistent with Stage 1's Conductor sign convention
## (audio/conductor.gd): both offsets are additive, "positive = shift the
## corresponding clock later". If the average measured tap lands late
## (positive), the stored input_offset_ms must be the *negative* of that
## average to cancel it -- shifting future tap times earlier before they're
## compared to a note's target time.

## Calibration tempo and length. Kept here (not shared config) -- these are
## specific to this screen's own routine, not gameplay tuning.
const BPM: float = Metronome.DEFAULT_BPM
const TOTAL_BEATS: int = 32
const BEATS_PER_BAR: int = 4
## First few beats are warmup -- gives the player time to lock into the
## tempo before any tap is recorded.
const WARMUP_BEATS: int = 4
## Godot's built-in "accept" action (Space/Enter by default) -- reused
## rather than adding a dedicated InputMap action just for this screen.
const TAP_ACTION: String = "ui_accept"

@onready var _background: ColorRect = %Background
@onready var _pulse_indicator: ColorRect = %PulseIndicator
@onready var _status_label: Label = %StatusLabel
@onready var _result_label: Label = %ResultLabel
@onready var _recalibrate_button: Button = %RecalibrateButton
@onready var _done_button: Button = %DoneButton

var _beat_interval_ms: float = 0.0
var _errors: Array[float] = []
var _running: bool = false
var _last_flashed_beat: int = -1


func _ready() -> void:
	_background.color = DesignTokens.COLOR_INK
	_pulse_indicator.color = DesignTokens.COLOR_PINK
	_beat_interval_ms = Metronome.beat_interval_ms(BPM)

	_recalibrate_button.pressed.connect(_start_routine)
	_done_button.pressed.connect(_on_done_pressed)

	_start_routine()


func _start_routine() -> void:
	_errors.clear()
	_running = true
	_last_flashed_beat = -1
	_result_label.text = ""
	_status_label.text = "Tap along with the beat (Space/Enter)..."
	var bars := int(ceil(float(TOTAL_BEATS) / BEATS_PER_BAR))
	Conductor.play(Metronome.build(BPM, bars, BEATS_PER_BAR))


func _process(_delta: float) -> void:
	if not _running:
		return

	var song_ms := Conductor.song_time_ms()
	var beat_index := int(roundf(song_ms / _beat_interval_ms))
	if beat_index != _last_flashed_beat:
		_last_flashed_beat = beat_index
		_flash_pulse()
		if beat_index >= TOTAL_BEATS:
			_finish_routine()


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event.is_action_pressed(TAP_ACTION):
		var song_ms := Conductor.song_time_ms()
		var nearest_beat := roundf(song_ms / _beat_interval_ms)
		if nearest_beat < WARMUP_BEATS:
			return
		var target_ms := nearest_beat * _beat_interval_ms
		_errors.append(song_ms - target_ms)
		_status_label.text = "Recorded %d taps..." % _errors.size()


func _finish_routine() -> void:
	_running = false
	Conductor.stop()

	if _errors.is_empty():
		_status_label.text = "No taps recorded -- press Recalibrate to try again."
		return

	var avg_error := 0.0
	for error in _errors:
		avg_error += error
	avg_error /= _errors.size()

	var input_offset_ms := -avg_error
	SettingsStore.settings.input_offset_ms = input_offset_ms
	SettingsStore.save()

	var direction := "late" if avg_error > 0.0 else "early"
	_status_label.text = "Calibration complete (%d taps)." % _errors.size()
	_result_label.text = "Input offset stored: %.1f ms  (average measured error: %.1f ms %s)" % [
		input_offset_ms, absf(avg_error), direction,
	]


func _flash_pulse() -> void:
	_pulse_indicator.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_pulse_indicator, "modulate:a", 0.2, 0.15)


func _on_done_pressed() -> void:
	Conductor.stop()
	SceneRouter.go_back()
