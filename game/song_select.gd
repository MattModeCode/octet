extends Control
## Stage 3 (M1b) song select: scans local .oct charts and lets the player
## pick one to play (PROJECT_BRIEF §7 milestone M1 -- "Loads a local .oct").
## Deliberately minimal -- no sort/filter/preview yet (DESIGN_BRIEF §6.2's
## full vision), just enough to get from "here are my charts" to gameplay.
##
## Scans two locations: the repo's own tests/fixtures/*.oct (so there's
## something to play out of the box) and user://songs/*.oct (the real
## per-machine convention for player-installed charts, auto-created if
## missing). Real audio import (Stage 4) and .octet bundle installation
## (Stage 5) will populate the latter for real; for now it's just a folder
## the player can drop loose .oct files into.

const FIXTURE_DIR: String = "res://tests/fixtures"
const USER_SONGS_DIR: String = "user://songs"
const GAMEPLAY_SCENE: String = "res://game/gameplay.tscn"
const CALIBRATION_SCENE: String = "res://audio/calibration.tscn"

@onready var _background: ColorRect = %Background
@onready var _list_container: VBoxContainer = %ListContainer
@onready var _detail_label: Label = %DetailLabel
@onready var _hint_label: Label = %HintLabel
@onready var _no_fail_check: CheckBox = %NoFailCheck
@onready var _play_button: Button = %PlayButton
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _back_button: Button = %BackButton

## Each entry: {"path": String, "chart": Chart}.
var _entries: Array[Dictionary] = []
var _row_buttons: Array[Button] = []
var _selected_index: int = -1


func _ready() -> void:
	_background.color = DesignTokens.COLOR_INK
	_ensure_user_songs_dir()
	_scan_charts()
	_build_rows()
	_hint_label.text = "Drop .oct files into %s/songs to add more." % OS.get_user_data_dir()

	_play_button.pressed.connect(_on_play_pressed)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_update_selection_ui()


func _ensure_user_songs_dir() -> void:
	if not DirAccess.dir_exists_absolute(USER_SONGS_DIR):
		DirAccess.make_dir_recursive_absolute(USER_SONGS_DIR)


func _scan_charts() -> void:
	_entries.clear()
	var scan_dirs: Array[String] = [FIXTURE_DIR, USER_SONGS_DIR]
	for dir_path in scan_dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() == "oct":
				var full_path := dir_path.path_join(file_name)
				var chart := OctIO.load_oct(full_path)
				if chart != null:
					_entries.append({"path": full_path, "chart": chart})
			file_name = dir.get_next()
		dir.list_dir_end()

	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.chart.metadata.title) < String(b.chart.metadata.title))


func _build_rows() -> void:
	for i in _entries.size():
		var chart: Chart = _entries[i].chart
		var button := Button.new()
		button.text = "%s — %s (%s)  %.1f★" % [
			chart.metadata.title, chart.metadata.artist, chart.metadata.difficulty_name, chart.metadata.star_rating,
		]
		button.pressed.connect(_on_row_pressed.bind(i))
		_list_container.add_child(button)
		_row_buttons.append(button)

	if not _entries.is_empty():
		_selected_index = 0


func _on_row_pressed(index: int) -> void:
	_selected_index = index
	_update_selection_ui()


func _update_selection_ui() -> void:
	for i in _row_buttons.size():
		_row_buttons[i].disabled = (i == _selected_index)

	if _selected_index >= 0:
		var chart: Chart = _entries[_selected_index].chart
		_detail_label.text = "%s\nby %s\nmapper: %s\n%s — %.1f★" % [
			chart.metadata.title, chart.metadata.artist, chart.metadata.mapper,
			chart.metadata.difficulty_name, chart.metadata.star_rating,
		]
		_play_button.disabled = false
	else:
		_detail_label.text = "No charts found."
		_play_button.disabled = true


func _on_play_pressed() -> void:
	if _selected_index < 0:
		return

	var paths: Array[String] = []
	for entry in _entries:
		paths.append(entry.path)

	PlaySession.chart_list = paths
	PlaySession.chart_index = _selected_index
	PlaySession.mods = GameplayMods.new(_no_fail_check.button_pressed, false)
	SceneRouter.goto_scene_pushed(GAMEPLAY_SCENE)


func _on_calibrate_pressed() -> void:
	SceneRouter.goto_scene_pushed(CALIBRATION_SCENE)


func _on_back_pressed() -> void:
	SceneRouter.go_back()
