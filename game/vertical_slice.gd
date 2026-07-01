extends Control
## Stage 1 (M0) vertical slice: one lane, one falling note, one judgment
## line, one judgment from a real Conductor time delta. Proves the
## conductor clock end to end (PROJECT_BRIEF §6.2) before Stage 2 builds
## all eight lanes and full note/scoring systems on top of it.
##
## Visuals here are deliberately minimal and cosmetic -- the thing under
## test is the timing math, not the art. Scroll speed changes how far
## ahead the note is visible; it must never affect judgment, which is
## computed purely from Conductor.song_time_ms() vs. the note's target ms.

## Which of the eight lanes this slice exercises (arbitrary for M0 -- lane 0
## is A / left pinky / electric orchid per DESIGN_BRIEF).
const LANE_INDEX: int = 0

## Cosmetic-only tuning for this proving-ground scene (not shared config,
## per CLAUDE.md tunables rule -- these don't affect judgment, only how the
## single note is drawn/animated). Mirrors the rationale in ui/main.gd's
## pulse constants.
const PIXELS_PER_MS: float = 0.6
const JUDGMENT_Y_FRACTION: float = 0.82
const NOTE_SIZE: Vector2 = Vector2(120, 40)

## The note's target beat on the metronome click track (2 s in at 120 BPM),
## giving the note time to scroll into view before it's due.
const NOTE_TARGET_BEAT: int = 4

## Extra time (ms) past the "good" window before an unhit note is declared
## a Miss and judging stops -- keeps a whiffed note from waiting forever.
const MISS_GRACE_MS: float = 250.0

## Ignore taps further than this from the target so pressing early doesn't
## "reach" for a note that isn't due yet.
const MAX_HIT_DETECTION_MS: float = 400.0

@onready var _background: ColorRect = %Background
@onready var _judgment_line: ColorRect = %JudgmentLine
@onready var _note: ColorRect = %Note
@onready var _judgment_label: Label = %JudgmentLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _help_label: Label = %HelpLabel

var _note_target_ms: float
var _judged: bool = false
var _judgment_y: float
var _lane_action: String


func _ready() -> void:
	_apply_colours()
	_lane_action = LaneInput.binding_for(LANE_INDEX)
	_note_target_ms = Metronome.beat_target_ms(NOTE_TARGET_BEAT)
	_help_label.text = "Lane key: %s -- hit the note on the beat" % LaneInput.current_key_string(LANE_INDEX)

	Conductor.play(Metronome.build())


func _process(_delta: float) -> void:
	_judgment_y = size.y * JUDGMENT_Y_FRACTION
	_judgment_line.position.y = _judgment_y
	_judgment_line.size.x = size.x

	if _judged:
		return

	var song_ms := Conductor.song_time_ms()
	var remaining_ms := _note_target_ms - song_ms
	_note.position = Vector2(
		(size.x - NOTE_SIZE.x) * 0.5,
		_judgment_y - remaining_ms * PIXELS_PER_MS * _scroll_speed() - NOTE_SIZE.y * 0.5
	)

	if remaining_ms < -(Config.gameplay.window_good_ms + MISS_GRACE_MS):
		_apply_judgment("Miss", remaining_ms)


func _unhandled_input(event: InputEvent) -> void:
	if _judged:
		return
	if event.is_action_pressed(_lane_action):
		var tap_ms := Conductor.song_time_ms()
		var err := Conductor.judgment_error_ms(tap_ms, _note_target_ms, Conductor.input_offset_ms())
		if absf(err) > MAX_HIT_DETECTION_MS:
			return # Too far from the note to plausibly be aimed at it.

		var gameplay := Config.gameplay
		var judgment: String
		if absf(err) <= gameplay.window_perfect_ms:
			judgment = "Perfect"
		elif absf(err) <= gameplay.window_great_ms:
			judgment = "Great"
		elif absf(err) <= gameplay.window_good_ms:
			judgment = "Good"
		else:
			judgment = "Miss"
		_apply_judgment(judgment, err)


func _apply_judgment(judgment: String, error_ms: float) -> void:
	_judged = true
	_judgment_label.text = judgment
	_judgment_label.add_theme_color_override("font_color", _judgment_color(judgment))
	if judgment == "Miss":
		_error_label.text = "unhit / out of window"
	else:
		var direction := "late" if error_ms > 0.0 else "early"
		_error_label.text = "%.1f ms %s" % [absf(error_ms), direction]
	_note.visible = false


func _judgment_color(judgment: String) -> Color:
	match judgment:
		"Perfect":
			return DesignTokens.COLOR_PERFECT_FLASH
		"Great":
			return DesignTokens.COLOR_AMBER
		"Good":
			return DesignTokens.COLOR_TEXT_PRIMARY
		_:
			return DesignTokens.COLOR_MISS


func _scroll_speed() -> float:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.scroll_speed
	return 1.0


func _apply_colours() -> void:
	_background.color = DesignTokens.COLOR_INK
	_judgment_line.color = DesignTokens.COLOR_JUDGMENT_LINE
	_note.color = DesignTokens.lane_color(LANE_INDEX)


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
