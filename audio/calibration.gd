extends Control
## Calibration screen, rebuilt to match "Octet - Calibration.dc.html"
## (Claude Design MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per
## CLAUDE.md's design-fidelity rule (PROJECT_BRIEF §2.8): a circular
## metronome visual, a beat counter + progress pips, and three offset
## readout cards.
##
## Calibration logic is unchanged from the Stage 3 version -- still a tap-
## to-the-beat routine against a steady metronome (audio/metronome.gd),
## averaging the measured error into a stored calibration offset.
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
## compared to a note's target time. The mockup's three offset cards
## (AUDIO/INPUT/TOTAL) are shown honestly against this model: AUDIO reflects
## whatever SettingsStore.settings.audio_offset_ms already holds (this
## screen never writes it), INPUT is what this routine measures and writes,
## TOTAL is their sum -- the actual combined value Conductor applies.

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

const PIP_COUNT: int = 8
const PIP_SIZE := Vector2(34, 8)

const GLOW_MIN_SCALE := 1.0
const GLOW_MAX_SCALE := 1.35
const GLOW_MIN_ALPHA := 0.15
const GLOW_MAX_ALPHA := 0.55
const FLASH_DURATION_SEC := 0.18

@onready var _subtitle_label: RichTextLabel = %SubtitleLabel
@onready var _top_tick: ColorRect = %TopTick
@onready var _glow_pulse: Panel = %GlowPulse
@onready var _bpm_label: Label = %BpmLabel
@onready var _beat_label: Label = %BeatLabel
@onready var _pips_row: HBoxContainer = %PipsRow
@onready var _status_label: Label = %StatusLabel
@onready var _audio_value: Label = %AudioValue
@onready var _input_value: Label = %InputValue
@onready var _total_value: Label = %TotalValue
@onready var _recalibrate_button: Button = %RecalibrateButton
@onready var _done_button: Button = %DoneButton

var _beat_interval_ms: float = 0.0
var _errors: Array[float] = []
var _running: bool = false
var _last_flashed_beat: int = -1
var _pips: Array[Panel] = []
var _pip_style_filled: StyleBoxFlat
var _pip_style_empty: StyleBoxFlat


func _ready() -> void:
	_pip_style_filled = _build_pip_style(DesignTokens.COLOR_PINK)
	_pip_style_empty = _build_pip_style(DesignTokens.COLOR_HAIRLINE)
	_subtitle_label.text = "[center]Tap [color=#FFC93C][b]Space[/b][/color] in time with the beat. We'll measure your audio and input offset.[/center]"
	_bpm_label.text = "%d BPM" % roundi(BPM)
	_beat_interval_ms = Metronome.beat_interval_ms(BPM)
	_build_pips()
	_refresh_offset_cards()

	_recalibrate_button.pressed.connect(_start_routine)
	_done_button.pressed.connect(_on_done_pressed)

	_start_routine()


func _build_pip_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func _build_pips() -> void:
	for child in _pips_row.get_children():
		child.queue_free()
	_pips.clear()
	for i in PIP_COUNT:
		var pip := Panel.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.add_theme_stylebox_override("panel", _pip_style_empty)
		_pips_row.add_child(pip)
		_pips.append(pip)


func _start_routine() -> void:
	_errors.clear()
	_running = true
	_last_flashed_beat = -1
	_status_label.text = "Tap along with the beat..."
	_beat_label.text = "BEAT 0 OF %d" % TOTAL_BEATS
	_update_pips(0)
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
		_beat_label.text = "BEAT %d OF %d" % [mini(beat_index, TOTAL_BEATS), TOTAL_BEATS]
		_update_pips(beat_index)
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
	_status_label.text = "Calibration complete (%d taps, average measured error %.1f ms %s)." % [
		_errors.size(), absf(avg_error), direction,
	]
	_refresh_offset_cards()


## Reads whatever audio_offset_ms already holds (this routine never writes
## it -- see the class-level design-decision comment), the just-measured
## input_offset_ms, and their sum -- the real combined value Conductor uses.
func _refresh_offset_cards() -> void:
	var audio_offset := SettingsStore.settings.audio_offset_ms
	var input_offset := SettingsStore.settings.input_offset_ms
	_audio_value.text = "%+.0f ms" % audio_offset
	_input_value.text = "%+.0f ms" % input_offset
	_total_value.text = "%+.0f ms" % (audio_offset + input_offset)


func _update_pips(beat_index: int) -> void:
	var filled_pips := int(floor((float(beat_index) / TOTAL_BEATS) * PIP_COUNT))
	for i in _pips.size():
		_pips[i].add_theme_stylebox_override("panel", _pip_style_filled if i < filled_pips else _pip_style_empty)


## Real beat-synced pulse (not the mockup's fixed-period CSS loop -- see the
## fidelity note in calibration.tscn) driving the top ring tick and the
## centre glow together, same "flash and fade" trick as the old flat pulse
## indicator this replaced.
func _flash_pulse() -> void:
	_top_tick.modulate.a = 1.0
	_glow_pulse.scale = Vector2(GLOW_MIN_SCALE, GLOW_MIN_SCALE)
	_glow_pulse.modulate.a = GLOW_MAX_ALPHA

	var tick_tween := create_tween()
	tick_tween.tween_property(_top_tick, "modulate:a", 0.25, FLASH_DURATION_SEC)

	var glow_tween := create_tween()
	glow_tween.set_parallel(true)
	glow_tween.tween_property(_glow_pulse, "scale", Vector2(GLOW_MAX_SCALE, GLOW_MAX_SCALE), FLASH_DURATION_SEC)
	glow_tween.tween_property(_glow_pulse, "modulate:a", GLOW_MIN_ALPHA, FLASH_DURATION_SEC)


func _on_done_pressed() -> void:
	Conductor.stop()
	SceneRouter.go_back()
