extends Control
## Results screen (PROJECT_BRIEF §2.7): grade, final accuracy, max combo,
## score, per-judgment breakdown, a hit-error histogram (early/late), mean
## offset, and retry/next/back actions. Reads PlaySession.last_engine --
## the JudgeEngine that just finished in game/gameplay.gd -- directly,
## rather than re-deriving any of its state.
##
## Online score submission ("if online and ranked, submit score and show
## placement") is Stage 7 (M4) scope -- Net is still a stub that always
## reports offline, so there is nothing to submit yet.

const SONG_SELECT_SCENE: String = "res://game/song_select.tscn"
const GAMEPLAY_SCENE: String = "res://game/gameplay.tscn"

const HISTOGRAM_BUCKET_COUNT: int = 9
const HISTOGRAM_BAR_WIDTH: float = 32.0
const HISTOGRAM_MAX_HEIGHT: float = 160.0

@onready var _background: ColorRect = %Background
@onready var _grade_label: Label = %GradeLabel
@onready var _accuracy_label: Label = %AccuracyLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _breakdown_label: Label = %BreakdownLabel
@onready var _badges_label: Label = %BadgesLabel
@onready var _offset_label: Label = %OffsetLabel
@onready var _histogram_container: HBoxContainer = %HistogramContainer
@onready var _retry_button: Button = %RetryButton
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton

var _engine: JudgeEngine


func _ready() -> void:
	_background.color = DesignTokens.COLOR_INK

	_engine = PlaySession.last_engine
	if _engine == null:
		_grade_label.text = "No results"
		_retry_button.disabled = true
		_next_button.disabled = true
		_back_button.pressed.connect(_on_back_pressed)
		return

	_populate()
	_retry_button.pressed.connect(_on_retry_pressed)
	_next_button.pressed.connect(_on_next_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _populate() -> void:
	_grade_label.text = _engine.grade()
	_grade_label.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER)
	_accuracy_label.text = "Accuracy: %.2f%%" % (_engine.accuracy() * 100.0)
	_combo_label.text = "Max combo: %d" % _engine.max_combo
	_score_label.text = "Score: %d" % _engine.score

	var counts := _engine.judgment_counts
	_breakdown_label.text = "Perfect: %d   Great: %d   Good: %d   Miss: %d" % [
		int(counts.get(Judgment.Kind.PERFECT, 0)),
		int(counts.get(Judgment.Kind.GREAT, 0)),
		int(counts.get(Judgment.Kind.GOOD, 0)),
		int(counts.get(Judgment.Kind.MISS, 0)),
	]

	var badges: Array[String] = []
	if _engine.is_full_combo():
		badges.append("Full combo")
	if _engine.is_all_perfect():
		badges.append("All Perfect")
	if _engine.is_failed():
		badges.append("FAILED")
	if not _engine.is_ranked():
		badges.append("Unranked")
	_badges_label.text = " · ".join(badges)

	var mean_offset := _mean_offset()
	var direction := "on time"
	if mean_offset < 0.0:
		direction = "early"
	elif mean_offset > 0.0:
		direction = "late"
	_offset_label.text = "Mean offset: %.1f ms %s" % [absf(mean_offset), direction]

	_build_histogram()


func _mean_offset() -> float:
	var errors := _engine.hit_errors
	if errors.is_empty():
		return 0.0
	var total := 0.0
	for error in errors:
		total += error
	return total / errors.size()


## Buckets JudgeEngine.hit_errors (signed ms, early = negative) into
## HISTOGRAM_BUCKET_COUNT bars spanning the observed range (at least the
## Good window, wider if any tail-release outliers exceeded it). Bars are
## bottom-aligned (SIZE_SHRINK_END) inside a fixed-height container so they
## read as a growing-up bar chart.
func _build_histogram() -> void:
	for child in _histogram_container.get_children():
		child.queue_free()

	var errors := _engine.hit_errors
	if errors.is_empty():
		var label := Label.new()
		label.text = "No hits recorded."
		_histogram_container.add_child(label)
		return

	var range_ms := Config.gameplay.window_good_ms
	for error in errors:
		range_ms = maxf(range_ms, absf(error))
	range_ms *= 1.05 # small margin so edge values aren't clipped into the last bucket.

	var bucket_width := (2.0 * range_ms) / HISTOGRAM_BUCKET_COUNT
	var counts: Array[int] = []
	counts.resize(HISTOGRAM_BUCKET_COUNT)
	for i in counts.size():
		counts[i] = 0
	for error in errors:
		var idx := int(floorf((error + range_ms) / bucket_width))
		idx = clampi(idx, 0, HISTOGRAM_BUCKET_COUNT - 1)
		counts[idx] += 1

	var max_count := 1
	for count in counts:
		max_count = maxi(max_count, count)

	_histogram_container.custom_minimum_size.y = HISTOGRAM_MAX_HEIGHT
	var center_bucket := int(HISTOGRAM_BUCKET_COUNT / 2)
	for i in HISTOGRAM_BUCKET_COUNT:
		var bar := ColorRect.new()
		var height := maxf(2.0, (float(counts[i]) / max_count) * HISTOGRAM_MAX_HEIGHT)
		bar.custom_minimum_size = Vector2(HISTOGRAM_BAR_WIDTH, height)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.color = DesignTokens.COLOR_AMBER if i == center_bucket else DesignTokens.COLOR_PINK
		_histogram_container.add_child(bar)


func _on_retry_pressed() -> void:
	SceneRouter.goto_scene(GAMEPLAY_SCENE)


func _on_next_pressed() -> void:
	PlaySession.advance_to_next_chart()
	SceneRouter.goto_scene(GAMEPLAY_SCENE)


func _on_back_pressed() -> void:
	SceneRouter.goto_scene(SONG_SELECT_SCENE)
