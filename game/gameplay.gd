extends Control
## Stage 3 (M1b) gameplay scene -- supersedes Stage 2's game/play_field.gd
## (documented there as a disposable M1a proving ground). Loads whichever
## chart song_select.gd queued in PlaySession, drives a JudgeEngine with
## real Conductor/LaneInput events, and on completion hands the finished
## engine to PlaySession for the results screen.
##
## Visuals: the imported HUD, 1a "Classic centered" (docs/DESIGN_HANDOFF.md,
## Stage 6 handoff in docs/BUILD_PLAN.md) -- top HUD row (title/artist/
## difficulty), centered score, right-aligned accuracy/combo, a horizontal
## health bar, and an 8-lane playfield (game/playfield_view.gd) with
## falling notes, a pulsing judgment line, hit bursts, and judgment popups.
## This scene owns all state; playfield_view.gd is a pure display layer fed
## every frame, same split as editor/waveform_view.gd under editor_main.gd.
##
## Falls back to the Stage 2 fixture when run standalone (F6) with no
## PlaySession chart queued, e.g. during development.
const FALLBACK_CHART_PATH: String = "res://tests/fixtures/m1a_fixture.oct"
const RESULTS_SCENE: String = "res://game/results.tscn"

const LANE_COUNT: int = 8

## Health bar fill's max width in pixels -- the track is 640 wide, inset by
## 1px on each side in the .tscn (HealthBarTrack -> HealthBarBackground),
## so the fillable interior is 638px. Kept in sync with gameplay.tscn by
## hand, same convention as PlayfieldView's mockup-derived constants.
const HEALTH_FILL_MAX_WIDTH: float = 638.0

## Extra beats of metronome padding past the chart's last note, so the
## click track never cuts out mid-song.
const AUDIO_TAIL_BEATS: int = 4
const AUDIO_BEATS_PER_BAR: int = 4

@onready var _title_label: Label = %TitleLabel
@onready var _artist_label: Label = %ArtistLabel
@onready var _difficulty_pill_label: Label = %DifficultyPillLabel
@onready var _score_value_label: Label = %ScoreValueLabel
@onready var _accuracy_value_label: Label = %AccuracyValueLabel
@onready var _combo_value_label: Label = %ComboValueLabel
@onready var _health_fill: TextureRect = %HealthBarFill
@onready var _playfield: Control = %PlayfieldView
@onready var _reduced_flash_label: Label = %ReducedFlashLabel
@onready var _failed_label: Label = %FailedLabel
@onready var _quit_button: Button = %QuitButton

var _engine: JudgeEngine
var _chart: Chart
var _chart_end_ms: float = 0.0
var _finished: bool = false


func _ready() -> void:
	_reduced_flash_label.text = "REDUCED FLASH: %s" % ("ON" if _reduced_flash() else "OFF")
	_playfield.set_accessibility(_reduced_flash(), _reduced_motion())
	_quit_button.pressed.connect(_on_quit_pressed)

	_chart = PlaySession.take_pending_chart()
	if _chart == null:
		var chart_path := PlaySession.current_chart_path()
		if chart_path.is_empty():
			chart_path = FALLBACK_CHART_PATH
		_chart = OctIO.load_oct(chart_path)

	if _chart == null:
		push_error("gameplay: failed to load a chart")
		return

	_populate_song_info()

	_engine = JudgeEngine.new(_chart, Config.gameplay, Config.scoring, PlaySession.mods)
	_engine.judged.connect(_on_note_judged)
	_engine.combo_changed.connect(_on_combo_changed)
	_engine.health_changed.connect(_on_health_changed)
	_engine.song_failed.connect(_on_song_failed)

	_chart_end_ms = _compute_chart_end_ms()
	_playfield.set_chart(_chart.notes, Config.gameplay.window_good_ms)
	_refresh_hud()
	_update_health_bar(_engine.health)

	var pending_audio := PlaySession.take_pending_audio_stream()
	Conductor.play(pending_audio if pending_audio != null else _build_backing_track())


