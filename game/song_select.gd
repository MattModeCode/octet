extends Control
## Song select, rebuilt to match "Octet - Song Select.dc.html" (Claude
## Design MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per CLAUDE.md's
## design-fidelity rule. Two-pane layout: a searchable/sortable list on the
## left, a detail panel (preview, difficulty chips, your-best, Play) on the
## right.
##
## Data layer hands off to PlaySession/SceneRouter same as ever; the chart
## scan itself now lives in core/song_library.gd (WP-F), shared with
## gameplay.gd's real-audio load and ui/main.gd's ambient music so all three
## agree on what "the available songs" means. The scene-local logic left is
## grouping same-song .oct files (title+artist) into difficulty variants so
## the mockup's per-song row + difficulty-chip UI has something to bind to,
## simple search/sort over that grouping, and (WP-F) playing a short preview
## of the selected chart's real audio via a plain AudioStreamPlayer.

const GAMEPLAY_SCENE: String = "res://game/gameplay.tscn"
const CALIBRATION_SCENE: String = "res://audio/calibration.tscn"

## Loops the selected song's preview back to preview_time_ms after this many
## seconds of playback, so the preview stays a short snippet rather than
## playing out to the end of the song (WP-F).
const PREVIEW_LOOP_SECONDS: float = 12.0
const PREVIEW_VOLUME_DB: float = -6.0

enum SortMode { DIFFICULTY, RECENT, TITLE }

const COVER_TILE_SIZE := 64
const ROW_COVER_SIZE := Vector2(64, 64)

@onready var _background: ColorRect = $Background
@onready var _search_field: LineEdit = %SearchField
@onready var _sort_row: HBoxContainer = %SortRow
@onready var _list_container: VBoxContainer = %ListContainer
@onready var _preview_box: PanelContainer = %PreviewBox
@onready var _progress_fill: ColorRect = %ProgressFill
@onready var _time_label: Label = %TimeLabel
@onready var _title_label: Label = %TitleLabel
@onready var _sub_label: RichTextLabel = %SubLabel
@onready var _difficulty_chips_row: HBoxContainer = %DifficultyChipsRow
@onready var _your_best_card: PanelContainer = %YourBestCard
@onready var _your_best_overline: Label = %YourBestOverline
@onready var _score_value: Label = %ScoreValue
@onready var _acc_value: Label = %AccValue
@onready var _grade_value: Label = %GradeValue
@onready var _no_fail_check: CheckBox = %NoFailCheck
@onready var _play_button: Button = %PlayButton
@onready var _overflow_button: Button = %OverflowButton
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _back_button: Button = %BackButton

## Raw scan results: each {"path": String, "chart": Chart}. Order here is
## PlaySession's chart_list order (preserved from the Stage 3 behaviour).
var _entries: Array[Dictionary] = []
## Grouped by (title, artist): each {"title", "artist", "mapper",
## "difficulties": Array[{"path","chart"}]}.
var _songs: Array[Dictionary] = []
var _sort_mode: SortMode = SortMode.TITLE
var _search_text: String = ""

var _row_panels: Array[PanelContainer] = []
## Parallel to _row_panels -- the duration Label in each row, so the
## selected row's duration can be recoloured pink like the mockup.
var _row_duration_labels: Array[Label] = []
var _chip_buttons: Array[Button] = []
var _sort_buttons: Array[Button] = []

var _selected_song_index: int = -1
var _selected_difficulty_index: int = -1

var _preview_player: AudioStreamPlayer
var _preview_loop_timer: Timer
var _preview_start_sec: float = 0.0

var _row_style_normal: StyleBoxFlat
var _row_style_selected: StyleBoxFlat
var _chip_style_normal: StyleBoxFlat
var _chip_style_selected: StyleBoxFlat
var _sort_style_active: StyleBoxFlat
var _sort_style_inactive: StyleBoxFlat
var _stripe_texture: ImageTexture


func _ready() -> void:
	_background.color = _ink_color()
	_build_shared_styles()
	_stripe_texture = _build_stripe_texture()
	_apply_preview_placeholder_style()
	_style_play_button()
	_build_preview_player()

	_ensure_user_songs_dir()
	_scan_charts()
	_group_songs()
	_build_sort_row()
	_rebuild_list()

	_search_field.text_changed.connect(_on_search_changed)
	_play_button.pressed.connect(_on_play_pressed)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	# The mockup's overflow "⋯" has no defined action anywhere in the brief
	# — left inert rather than invented, per CLAUDE.md's design-fidelity
	# rule against guessing behaviour that isn't specified.
	_overflow_button.disabled = true

	_update_detail_panel()


