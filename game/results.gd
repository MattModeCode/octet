extends Control
## Results screen, rebuilt to match "Octet - Results.dc.html" (Claude
## Design MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per CLAUDE.md's
## design-fidelity rule (PROJECT_BRIEF §2.7): grade, final accuracy, max
## combo, score, per-judgment breakdown, a hit-error histogram (early/late),
## mean offset, and retry/next/back actions.
##
## Data layer is unchanged from the Stage 3 version -- still reads
## PlaySession.last_engine (the JudgeEngine that just finished in
## game/gameplay.gd) directly, rather than re-deriving any of its state.
##
## Online score submission ("if online and ranked, submit score and show
## placement") is Stage 7 (M4) scope -- Net is still a stub that always
## reports offline, so there is nothing to submit yet. No "NEW BEST" badge
## either -- no score-persistence layer exists to compare against (not
## faking the mockup's sample data, per CLAUDE.md's rule).

const SONG_SELECT_SCENE: String = "res://game/song_select.tscn"
const GAMEPLAY_SCENE: String = "res://game/gameplay.tscn"

const HISTOGRAM_BUCKET_COUNT: int = 9
const HISTOGRAM_BAR_WIDTH: float = 68.0
const HISTOGRAM_MAX_HEIGHT: float = 140.0

const BREAKDOWN_BAR_HEIGHT := 12.0

@onready var _overline_label: Label = %OverlineLabel
@onready var _grade_label: Label = %GradeLabel
@onready var _score_value: Label = %ScoreValue
@onready var _accuracy_value: Label = %AccuracyValue
@onready var _combo_value: Label = %ComboValue
@onready var _breakdown_block: VBoxContainer = %BreakdownBlock
@onready var _badges_label: Label = %BadgesLabel
@onready var _offset_label: Label = %OffsetLabel
@onready var _histogram_container: HBoxContainer = %HistogramContainer
@onready var _retry_button: Button = %RetryButton
@onready var _next_button: Button = %NextButton
@onready var _back_button: Button = %BackButton

var _engine: JudgeEngine


func _ready() -> void:
	_engine = PlaySession.last_engine
	_back_button.pressed.connect(_on_back_pressed)

	if _engine == null:
		_grade_label.text = "—"
		_overline_label.text = "No results"
		_retry_button.disabled = true
		_next_button.disabled = true
		return

	_populate()
	_retry_button.pressed.connect(_on_retry_pressed)
	_next_button.pressed.connect(_on_next_pressed)


func _populate() -> void:
	_overline_label.text = _song_overline()
	_grade_label.text = _engine.grade()
	_accuracy_value.text = "%.2f%%" % (_engine.accuracy() * 100.0)
	_combo_value.text = "%dx" % _engine.max_combo
	_score_value.text = "%d" % _engine.score

	_build_breakdown()

	var badges: Array[String] = []
	if _engine.is_full_combo():
		badges.append("FULL COMBO")
	if _engine.is_all_perfect():
		badges.append("ALL PERFECT")
	if _engine.is_failed():
		badges.append("FAILED")
	if not _engine.is_ranked():
		badges.append("UNRANKED")
	_badges_label.text = "  ·  ".join(badges)

	var mean_offset := _mean_offset()
	var direction := "on time"
	if mean_offset < 0.0:
		direction = "early"
	elif mean_offset > 0.0:
		direction = "late"
	_offset_label.text = "avg offset %.1fms %s" % [absf(mean_offset), direction]

	_build_histogram()


func _song_overline() -> String:
	var path := PlaySession.current_chart_path()
	if path.is_empty():
		return "—"
	var chart := OctIO.load_oct(path)
	if chart == null:
		return "—"
	var meta := chart.metadata
	var diff_name := meta.difficulty_name.to_upper() if not meta.difficulty_name.is_empty() else "—"
	return "%s — %s Lv.%.0f" % [meta.title, diff_name, meta.star_rating]


func _mean_offset() -> float:
	var errors := _engine.hit_errors
	if errors.is_empty():
		return 0.0
	var total := 0.0
	for error in errors:
		total += error
	return total / errors.size()


