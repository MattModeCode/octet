extends Control
## Profile screen, visually built from "Octet - Profile.dc.html" (Claude
## Design MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per CLAUDE.md's
## design-fidelity rule -- header (avatar, name, stat chips) and the two
## content panels match the mockup's layout.
##
## Known, explicitly flagged deviations: there are no accounts yet (Stage
## 7/8 scope per ui/main.gd's header comment), so identity/rank/accuracy/pp
## are an honest "Guest" / "—" placeholder rather than the mockup's sample
## "kayvox / #1,204" data -- same convention ui/main.gd already established.
## "Best scores" IS real data: it reads core/score_store.gd's local
## per-chart bests (WP-E) rather than fabricating numbers. "Recent plays"
## has no honest data to show -- ScoreStore only keeps one best per chart,
## not a play history with timestamps -- so it stays an empty state instead
## of inventing the mockup's "2 hours ago" sample entries.
##
## User-directed deviation: the mockup's "Best scores" list shows no
## difficulty at all (only "Recent plays" does, e.g. "Hard · 2 hours ago").
## Each row here additionally shows "Title — Difficulty" plus the star
## rating, since a saved score should surface which difficulty it was set
## on -- both now persisted directly on the score record (core/score_store.gd,
## core/best_scores.gd).

const MAX_BEST_SCORES: int = 8

@onready var _name_label: Label = %NameLabel
@onready var _best_scores_list: VBoxContainer = %BestScoresList
@onready var _best_scores_empty: Label = %BestScoresEmpty
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_name_label.text = "Guest"
	_populate_best_scores()
	_back_button.pressed.connect(_on_back_pressed)


## Reads real local bests from ScoreStore (WP-E) -- one row per chart,
## sorted highest score first. Difficulty (name + star rating) now comes
## from the score record itself (persisted at save time, fan-out difficulty
## picker) rather than re-reading the .oct, so a row still shows its
## difficulty even if the chart file has since moved or been deleted; the
## .oct is still consulted for the title, falling back to the chart's
## filename when it's missing.
func _populate_best_scores() -> void:
	var entries: Dictionary = ScoreStore.all_entries()
	var rows: Array[Dictionary] = []
	for chart_path in entries:
		var best: Dictionary = entries[chart_path]
		var chart: Chart = OctIO.load_oct(chart_path)
		var title := String(chart_path).get_file()
		if chart != null and not chart.metadata.title.is_empty():
			title = chart.metadata.title
		rows.append({
			"title": title,
			"difficulty_name": String(best.get("difficulty_name", "")),
			"star_rating": float(best.get("star_rating", 0.0)),
			"score": int(best.get("score", 0)),
			"grade": String(best.get("grade", "—")),
		})

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)

	_best_scores_empty.visible = rows.is_empty()
	for row in rows.slice(0, MAX_BEST_SCORES):
		_best_scores_list.add_child(_build_best_score_row(row))


func _build_best_score_row(row: Dictionary) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)

	var grade_label := Label.new()
	grade_label.text = row.grade
	grade_label.custom_minimum_size = Vector2(36, 0)
	grade_label.add_theme_color_override("font_color", DesignTokens.COLOR_AMBER)
	grade_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(grade_label)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)

	var title_label := Label.new()
	# "Title — Difficulty" (ChartMetadata.format_display_name) -- same naming
	# convention as the song-select fan-out sub-rows, so a saved score reads
	# identically to its picker entry. Falls back to a bare title when an
	# older record (saved before this change) has no difficulty_name.
	title_label.text = ChartMetadata.format_display_name(String(row.title), String(row.difficulty_name))
	title_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	info_vbox.add_child(title_label)

	if not String(row.difficulty_name).is_empty():
		var diff_label := Label.new()
		diff_label.text = "%.1f★" % float(row.star_rating)
		diff_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
		diff_label.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(diff_label)

	hbox.add_child(info_vbox)

	var score_label := Label.new()
	score_label.text = "%d" % row.score
	score_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	hbox.add_child(score_label)

	return hbox


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	SceneRouter.goto_scene("res://ui/main.tscn")