func _ensure_user_songs_dir() -> void:
	if not DirAccess.dir_exists_absolute(SongLibrary.USER_SONGS_DIR):
		DirAccess.make_dir_recursive_absolute(SongLibrary.USER_SONGS_DIR)


func _scan_charts() -> void:
	_entries = SongLibrary.scan_charts()
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.chart.metadata.title) < String(b.chart.metadata.title))


## Groups same-song entries (matched by title+artist) into difficulty
## variants, so the mockup's "one row, several difficulty chips" UI has
## something real to bind to even though the underlying scan is still
## flat per-.oct-file (no chart-grouping format change).
func _group_songs() -> void:
	_songs.clear()
	var by_key: Dictionary = {}
	for entry in _entries:
		var chart: Chart = entry.chart
		var key := "%s%s" % [chart.metadata.title, chart.metadata.artist]
		if not by_key.has(key):
			var song := {
				"title": chart.metadata.title,
				"artist": chart.metadata.artist,
				"mapper": chart.metadata.mapper,
				"difficulties": [] as Array,
			}
			by_key[key] = song
			_songs.append(song)
		by_key[key].difficulties.append(entry)

	for song in _songs:
		var diffs: Array = song.difficulties
		diffs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.chart.metadata.star_rating) < float(b.chart.metadata.star_rating))


func _build_shared_styles() -> void:
	_row_style_normal = StyleBoxFlat.new()
	_row_style_normal.bg_color = Color(0, 0, 0, 0)
	_row_style_normal.border_width_top = 1
	_row_style_normal.border_color = _surface_raised_color()
	_row_style_normal.content_margin_left = 32.0
	_row_style_normal.content_margin_right = 32.0
	_row_style_normal.content_margin_top = 16.0
	_row_style_normal.content_margin_bottom = 16.0

	_row_style_selected = _row_style_normal.duplicate()
	_row_style_selected.bg_color = _surface_raised_color()
	_row_style_selected.border_width_left = 3
	_row_style_selected.border_color = _pink_color()

	_chip_style_normal = StyleBoxFlat.new()
	_chip_style_normal.bg_color = _surface_raised_color()
	_chip_style_normal.border_width_left = 1
	_chip_style_normal.border_width_top = 1
	_chip_style_normal.border_width_right = 1
	_chip_style_normal.border_width_bottom = 1
	_chip_style_normal.border_color = _hairline_color()
	_chip_style_normal.corner_radius_top_left = 8
	_chip_style_normal.corner_radius_top_right = 8
	_chip_style_normal.corner_radius_bottom_right = 8
	_chip_style_normal.corner_radius_bottom_left = 8
	_chip_style_normal.content_margin_left = 18.0
	_chip_style_normal.content_margin_right = 18.0
	_chip_style_normal.content_margin_top = 10.0
	_chip_style_normal.content_margin_bottom = 10.0

	_chip_style_selected = _chip_style_normal.duplicate()
	_chip_style_selected.border_width_left = 2
	_chip_style_selected.border_width_top = 2
	_chip_style_selected.border_width_right = 2
	_chip_style_selected.border_width_bottom = 2
	_chip_style_selected.border_color = _pink_color()

	_sort_style_active = StyleBoxFlat.new()
	_sort_style_active.bg_color = _amber_color()
	_sort_style_active.content_margin_left = 18.0
	_sort_style_active.content_margin_right = 18.0
	_sort_style_active.content_margin_top = 12.0
	_sort_style_active.content_margin_bottom = 12.0

	# Inactive tabs stay transparent so the SortPill wrapper's own
	# bg/border reads as one seamless segmented control, matching the
	# mockup -- only the active tab gets a solid (amber) fill.
	_sort_style_inactive = _sort_style_active.duplicate()
	_sort_style_inactive.bg_color = Color(0, 0, 0, 0)


## Approximates the mockup's `repeating-linear-gradient(45deg,...)`
## diagonal-stripe cover-art placeholder (no real cover art exists yet —
## Stage 5's export flow doesn't wire an art picker). Godot has no CSS
## repeating-gradient primitive, so this bakes one tileable diagonal-stripe
## texture and tiles it via TextureRect.STRETCH_TILE.
func _build_stripe_texture() -> ImageTexture:
	var image := Image.create(COVER_TILE_SIZE, COVER_TILE_SIZE, false, Image.FORMAT_RGBA8)
	var color_a := _hairline_color()
	var color_b := _surface_raised_color()
	for x in COVER_TILE_SIZE:
		for y in COVER_TILE_SIZE:
			var band := (x + y) % 24
			image.set_pixel(x, y, color_a if band < 12 else color_b)
	return ImageTexture.create_from_image(image)