## One labelled, proportional bar per judgment tier (mockup: label + bar +
## count, bar coloured per-tier, width proportional to the tier's share of
## the total judged notes).
func _build_breakdown() -> void:
	for child in _breakdown_block.get_children():
		child.queue_free()

	var counts := _engine.judgment_counts
	var perfect := int(counts.get(Judgment.Kind.PERFECT, 0))
	var great := int(counts.get(Judgment.Kind.GREAT, 0))
	var good := int(counts.get(Judgment.Kind.GOOD, 0))
	var miss := int(counts.get(Judgment.Kind.MISS, 0))
	var total := maxi(1, perfect + great + good + miss)

	_add_breakdown_row("PERFECT", perfect, total, DesignTokens.COLOR_PERFECT_FLASH)
	_add_breakdown_row("GREAT", great, total, DesignTokens.COLOR_AMBER)
	_add_breakdown_row("GOOD", good, total, DesignTokens.LANE_COLOR_CORAL)
	_add_breakdown_row("MISS", miss, total, DesignTokens.COLOR_MISS)


func _add_breakdown_row(label_text: String, count: int, total: int, colour: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_breakdown_block.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(90, 0)
	label.add_theme_font_override("font", load("res://assets/fonts/font_mono.tres"))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", colour)
	row.add_child(label)

	# Panel (not PanelContainer) -- PanelContainer force-fits its child to
	# the full content rect every layout pass regardless of size flags,
	# which would fight a partial-width fill bar. Panel does no child
	# layout at all, so the fill's manually-set size sticks.
	var track := Panel.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size = Vector2(0, BREAKDOWN_BAR_HEIGHT)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	track_style.corner_radius_top_left = 6
	track_style.corner_radius_top_right = 6
	track_style.corner_radius_bottom_right = 6
	track_style.corner_radius_bottom_left = 6
	track.add_theme_stylebox_override("panel", track_style)
	row.add_child(track)

	var fill := ColorRect.new()
	var fraction := float(count) / float(total)
	fill.color = colour
	fill.position = Vector2.ZERO
	fill.size = Vector2(0, BREAKDOWN_BAR_HEIGHT)
	track.add_child(fill)
	# The track's real width isn't known until after this frame's layout
	# pass, so defer the pixel-width fill sizing.
	call_deferred("_size_breakdown_fill", fill, track, fraction)

	var count_label := Label.new()
	count_label.text = str(count)
	count_label.custom_minimum_size = Vector2(56, 0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_override("font", load("res://assets/fonts/font_mono.tres"))
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	row.add_child(count_label)


func _size_breakdown_fill(fill: ColorRect, track: Control, fraction: float) -> void:
	if not is_instance_valid(fill) or not is_instance_valid(track):
		return
	fill.size.x = track.size.x * fraction


## Buckets JudgeEngine.hit_errors (signed ms, early = negative) into
## HISTOGRAM_BUCKET_COUNT bars spanning the observed range (at least the
## Good window, wider if any tail-release outliers exceeded it). Bars are
## bottom-aligned (SIZE_SHRINK_END) inside a fixed-height container so they
## read as a growing-up bar chart. Coloured on an orchid (early) -> pink
## (on time) -> coral (late) gradient across bucket position, matching the
## mockup's SVG (not by count magnitude).
func _build_histogram() -> void:
	for child in _histogram_container.get_children():
		child.queue_free()

	var errors := _engine.hit_errors
	if errors.is_empty():
		var label := Label.new()
		label.text = "No hits recorded."
		label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
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

	for i in HISTOGRAM_BUCKET_COUNT:
		var bar := ColorRect.new()
		var height := maxf(3.0, (float(counts[i]) / max_count) * HISTOGRAM_MAX_HEIGHT)
		bar.custom_minimum_size = Vector2(HISTOGRAM_BAR_WIDTH, height)
		bar.size_flags_vertical = Control.SIZE_SHRINK_END
		bar.color = _histogram_bucket_colour(i)
		_histogram_container.add_child(bar)


func _histogram_bucket_colour(bucket_index: int) -> Color:
	var t := float(bucket_index) / float(HISTOGRAM_BUCKET_COUNT - 1) # 0 = earliest, 1 = latest
	if t < 0.5:
		return DesignTokens.LANE_COLOR_ORCHID.lerp(DesignTokens.COLOR_PINK, t / 0.5)
	return DesignTokens.COLOR_PINK.lerp(DesignTokens.LANE_COLOR_CORAL, (t - 0.5) / 0.5)


func _on_retry_pressed() -> void:
	SceneRouter.goto_scene(GAMEPLAY_SCENE)


func _on_next_pressed() -> void:
	PlaySession.advance_to_next_chart()
	SceneRouter.goto_scene(GAMEPLAY_SCENE)


func _on_back_pressed() -> void:
	SceneRouter.goto_scene(SONG_SELECT_SCENE)