func _process(_delta: float) -> void:
	if _engine == null or _finished:
		return

	var song_ms := Conductor.song_time_ms()
	_engine.update(song_ms)
	_playfield.update_state(song_ms, _scroll_speed())

	if song_ms > _chart_end_ms:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if _engine == null or _finished:
		return
	var song_ms := Conductor.song_time_ms()
	for lane in LANE_COUNT:
		var action := LaneInput.binding_for(lane)
		if event.is_action_pressed(action):
			_engine.on_lane_press(lane, song_ms)
		elif event.is_action_released(action):
			_engine.on_lane_release(lane, song_ms)


func _compute_chart_end_ms() -> float:
	var latest := 0.0
	for note in _chart.notes:
		var note_end := float(note.end_time_ms if note.type == "hold" else note.time_ms)
		latest = maxf(latest, note_end)
	return latest + Config.gameplay.window_good_ms


func _build_backing_track() -> AudioStreamWAV:
	# Real audio import is Stage 4 scope -- every chart is currently played
	# against a metronome click track long enough to cover its last note,
	# at the BPM of the chart's first timing point (defaulting to
	# Metronome's own default if the chart has none).
	var bpm := Metronome.DEFAULT_BPM
	if not _chart.timing_points.is_empty():
		bpm = _chart.timing_points[0].bpm

	var beat_ms := Metronome.beat_interval_ms(bpm)
	var beats_needed := int(ceil(_chart_end_ms / beat_ms)) + AUDIO_TAIL_BEATS
	var bars_needed := int(ceil(float(beats_needed) / AUDIO_BEATS_PER_BAR))
	return Metronome.build(bpm, bars_needed, AUDIO_BEATS_PER_BAR)


func _finish() -> void:
	_finished = true
	Conductor.stop()
	PlaySession.last_engine = _engine
	SceneRouter.goto_scene_pushed(RESULTS_SCENE)


func _on_quit_pressed() -> void:
	Conductor.stop()
	SceneRouter.go_back()


func _populate_song_info() -> void:
	var meta := _chart.metadata
	_title_label.text = meta.title if not meta.title.is_empty() else "Untitled"
	_artist_label.text = meta.artist if not meta.artist.is_empty() else "Unknown artist"
	var diff_name := meta.difficulty_name.to_upper() if not meta.difficulty_name.is_empty() else "—"
	_difficulty_pill_label.text = "%s · %.1f★" % [diff_name, meta.star_rating]


## [param affects_combo] is true only for a discrete note event (a real
## head/tail press or release, or an auto/forfeited Miss) -- false for
## hold-tick credit and truncated-remaining-tick entries (game/judge_engine.gd's
## same-named internal flag, now threaded through the signal). Score/
## accuracy always refresh (ticks do affect those); the popup/burst are
## gated to discrete events only, so a held note doesn't spam a "PERFECT"
## popup every hold_tick_interval_ms.
func _on_note_judged(lane: int, kind: Judgment.Kind, _error_ms: float, affects_combo: bool) -> void:
	_refresh_hud()
	if not affects_combo:
		return
	_playfield.trigger_judgment_popup(kind)
	if kind != Judgment.Kind.MISS:
		_playfield.trigger_hit_burst(lane)


func _on_combo_changed(combo: int) -> void:
	_refresh_hud()
	if combo > 0 and not _reduced_motion():
		_pulse_combo_label()


func _on_health_changed(health: float) -> void:
	_update_health_bar(health)


func _on_song_failed() -> void:
	_failed_label.visible = true


func _refresh_hud() -> void:
	_score_value_label.text = "%d" % _engine.score
	_accuracy_value_label.text = "%.2f%%" % (_engine.accuracy() * 100.0)
	_combo_value_label.text = "%dx" % _engine.combo


func _update_health_bar(health: float) -> void:
	var fraction := clampf(health / Config.gameplay.health_start, 0.0, 1.0)
	_health_fill.size.x = HEALTH_FILL_MAX_WIDTH * fraction


## Brief scale pulse on a combo increase -- skipped under reduced motion.
func _pulse_combo_label() -> void:
	_combo_value_label.pivot_offset = _combo_value_label.size * 0.5
	var tween := create_tween()
	tween.tween_property(_combo_value_label, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(_combo_value_label, "scale", Vector2.ONE, 0.16)


func _scroll_speed() -> float:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.scroll_speed
	return 1.0


func _reduced_flash() -> bool:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.reduced_flash
	return false


func _reduced_motion() -> bool:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.reduced_motion
	return false


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