func _apply_preview_placeholder_style() -> void:
	var stripe_rect := TextureRect.new()
	stripe_rect.texture = _stripe_texture
	stripe_rect.stretch_mode = TextureRect.STRETCH_TILE
	stripe_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stripe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_box.add_child(stripe_rect)
	_preview_box.move_child(stripe_rect, 0)
	_preview_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


## The mockup's Play button is a bold pink CTA (bg #FF2D6E, ink text) --
## distinct from the generic dark theme Button style every other button on
## this screen correctly uses, so it needs an explicit override rather than
## relying on the shared theme.
func _style_play_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = _pink_color()
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_right = 12
	normal.corner_radius_bottom_left = 12

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)
	var disabled := normal.duplicate()
	disabled.bg_color = normal.bg_color.darkened(0.4)

	_play_button.add_theme_stylebox_override("normal", normal)
	_play_button.add_theme_stylebox_override("hover", hover)
	_play_button.add_theme_stylebox_override("pressed", pressed)
	_play_button.add_theme_stylebox_override("disabled", disabled)
	_play_button.add_theme_font_override("font", _display_font())
	_play_button.add_theme_font_size_override("font_size", 20)
	_play_button.add_theme_color_override("font_color", _ink_color())
	_play_button.add_theme_color_override("font_hover_color", _ink_color())
	_play_button.add_theme_color_override("font_pressed_color", _ink_color())
	_play_button.add_theme_color_override("font_disabled_color", _ink_color())


## Plain AudioStreamPlayer, not Conductor -- a selection preview has no
## judgment timing to derive, so Conductor's calibration-aware clock would be
## pure overhead here (WP-F's own guidance). _preview_loop_timer restarts
## playback at the chart's preview_time_ms every PREVIEW_LOOP_SECONDS so the
## preview stays a short snippet instead of playing out the whole song.
func _build_preview_player() -> void:
	_preview_player = AudioStreamPlayer.new()
	_preview_player.volume_db = PREVIEW_VOLUME_DB
	_preview_player.finished.connect(_on_preview_finished)
	add_child(_preview_player)

	_preview_loop_timer = Timer.new()
	_preview_loop_timer.wait_time = PREVIEW_LOOP_SECONDS
	_preview_loop_timer.timeout.connect(_on_preview_loop_timeout)
	add_child(_preview_loop_timer)


func _start_preview(diff_entry: Dictionary) -> void:
	_preview_loop_timer.stop()
	var chart: Chart = diff_entry.chart
	var stream := SongLibrary.load_chart_audio(String(diff_entry.path), chart)
	if stream == null:
		_preview_player.stop()
		return
	_preview_start_sec = chart.metadata.preview_time_ms / 1000.0
	_preview_player.stream = stream
	_preview_player.play(_preview_start_sec)
	_preview_loop_timer.start()


func _stop_preview() -> void:
	_preview_loop_timer.stop()
	_preview_player.stop()


func _on_preview_loop_timeout() -> void:
	if _preview_player.playing:
		_preview_player.seek(_preview_start_sec)


## Safety net for a chart whose audio is shorter than PREVIEW_LOOP_SECONDS
## past preview_time_ms -- without this the player would just go silent
## until the loop timer next fires.
func _on_preview_finished() -> void:
	if not _preview_loop_timer.is_stopped():
		_preview_player.play(_preview_start_sec)


## Drives the preview playback bar's live elapsed time and pink progress
## fill from the real AudioStreamPlayer position (WP-F), replacing the
## static "0:00 / duration" placeholder the mockup's overlay implies is
## live-updating.
func _process(_delta: float) -> void:
	if not _preview_player.playing:
		return
	if _selected_song_index < 0 or _selected_difficulty_index < 0:
		return
	var diffs: Array = _songs[_selected_song_index].difficulties
	if _selected_difficulty_index >= diffs.size():
		return
	var chart: Chart = diffs[_selected_difficulty_index].chart
	var duration_ms := _chart_duration_ms(chart)
	if duration_ms <= 0:
		return

	var elapsed_ms := int(_preview_player.get_playback_position() * 1000.0)
	_time_label.text = "%s / %s" % [_format_duration(elapsed_ms), _format_duration(duration_ms)]
	_progress_fill.anchor_right = clampf(elapsed_ms / float(duration_ms), 0.0, 1.0)


