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
## sorted highest score first. Chart title/difficulty come from re-reading
## each .oct's metadata since ScoreStore only stores the numeric result,
## not display strings; a missing/moved chart file is skipped rather than
## shown with blank text.
func _populate_best_scores() -> void:
	var entries: Dictionary = ScoreStore.all_entries()
	var rows: Array[Dictionary] = []
	for chart_path in entries:
		var best: Dictionary = entries[chart_path]
		var chart: Chart = OctIO.load_oct(chart_path)
		if chart == null:
			continue
		rows.append({
			"title": chart.metadata.title if not chart.metadata.title.is_empty() else chart_path.get_file(),
			"difficulty_name": chart.metadata.difficulty_name,
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
	title_label.text = row.title
	title_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	info_vbox.add_child(title_label)

	if not String(row.difficulty_name).is_empty():
		var diff_label := Label.new()
		diff_label.text = row.difficulty_name
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
