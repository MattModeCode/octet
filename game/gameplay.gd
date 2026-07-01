extends Control
## Stage 3 (M1b) gameplay scene -- supersedes Stage 2's game/play_field.gd
## (documented there as a disposable M1a proving ground). Loads whichever
## chart song_select.gd queued in PlaySession, drives a JudgeEngine with
## real Conductor/LaneInput events exactly as play_field.gd proved, and on
## completion hands the finished engine to PlaySession for the results
## screen.
##
## Visuals are still deliberately minimal plain Control nodes, NOT the
## imported HUD (variant 2A) -- that import is blocked on the Claude
## Design MCP connection (docs/BUILD_PLAN.md Stage 3 handoff) and is left
## as a follow-up. This scene's Conductor/LaneInput/JudgeEngine wiring is
## the part that carries over unchanged once the real HUD replaces these
## labels.

## Falls back to the Stage 2 fixture when run standalone (F6) with no
## PlaySession chart queued, e.g. during development.
const FALLBACK_CHART_PATH: String = "res://tests/fixtures/m1a_fixture.oct"
const RESULTS_SCENE: String = "res://game/results.tscn"

## Cosmetic-only tuning (not shared config -- mirrors game/vertical_slice.gd
## and Stage 2's game/play_field.gd; these don't affect judgment).
const PIXELS_PER_MS: float = 0.6
const JUDGMENT_Y_FRACTION: float = 0.82
const LANE_COUNT: int = 8
const LANE_WIDTH: float = 160.0
const NOTE_HEIGHT: float = 40.0

## Extra beats of metronome padding past the chart's last note, so the
## click track never cuts out mid-song.
const AUDIO_TAIL_BEATS: int = 4
const AUDIO_BEATS_PER_BAR: int = 4

@onready var _background: ColorRect = %Background
@onready var _judgment_line: ColorRect = %JudgmentLine
@onready var _lanes_container: Control = %LanesContainer
@onready var _score_label: Label = %ScoreLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _health_label: Label = %HealthLabel
@onready var _grade_label: Label = %GradeLabel
@onready var _quit_button: Button = %QuitButton

var _engine: JudgeEngine
var _chart: Chart
## Each entry: {"note": ChartNote, "rect": ColorRect, "hide_after_ms": float}.
var _note_visuals: Array[Dictionary] = []
var _judgment_y: float = 0.0
var _chart_end_ms: float = 0.0
var _finished: bool = false


func _ready() -> void:
	_apply_colours()
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

	_engine = JudgeEngine.new(_chart, Config.gameplay, Config.scoring, PlaySession.mods)
	_engine.judged.connect(_on_engine_changed.unbind(3))
	_engine.combo_changed.connect(_on_engine_changed.unbind(1))
	_engine.health_changed.connect(_on_engine_changed.unbind(1))
	_engine.song_failed.connect(_on_song_failed)

	_chart_end_ms = _compute_chart_end_ms()
	_build_note_visuals()
	_update_hud()

	var pending_audio := PlaySession.take_pending_audio_stream()
	Conductor.play(pending_audio if pending_audio != null else _build_backing_track())


func _process(_delta: float) -> void:
	if _engine == null or _finished:
		return

	var song_ms := Conductor.song_time_ms()
	_engine.update(song_ms)

	_judgment_y = size.y * JUDGMENT_Y_FRACTION
	_judgment_line.position.y = _judgment_y
	_judgment_line.size.x = size.x

	_update_note_positions(song_ms)

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


func _build_note_visuals() -> void:
	for note in _chart.notes:
		var rect := ColorRect.new()
		rect.color = DesignTokens.lane_color(note.lane)
		rect.size = Vector2(LANE_WIDTH * 0.7, NOTE_HEIGHT)
		_lanes_container.add_child(rect)

		var is_hold := note.type == "hold"
		var target_ms := float(note.end_time_ms if is_hold else note.time_ms)
		_note_visuals.append({
			"note": note,
			"rect": rect,
			"hide_after_ms": target_ms + Config.gameplay.window_good_ms,
		})


## Positions (or hides) every note visual for the current song time. Hiding
## is purely time-based (past the note's -- or hold's tail's -- Good
## window), not tied to the engine's judged signal: by definition, once
## that time has passed the note has necessarily either been hit or
## auto-Missed, so it's safe to hide without correlating back to a
## specific judgment.
func _update_note_positions(song_ms: float) -> void:
	var scroll_speed := _scroll_speed()
	for entry in _note_visuals:
		var note: ChartNote = entry.note
		var rect: ColorRect = entry.rect

		if song_ms > entry.hide_after_ms:
			rect.visible = false
			continue

		var lane_x := note.lane * LANE_WIDTH
		if note.type == "hold":
			var head_y := _judgment_y - (float(note.time_ms) - song_ms) * PIXELS_PER_MS * scroll_speed
			var tail_y := _judgment_y - (float(note.end_time_ms) - song_ms) * PIXELS_PER_MS * scroll_speed
			var top := minf(head_y, tail_y)
			var height := maxf(NOTE_HEIGHT, absf(tail_y - head_y))
			rect.position = Vector2(lane_x + LANE_WIDTH * 0.15, top - NOTE_HEIGHT * 0.5)
			rect.size = Vector2(LANE_WIDTH * 0.7, height)
		else:
			var y := _judgment_y - (float(note.time_ms) - song_ms) * PIXELS_PER_MS * scroll_speed - NOTE_HEIGHT * 0.5
			rect.position = Vector2(lane_x + LANE_WIDTH * 0.15, y)
			rect.size = Vector2(LANE_WIDTH * 0.7, NOTE_HEIGHT)


func _on_engine_changed() -> void:
	_update_hud()


func _on_song_failed() -> void:
	_grade_label.text = "FAILED"


func _update_hud() -> void:
	_score_label.text = "Score: %d" % _engine.score
	_combo_label.text = "Combo: %d  (x%.0f)" % [_engine.combo, _engine.current_multiplier()]
	_accuracy_label.text = "Accuracy: %.2f%%" % (_engine.accuracy() * 100.0)
	_health_label.text = "Health: %.0f" % _engine.health
	_grade_label.text = "Grade: %s" % _engine.grade()


func _scroll_speed() -> float:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.scroll_speed
	return 1.0


func _apply_colours() -> void:
	_background.color = DesignTokens.COLOR_INK
	_judgment_line.color = DesignTokens.COLOR_JUDGMENT_LINE


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