func _build_sort_row() -> void:
	var labels := ["Difficulty", "Recent", "A–Z"]
	for i in labels.size():
		var button := Button.new()
		button.text = labels[i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", _mono_font())
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_sort_pressed.bind(i))
		_sort_row.add_child(button)
		_sort_buttons.append(button)
	_update_sort_row_styles()


func _on_sort_pressed(mode_index: int) -> void:
	_sort_mode = mode_index as SortMode
	_update_sort_row_styles()
	_rebuild_list()


func _update_sort_row_styles() -> void:
	for i in _sort_buttons.size():
		var button := _sort_buttons[i]
		var active := (i == int(_sort_mode))
		button.add_theme_stylebox_override("normal", _sort_style_active if active else _sort_style_inactive)
		button.add_theme_stylebox_override("hover", _sort_style_active if active else _sort_style_inactive)
		button.add_theme_color_override("font_color", _ink_color() if active else _text_secondary_color())


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text.to_lower()
	_rebuild_list()


func _filtered_sorted_songs() -> Array:
	var filtered: Array = []
	for song in _songs:
		if _search_text.is_empty() \
				or String(song.title).to_lower().contains(_search_text) \
				or String(song.artist).to_lower().contains(_search_text) \
				or String(song.mapper).to_lower().contains(_search_text):
			filtered.append(song)

	match _sort_mode:
		SortMode.DIFFICULTY:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _max_star(a) > _max_star(b))
		SortMode.RECENT:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _max_mtime(a) > _max_mtime(b))
		SortMode.TITLE:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return String(a.title) < String(b.title))
	return filtered


func _max_star(song: Dictionary) -> float:
	var best := 0.0
	for diff in song.difficulties:
		best = maxf(best, float(diff.chart.metadata.star_rating))
	return best


func _max_mtime(song: Dictionary) -> int:
	var best := 0
	for diff in song.difficulties:
		best = maxi(best, int(diff.mtime))
	return best


func _rebuild_list() -> void:
	for panel in _row_panels:
		panel.queue_free()
	_row_panels.clear()
	_row_duration_labels.clear()

	var visible_songs := _filtered_sorted_songs()
	var previously_selected_song: Dictionary = {}
	if _selected_song_index >= 0 and _selected_song_index < _songs.size():
		previously_selected_song = _songs[_selected_song_index]

	for song in visible_songs:
		var row_index_in_songs := _songs.find(song)
		_row_panels.append(_build_song_row(song, row_index_in_songs))

	if not visible_songs.is_empty():
		var keep_selection := not previously_selected_song.is_empty() and visible_songs.has(previously_selected_song)
		if not keep_selection:
			_select_song(_songs.find(visible_songs[0]))
		else:
			_refresh_row_selection_styles()
	else:
		_selected_song_index = -1
		_selected_difficulty_index = -1
		_update_detail_panel()


func _build_song_row(song: Dictionary, song_index: int) -> PanelContainer:
	var best_diff: Dictionary = song.difficulties.back()

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style_normal)
	_list_container.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	panel.add_child(hbox)

	var cover := TextureRect.new()
	cover.texture = _stripe_texture
	cover.stretch_mode = TextureRect.STRETCH_TILE
	cover.custom_minimum_size = ROW_COVER_SIZE
	hbox.add_child(cover)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	hbox.add_child(text_col)

	var title_label := Label.new()
	title_label.text = String(song.title)
	title_label.add_theme_font_override("font", _display_font())
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", _text_primary_color())
	text_col.add_child(title_label)

	# RichTextLabel (not Label) so the "· mapped by" connector can be muted
	# separately from the artist/mapper names either side of it, matching
	# the mockup's two-tone span styling.
	var meta_label := RichTextLabel.new()
	meta_label.bbcode_enabled = true
	meta_label.fit_content = true
	meta_label.scroll_active = false
	meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_label.text = "%s [color=#6E6676]· mapped by[/color] %s" % [String(song.artist), String(song.mapper)]
	meta_label.add_theme_font_override("normal_font", _ui_font())
	meta_label.add_theme_font_size_override("normal_font_size", 13)
	meta_label.add_theme_color_override("default_color", _text_secondary_color())
	text_col.add_child(meta_label)

	var star_badge := Label.new()
	star_badge.text = "%.1f★" % float(best_diff.chart.metadata.star_rating)
	star_badge.add_theme_font_override("font", _mono_font())
	star_badge.add_theme_font_size_override("font_size", 11)
	star_badge.add_theme_color_override("font_color", _ink_color())
	var badge_bg := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = _amber_color()
	badge_style.corner_radius_top_left = 5
	badge_style.corner_radius_top_right = 5
	badge_style.corner_radius_bottom_right = 5
	badge_style.corner_radius_bottom_left = 5
	badge_style.content_margin_left = 8.0
	badge_style.content_margin_right = 8.0
	badge_style.content_margin_top = 4.0
	badge_style.content_margin_bottom = 4.0
	badge_bg.add_theme_stylebox_override("panel", badge_style)
	badge_bg.add_child(star_badge)
	badge_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(badge_bg)

	var duration_label := Label.new()
	duration_label.text = _format_duration(_chart_duration_ms(best_diff.chart))
	duration_label.custom_minimum_size = Vector2(70, 0)
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	duration_label.add_theme_font_override("font", _mono_font())
	duration_label.add_theme_font_size_override("font_size", 13)
	duration_label.add_theme_color_override("font_color", _text_secondary_color())
	hbox.add_child(duration_label)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(_on_row_pressed.bind(song_index))
	panel.add_child(button)
	panel.move_child(button, 0)

	_row_duration_labels.append(duration_label)
	return panel


func _on_row_pressed(song_index: int) -> void:
	_select_song(song_index)


func _select_song(song_index: int) -> void:
	_selected_song_index = song_index
	if song_index >= 0 and song_index < _songs.size():
		var diffs: Array = _songs[song_index].difficulties
		_selected_difficulty_index = diffs.size() - 1 # default to the highest-star difficulty
	else:
		_selected_difficulty_index = -1
	_refresh_row_selection_styles()
	_update_detail_panel()


func _refresh_row_selection_styles() -> void:
	var visible_songs := _filtered_sorted_songs()
	for i in _row_panels.size():
		if i >= visible_songs.size():
			continue
		var is_selected := _songs.find(visible_songs[i]) == _selected_song_index
		_row_panels[i].add_theme_stylebox_override("panel", _row_style_selected if is_selected else _row_style_normal)
		# Mockup highlights the selected row's duration in pink; every
		# other row stays secondary grey.
		_row_duration_labels[i].add_theme_color_override(
			"font_color", _pink_color() if is_selected else _text_secondary_color())


func _update_detail_panel() -> void:
	for chip in _chip_buttons:
		chip.queue_free()
	_chip_buttons.clear()

	if _selected_song_index < 0:
		_stop_preview()
		_title_label.text = "No charts found"
		_sub_label.text = "Drop .oct files into %s/songs to add more." % OS.get_user_data_dir()
		_your_best_card.visible = false
		_play_button.disabled = true
		_time_label.text = "0:00 / 0:00"
		return

	var song: Dictionary = _songs[_selected_song_index]
	var diffs: Array = song.difficulties
	var selected_diff: Dictionary = diffs[_selected_difficulty_index]
	var chart: Chart = selected_diff.chart
	_start_preview(selected_diff)

	_title_label.text = String(song.title)
	var bpm := 0.0
	if not chart.timing_points.is_empty():
		bpm = chart.timing_points[0].bpm
	var duration_str := _format_duration(_chart_duration_ms(chart))
	# Two-tone to match the mockup: artist/mapper names in the default
	# secondary colour, the "· mapped by" connector and the trailing
	# "BPM · duration" stats muted.
	_sub_label.text = "%s [color=#6E6676]· mapped by[/color] %s [color=#6E6676]· %d BPM · %s[/color]" % [
		String(song.artist), String(song.mapper), roundi(bpm), duration_str,
	]
	# _process() takes over once preview playback actually starts (WP-F);
	# this is just the pre-playback fallback so the label isn't blank.
	_time_label.text = "0:00 / %s" % duration_str
	_progress_fill.anchor_right = 0.0

	for i in diffs.size():
		var diff_chart: Chart = diffs[i].chart
		var chip := Button.new()
		chip.text = "%s %.1f" % [diff_chart.metadata.difficulty_name, diff_chart.metadata.star_rating]
		chip.flat = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.add_theme_font_override("font", _mono_font())
		chip.add_theme_font_size_override("font_size", 13)
		var selected := (i == _selected_difficulty_index)
		chip.add_theme_stylebox_override("normal", _chip_style_selected if selected else _chip_style_normal)
		chip.add_theme_stylebox_override("hover", _chip_style_selected if selected else _chip_style_normal)
		chip.add_theme_color_override("font_color", _text_primary_color() if selected else _text_secondary_color())
		chip.pressed.connect(_on_chip_pressed.bind(i))
		_difficulty_chips_row.add_child(chip)
		_chip_buttons.append(chip)

	# Mockup's overline includes the selected difficulty ("YOUR BEST — HARD").
	_your_best_overline.text = "YOUR BEST — %s" % String(chart.metadata.difficulty_name).to_upper()

	var best := ScoreStore.best_for(String(selected_diff.path))
	if best.is_empty():
		_score_value.text = "—"
		_acc_value.text = "—"
		_grade_value.text = "—"
	else:
		_score_value.text = "%d" % int(best.score)
		_acc_value.text = "%.2f%%" % (float(best.accuracy) * 100.0)
		_grade_value.text = String(best.grade)
	_your_best_card.visible = true

	_play_button.disabled = false


func _on_chip_pressed(diff_index: int) -> void:
	_selected_difficulty_index = diff_index
	_update_detail_panel()


func _on_play_pressed() -> void:
	if _selected_song_index < 0 or _selected_difficulty_index < 0:
		return

	var paths: Array[String] = []
	for entry in _entries:
		paths.append(entry.path)

	var selected_path: String = _songs[_selected_song_index].difficulties[_selected_difficulty_index].path
	var play_index := paths.find(selected_path)

	PlaySession.chart_list = paths
	PlaySession.chart_index = play_index
	PlaySession.mods = GameplayMods.new(_no_fail_check.button_pressed, false)
	# A normal play from Song Select is never a playtest -- clear any stale
	# origin flag left over from an earlier editor playtest so Results'
	# Back button doesn't mistakenly route this run back to the editor.
	PlaySession.playtest_origin_scene = ""
	_stop_preview()
	SceneRouter.goto_scene_pushed(GAMEPLAY_SCENE)


func _on_calibrate_pressed() -> void:
	_stop_preview()
	SceneRouter.goto_scene_pushed(CALIBRATION_SCENE)


func _on_back_pressed() -> void:
	# Song select is only ever reached from the main menu, and the main menu
	# navigates here with the non-pushing goto_scene() (so the wordmark/logo
	# stays a stable "home" rather than accumulating stack entries) -- so
	# go_back() would find an empty stack and silently no-op. Route home
	# explicitly instead, mirroring game/results.gd's hardcoded-destination
	# pattern.
	_stop_preview()
	SceneRouter.goto_scene("res://ui/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _chart_duration_ms(chart: Chart) -> int:
	var duration := 0
	for note in chart.notes:
		var note_end: int = note.end_time_ms if note.type == "hold" and note.end_time_ms >= 0 else note.time_ms
		duration = maxi(duration, note_end)
	return duration


func _format_duration(duration_ms: int) -> String:
	var total_seconds := int(duration_ms / 1000.0)
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%d:%02d" % [minutes, seconds]


func _display_font() -> Font:
	return load("res://assets/fonts/font_display.tres")


func _mono_font() -> Font:
	return load("res://assets/fonts/font_mono.tres")


func _ui_font() -> Font:
	return load("res://assets/fonts/font_ui.tres")


func _ink_color() -> Color:
	return DesignTokens.COLOR_INK if _has_design_tokens() else Color.html("#0C0A0F")


func _surface_color() -> Color:
	return DesignTokens.COLOR_SURFACE if _has_design_tokens() else Color.html("#16131B")


func _surface_raised_color() -> Color:
	return DesignTokens.COLOR_SURFACE_RAISED if _has_design_tokens() else Color.html("#1F1A26")


func _hairline_color() -> Color:
	return DesignTokens.COLOR_HAIRLINE if _has_design_tokens() else Color.html("#2A2431")


func _text_primary_color() -> Color:
	return DesignTokens.COLOR_TEXT_PRIMARY if _has_design_tokens() else Color.html("#F5F1F5")


func _text_secondary_color() -> Color:
	return DesignTokens.COLOR_TEXT_SECONDARY if _has_design_tokens() else Color.html("#A79FAE")


func _pink_color() -> Color:
	return DesignTokens.COLOR_PINK if _has_design_tokens() else Color.html("#FF2D6E")


func _amber_color() -> Color:
	return DesignTokens.COLOR_AMBER if _has_design_tokens() else Color.html("#FFC93C")


func _has_design_tokens() -> bool:
	return get_tree() != null and get_tree().root.has_node("DesignTokens")
