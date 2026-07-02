extends Control
## Editor shell (Stage 4 + Stage 5 + Stage 6 / M2a-M2b-M3), rebuilt around
## the imported Claude Design mockup "Octet - Editor.dc.html", option
## **2a** ("Standard DAW layout — waveform top, tool rail left, inspector
## right") -- see docs/DESIGN_HANDOFF.md for why "2a" and not the earlier
## guessed "1A". Structure: top bar (wordmark/transport) -> difficulty
## tabs + BPM/offset/snap chips -> waveform -> body (tool rail / note
## timeline / inspector) -> bottom utility bar. Every row is a real
## auto-flowing Container now (VBoxContainer/HBoxContainer/PanelContainer)
## -- no more hand-computed layout_mode=0 pixel offsets, which is what
## caused the button-hitbox misalignment bug: rows pinned to a fixed 36px
## height (borderline against the theme's real Button minimum) silently
## overflowed into the next row's space. Containers make that class of bug
## structurally impossible.
##
## All state still lives in the EditorSession autoload (Stage 5) so a
## playtest-in-editor round trip survives scene destruction/recreation.

const WAVEFORM_BUCKET_COUNT: int = 800
const RATE_OPTIONS: Array[float] = [0.25, 0.5, 0.75, 1.0]
const AUTOSAVE_INTERVAL_SEC: float = 15.0
const BASE_TIMELINE_WIDTH: float = 1800.0
const BASE_ROW_HEIGHT_TOTAL: float = 320.0

@onready var _background: ColorRect = %Background
@onready var _filename_label: Label = %FilenameLabel
@onready var _waveform_scroll: ScrollContainer = %WaveformScroll
@onready var _waveform_view: Control = %WaveformView
@onready var _timeline_scroll: ScrollContainer = %TimelineScroll
@onready var _note_timeline_view: Control = %NoteTimelineView
@onready var _import_button: Button = %ImportButton
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _play_button: Button = %PlayButton
@onready var _stop_button: Button = %StopButton
@onready var _rate_option: OptionButton = %RateOption
@onready var _metronome_check: CheckBox = %MetronomeCheck
@onready var _time_label: Label = %TimeLabel
@onready var _bpm_spinbox: SpinBox = %BpmSpinBox
@onready var _offset_spinbox: SpinBox = %OffsetSpinBox
@onready var _add_timing_point_button: Button = %AddTimingPointButton
@onready var _timing_points_row: HBoxContainer = %TimingPointsRow
@onready var _snap_row: HBoxContainer = %SnapRow
@onready var _tool_rail: VBoxContainer = %ToolRail
@onready var _time_zoom_slider: HSlider = %TimeZoomSlider
@onready var _row_zoom_slider: HSlider = %RowZoomSlider
@onready var _difficulty_tabs: TabBar = %DifficultyTabs
@onready var _add_difficulty_button: Button = %AddDifficultyButton
@onready var _remove_difficulty_button: Button = %RemoveDifficultyButton
@onready var _selected_note_label: Label = %SelectedNoteLabel
@onready var _delete_note_button: Button = %DeleteNoteButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _analyze_button: Button = %AnalyzeButton
@onready var _save_chart_button: Button = %SaveChartButton
@onready var _export_bundle_button: Button = %ExportBundleButton
@onready var _playtest_button: Button = %PlaytestButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _metronome_player: AudioStreamPlayer = %MetronomePlayer
@onready var _autosave_timer: Timer = %AutosaveTimer

var _undo_stack := EditorUndoStack.new()
var _selected_notes: Array[ChartNote] = []
var _clipboard: Array[ChartNote] = []
var _time_zoom: float = 1.0
var _row_zoom: float = 1.0
var _last_beat_flashed: int = -1
var _snap_division: int = 4
var _free_place: bool = false
var _mirror_button: Button
var _delete_tool_button: Button

var _analysis_thread: Thread = null
var _analysis_pending: bool = false


func _ready() -> void:
	_apply_colours()
	_populate_rate_options()
	_build_snap_row()
	_build_tool_rail()
	_wire_signals()
	_metronome_player.stream = Metronome.build_single_click()

	if not EditorSession.has_project():
		if EditorSession.has_autosave() and EditorSession.load_autosave():
			_status_label.text = "Recovered previous session from autosave."
		else:
			_init_fresh_project()

	_rebuild_difficulty_tabs()
	_refresh_all()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.timeout.connect(func() -> void: EditorSession.autosave())
	_autosave_timer.start()


func _init_fresh_project() -> void:
	var chart := Chart.new()
	chart.metadata.difficulty_name = "Normal"
	EditorSession.difficulties = [chart]
	EditorSession.timing_points = [_default_timing_point()]
	EditorSession.active_difficulty_index = 0


func _default_timing_point() -> TimingPoint:
	var tp := TimingPoint.new()
	tp.time_ms = 0
	tp.bpm = 120.0
	tp.meter = 4
	return tp


func _wire_signals() -> void:
	_import_button.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	_file_dialog.file_selected.connect(_on_file_selected)
	_play_button.pressed.connect(_on_play_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_rate_option.item_selected.connect(_on_rate_selected)
	_waveform_view.gui_input.connect(_on_waveform_gui_input)

	_bpm_spinbox.value_changed.connect(_on_bpm_changed)
	_offset_spinbox.value_changed.connect(_on_offset_changed)
	_add_timing_point_button.pressed.connect(_on_add_timing_point_pressed)

	_time_zoom_slider.value_changed.connect(_on_time_zoom_changed)
	_row_zoom_slider.value_changed.connect(_on_row_zoom_changed)

	_difficulty_tabs.tab_changed.connect(_on_difficulty_tab_changed)
	_add_difficulty_button.pressed.connect(_on_add_difficulty_pressed)
	_remove_difficulty_button.pressed.connect(_on_remove_difficulty_pressed)

	_delete_note_button.pressed.connect(_on_delete_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_analyze_button.pressed.connect(_on_analyze_pressed)
	_save_chart_button.pressed.connect(_on_save_chart_pressed)
	_export_bundle_button.pressed.connect(_on_export_bundle_pressed)
	_playtest_button.pressed.connect(_on_playtest_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_note_timeline_view.connect("tap_place_requested", _on_tap_place_requested)
	_note_timeline_view.connect("hold_place_requested", _on_hold_place_requested)
	_note_timeline_view.connect("note_delete_requested", _on_note_delete_requested)
	_note_timeline_view.connect("box_select_requested", _on_box_select_requested)


func _process(_delta: float) -> void:
	var song_ms := Conductor.song_time_ms()
	_waveform_view.call("set_playhead", song_ms)
	_note_timeline_view.call("set_playhead", song_ms)
	_time_label.text = "%.0f ms" % song_ms
	_play_button.text = "Pause" if Conductor.is_playing() else "Play"
	_waveform_scroll.scroll_horizontal = _timeline_scroll.scroll_horizontal

	if _metronome_check.button_pressed and Conductor.is_playing():
		_check_metronome_beat(song_ms)

	if _analysis_pending and _analysis_thread != null and not _analysis_thread.is_alive():
		var result: Dictionary = _analysis_thread.wait_to_finish()
		_analysis_thread = null
		_analysis_pending = false
		_apply_analysis_result(result)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_on_undo_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			_on_redo_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_C:
			_on_copy_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_V:
			_on_paste_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT and not _selected_notes.is_empty():
			_nudge_selection(-_snap_step_ms())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT and not _selected_notes.is_empty():
			_nudge_selection(_snap_step_ms())
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Tool rail (§3.5 note-tool palette: Tap / Hold / Select, free-place toggle,
# Mirror/Delete actions) -- built procedurally, matching the pattern
# already used for timing-point rows / song-select rows elsewhere.
# ---------------------------------------------------------------------------

func _build_tool_rail() -> void:
	var group := ButtonGroup.new()
	var tap_button := _make_rail_button("●", group)
	tap_button.button_pressed = true
	tap_button.pressed.connect(func() -> void: _note_timeline_view.call("set_tool_mode", 0)) # Tool.TAP
	_tool_rail.add_child(tap_button)

	var hold_button := _make_rail_button("┃", group)
	hold_button.pressed.connect(func() -> void: _note_timeline_view.call("set_tool_mode", 1)) # Tool.HOLD
	_tool_rail.add_child(hold_button)

	var select_button := _make_rail_button("▭", group)
	select_button.pressed.connect(func() -> void: _note_timeline_view.call("set_tool_mode", 2)) # Tool.SELECT
	_tool_rail.add_child(select_button)

	var divider := ColorRect.new()
	divider.color = DesignTokens.COLOR_HAIRLINE
	divider.custom_minimum_size = Vector2(0, 1)
	_tool_rail.add_child(divider)

	var free_place_check := _make_rail_toggle("⌁")
	free_place_check.toggled.connect(func(pressed: bool) -> void:
		_free_place = pressed
		_note_timeline_view.call("set_free_place", pressed))
	_tool_rail.add_child(free_place_check)

	_mirror_button = _make_rail_action("⇋")
	_mirror_button.pressed.connect(_on_mirror_pressed)
	_tool_rail.add_child(_mirror_button)

	_delete_tool_button = _make_rail_action("⌫")
	_delete_tool_button.pressed.connect(_on_delete_pressed)
	_tool_rail.add_child(_delete_tool_button)


func _make_rail_button(label_text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_stylebox_override("normal", _tool_style(false))
	button.add_theme_stylebox_override("pressed", _tool_style(true))
	button.add_theme_stylebox_override("hover", _tool_style(false))
	return button


func _make_rail_toggle(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_stylebox_override("normal", _tool_style(false))
	button.add_theme_stylebox_override("pressed", _tool_style(true))
	button.add_theme_stylebox_override("hover", _tool_style(false))
	return button


func _make_rail_action(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_stylebox_override("normal", _tool_style(false))
	return button


func _tool_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_PINK if active else DesignTokens.COLOR_SURFACE_RAISED
	style.set_corner_radius_all(10)
	if not active:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = DesignTokens.COLOR_HAIRLINE
	return style


# ---------------------------------------------------------------------------
# Audio import / transport
# ---------------------------------------------------------------------------

func _on_file_selected(path: String) -> void:
	var stream := AudioImport.load_audio_file(path)
	if stream == null:
		_status_label.text = "Failed to import %s -- see error log." % path.get_file()
		return

	EditorSession.audio_stream = stream
	EditorSession.audio_source_path = path
	EditorSession.audio_data.filename = path.get_file()
	EditorSession.audio_data.duration_ms = int(round(stream.get_length() * 1000.0))
	_filename_label.text = path.get_file()

	if EditorSession.timing_points.is_empty():
		EditorSession.timing_points = [_default_timing_point()]

	_status_label.text = "Decoding %s..." % path.get_file()
	EditorSession.pcm_samples = AudioImport.decode_full_pcm(stream)
	EditorSession.pcm_sample_rate = AudioImport.effective_sample_rate(EditorSession.pcm_samples, stream.get_length())
	EditorSession.waveform_peaks = AudioImport.build_waveform_peaks(EditorSession.pcm_samples, WAVEFORM_BUCKET_COUNT)

	Conductor.play(stream)
	Conductor.pause()

	_refresh_all()
	_status_label.text = "Imported %s (%.1fs)." % [path.get_file(), stream.get_length()]


func _on_play_pressed() -> void:
	if EditorSession.audio_stream == null:
		return
	if Conductor.is_playing():
		Conductor.pause()
	else:
		Conductor.resume()


func _on_stop_pressed() -> void:
	if EditorSession.audio_stream == null:
		return
	Conductor.seek_ms(0.0)
	if Conductor.is_playing():
		Conductor.pause()
	_last_beat_flashed = -1


func _on_rate_selected(index: int) -> void:
	Conductor.set_playback_rate(RATE_OPTIONS[index])


func _on_waveform_gui_input(event: InputEvent) -> void:
	if EditorSession.audio_stream == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var time_ms: float = _waveform_view.call("x_to_time_ms", event.position.x)
		Conductor.seek_ms(time_ms)


func _check_metronome_beat(song_ms: float) -> void:
	if EditorSession.timing_points.is_empty():
		return
	var active := BeatGrid.active_timing_point(EditorSession.timing_points, song_ms)
	var interval := Metronome.beat_interval_ms(active.bpm)
	var beat_index := int(roundf(song_ms / interval))
	if beat_index != _last_beat_flashed:
		_last_beat_flashed = beat_index
		_metronome_player.play()


# ---------------------------------------------------------------------------
# Automatic analysis (Stage 6 / M3, PROJECT_BRIEF §3.2)
# ---------------------------------------------------------------------------

func _on_analyze_pressed() -> void:
	if EditorSession.pcm_samples.is_empty():
		_status_label.text = "Import audio before analyzing."
		return
	if _analysis_thread != null and _analysis_thread.is_alive():
		return

	_status_label.text = "Analyzing (onset detection + tempo estimation)..."
	# Bound as local copies (not read from EditorSession inside the thread
	# function) so the background thread never touches the autoload --
	# PackedFloat32Array's copy-on-write semantics make this a cheap,
	# race-free snapshot.
	var pcm := EditorSession.pcm_samples
	var rate := EditorSession.pcm_sample_rate
	_analysis_thread = Thread.new()
	_analysis_pending = true
	_analysis_thread.start(AudioAnalysis.analyze.bind(pcm, rate))


func _apply_analysis_result(result: Dictionary) -> void:
	if EditorSession.timing_points.is_empty():
		EditorSession.timing_points = [_default_timing_point()]
	EditorSession.timing_points[0].bpm = result.bpm
	EditorSession.timing_points[0].time_ms = int(round(result.offset_ms))
	_update_bpm_offset_fields()
	_refresh_timing_points_row()
	_refresh_waveform()

	var chart := EditorSession.active_chart()
	var seeded_count := 0
	# Non-destructive default: only seed onset-aligned taps if the active
	# chart currently has zero notes -- never silently clobbers existing work.
	if chart != null and chart.notes.is_empty() and not result.onsets.is_empty():
		_undo_stack.record(chart.notes)
		var lane := 0
		for onset_ms in result.onsets:
			NoteEditor.place_tap(chart.notes, lane, int(round(onset_ms)))
			lane = (lane + 1) % 8
		seeded_count = result.onsets.size()
		_refresh_notes()

	var seed_note := " -- seeded %d draft notes" % seeded_count if seeded_count > 0 else ""
	_status_label.text = "Analysis complete: %.1f BPM, offset %.1fms%s" % [result.bpm, result.offset_ms, seed_note]


func _ensure_analysis_thread_finished() -> void:
	if _analysis_thread != null:
		if _analysis_thread.is_alive():
			_analysis_thread.wait_to_finish()
		_analysis_thread = null
		_analysis_pending = false


# ---------------------------------------------------------------------------
# BPM / offset / timing points
# ---------------------------------------------------------------------------

func _on_bpm_changed(value: float) -> void:
	if EditorSession.timing_points.is_empty():
		return
	EditorSession.timing_points[0].bpm = value
	_refresh_waveform()
	_refresh_timing_points_row()


func _on_offset_changed(value: float) -> void:
	if EditorSession.timing_points.is_empty():
		return
	EditorSession.timing_points[0].time_ms = int(value)
	_refresh_waveform()
	_refresh_timing_points_row()


func _on_add_timing_point_pressed() -> void:
	if EditorSession.timing_points.is_empty():
		return
	var tp := TimingPoint.new()
	tp.time_ms = int(round(Conductor.song_time_ms()))
	tp.bpm = EditorSession.timing_points[0].bpm
	tp.meter = EditorSession.timing_points[0].meter
	var points: Array[TimingPoint] = EditorSession.timing_points.duplicate()
	points.append(tp)
	points.sort_custom(func(a: TimingPoint, b: TimingPoint) -> bool: return a.time_ms < b.time_ms)
	EditorSession.timing_points = points
	_refresh_timing_points_row()
	_refresh_waveform()


func _on_remove_timing_point_pressed(index: int) -> void:
	if index == 0 or index >= EditorSession.timing_points.size():
		return
	var points: Array[TimingPoint] = EditorSession.timing_points.duplicate()
	points.remove_at(index)
	EditorSession.timing_points = points
	_refresh_timing_points_row()
	_refresh_waveform()


## Compact horizontal row of timing-point chips (replacing Stage 4's
## vertical scrollable list -- the 2A layout doesn't have room for a tall
## panel here, and a chip row matches the mockup's visual language better).
func _refresh_timing_points_row() -> void:
	for child in _timing_points_row.get_children():
		child.queue_free()

	for i in EditorSession.timing_points.size():
		var tp := EditorSession.timing_points[i]
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _chip_style())
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var label := Label.new()
		label.text = "%dms · %.1f BPM" % [tp.time_ms, tp.bpm]
		label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
		row.add_child(label)

		if i > 0:
			var remove_button := Button.new()
			remove_button.text = "×"
			remove_button.custom_minimum_size = Vector2(24, 0)
			remove_button.pressed.connect(_on_remove_timing_point_pressed.bind(i))
			row.add_child(remove_button)

		chip.add_child(row)
		_timing_points_row.add_child(chip)


func _chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = DesignTokens.COLOR_HAIRLINE
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _update_bpm_offset_fields() -> void:
	if EditorSession.timing_points.is_empty():
		return
	_bpm_spinbox.set_value_no_signal(EditorSession.timing_points[0].bpm)
	_offset_spinbox.set_value_no_signal(EditorSession.timing_points[0].time_ms)


# ---------------------------------------------------------------------------
# Snap segmented control (§3.5: 1/1-1/16), zoom
# ---------------------------------------------------------------------------

func _populate_rate_options() -> void:
	for rate in RATE_OPTIONS:
		_rate_option.add_item("%.2fx" % rate)
	_rate_option.select(RATE_OPTIONS.find(1.0))


func _build_snap_row() -> void:
	var group := ButtonGroup.new()
	for division in BeatGrid.SNAP_DIVISIONS:
		var button := Button.new()
		button.text = "1/%d" % division
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = division == 4
		button.custom_minimum_size = Vector2(48, 0)
		button.pressed.connect(_on_snap_selected.bind(division))
		_snap_row.add_child(button)


func _on_snap_selected(division: int) -> void:
	_snap_division = division
	_note_timeline_view.call("set_snap_division", division)


func _snap_step_ms() -> int:
	if EditorSession.timing_points.is_empty():
		return 10
	var bpm := EditorSession.timing_points[0].bpm
	return int(round(Metronome.beat_interval_ms(bpm) / _snap_division))


func _on_time_zoom_changed(value: float) -> void:
	_time_zoom = value
	_apply_zoom()


func _on_row_zoom_changed(value: float) -> void:
	_row_zoom = value
	_apply_zoom()


func _apply_zoom() -> void:
	_waveform_view.custom_minimum_size.x = BASE_TIMELINE_WIDTH * _time_zoom
	_note_timeline_view.custom_minimum_size = Vector2(BASE_TIMELINE_WIDTH * _time_zoom, BASE_ROW_HEIGHT_TOTAL * _row_zoom)


# ---------------------------------------------------------------------------
# Difficulty tabs
# ---------------------------------------------------------------------------

## TabBar auto-selects tab 0 as tabs go from empty to non-empty while
## looping add_tab() below, firing tab_changed(0) and -- via
## _on_difficulty_tab_changed() -- overwriting EditorSession's intended
## active_difficulty_index before this function gets a chance to set the
## real target. Captured up front and re-asserted at the end (caught by
## an end-to-end verification script during Stage 5; see docs/BUILD_PLAN.md).
func _rebuild_difficulty_tabs() -> void:
	var target_index := EditorSession.active_difficulty_index
	_difficulty_tabs.clear_tabs()
	for chart in EditorSession.difficulties:
		_difficulty_tabs.add_tab(chart.metadata.difficulty_name)
	_difficulty_tabs.current_tab = target_index
	EditorSession.active_difficulty_index = target_index


func _on_difficulty_tab_changed(tab: int) -> void:
	EditorSession.active_difficulty_index = tab
	_selected_notes.clear()
	_undo_stack.clear()
	_refresh_notes()


func _on_add_difficulty_pressed() -> void:
	var source := EditorSession.active_chart()
	var chart := Chart.new()
	chart.metadata.title = source.metadata.title if source != null else ""
	chart.metadata.artist = source.metadata.artist if source != null else ""
	chart.metadata.mapper = source.metadata.mapper if source != null else ""
	chart.metadata.difficulty_name = "Difficulty %d" % (EditorSession.difficulties.size() + 1)
	EditorSession.difficulties.append(chart)
	EditorSession.active_difficulty_index = EditorSession.difficulties.size() - 1
	_rebuild_difficulty_tabs()
	_selected_notes.clear()
	_undo_stack.clear()
	_refresh_notes()


func _on_remove_difficulty_pressed() -> void:
	if EditorSession.difficulties.size() <= 1:
		_status_label.text = "Can't remove the last difficulty."
		return
	EditorSession.difficulties.remove_at(EditorSession.active_difficulty_index)
	EditorSession.active_difficulty_index = clampi(EditorSession.active_difficulty_index, 0, EditorSession.difficulties.size() - 1)
	_rebuild_difficulty_tabs()
	_selected_notes.clear()
	_undo_stack.clear()
	_refresh_notes()


# ---------------------------------------------------------------------------
# Note placement / selection / editing (§3.5-3.6)
# ---------------------------------------------------------------------------

func _on_tap_place_requested(lane: int, time_ms: int) -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	_undo_stack.record(chart.notes)
	var note := NoteEditor.place_tap(chart.notes, lane, time_ms)
	_selected_notes = [note]
	_refresh_notes()


func _on_hold_place_requested(lane: int, start_ms: int, end_ms: int) -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	_undo_stack.record(chart.notes)
	var note := NoteEditor.place_hold(chart.notes, lane, start_ms, end_ms)
	_selected_notes = [note]
	_refresh_notes()


func _on_note_delete_requested(note: ChartNote) -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	_undo_stack.record(chart.notes)
	NoteEditor.delete_notes(chart.notes, [note])
	_selected_notes.erase(note)
	_refresh_notes()


func _on_box_select_requested(start_ms: float, end_ms: float, lane_min: int, lane_max: int) -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	_selected_notes = NoteEditor.notes_in_range(chart.notes, start_ms, end_ms, lane_min, lane_max)
	_note_timeline_view.call("set_selection", _selected_notes)
	_refresh_inspector()
	_status_label.text = "Selected %d note(s)." % _selected_notes.size()


func _on_undo_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	chart.notes = _undo_stack.undo(chart.notes)
	_selected_notes.clear()
	_refresh_notes()


func _on_redo_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	chart.notes = _undo_stack.redo(chart.notes)
	_selected_notes.clear()
	_refresh_notes()


func _on_mirror_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	var target := _selected_notes if not _selected_notes.is_empty() else chart.notes
	_undo_stack.record(chart.notes)
	NoteEditor.mirror_notes(target)
	_refresh_notes()


func _on_duplicate_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null or _selected_notes.is_empty():
		return
	_undo_stack.record(chart.notes)
	var offset := _snap_step_ms()
	var copies := NoteEditor.duplicate_notes(_selected_notes, offset)
	chart.notes.append_array(copies)
	_selected_notes = copies
	_refresh_notes()


func _on_delete_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null or _selected_notes.is_empty():
		return
	_undo_stack.record(chart.notes)
	NoteEditor.delete_notes(chart.notes, _selected_notes)
	_selected_notes.clear()
	_refresh_notes()


func _on_copy_pressed() -> void:
	if _selected_notes.is_empty():
		return
	_clipboard = NoteEditor.duplicate_notes(_selected_notes, 0)
	_status_label.text = "Copied %d note(s)." % _clipboard.size()


func _on_paste_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null or _clipboard.is_empty():
		return
	_undo_stack.record(chart.notes)
	var paste_time := int(round(Conductor.song_time_ms()))
	var earliest := _clipboard[0].time_ms
	for note in _clipboard:
		earliest = mini(earliest, note.time_ms)
	var copies := NoteEditor.duplicate_notes(_clipboard, paste_time - earliest)
	chart.notes.append_array(copies)
	_selected_notes = copies
	_refresh_notes()


func _nudge_selection(delta_ms: int) -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	_undo_stack.record(chart.notes)
	NoteEditor.nudge_notes(_selected_notes, delta_ms)
	_refresh_notes()


# ---------------------------------------------------------------------------
# Inspector panel ("Selected note", read-only -- BPM/offset editing stays
# solely in the difficulty-bar chips, not duplicated here)
# ---------------------------------------------------------------------------

func _refresh_inspector() -> void:
	if _selected_notes.is_empty():
		_selected_note_label.text = "No note selected."
		_delete_note_button.disabled = true
		return

	_delete_note_button.disabled = false
	var note := _selected_notes[0]
	var lane_key := KeybindDefaults.DEFAULT_LANE_KEYS[note.lane] if note.lane >= 0 and note.lane < 8 else "?"
	var suffix := "" if _selected_notes.size() == 1 else " (+%d more)" % (_selected_notes.size() - 1)

	var beat_text := ""
	if not EditorSession.timing_points.is_empty():
		var active := BeatGrid.active_timing_point(EditorSession.timing_points, note.time_ms)
		var beat_interval := Metronome.beat_interval_ms(active.bpm)
		var beat_number := (note.time_ms - active.time_ms) / beat_interval
		beat_text = "Beat %.2f" % beat_number

	_selected_note_label.text = "Lane %s · lane %d%s\nType: %s\nTime: %d ms\n%s" % [
		lane_key, note.lane, suffix, note.type.capitalize(), note.time_ms, beat_text,
	]


# ---------------------------------------------------------------------------
# Save / export / playtest
# ---------------------------------------------------------------------------

func _on_save_chart_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null:
		return
	EditorSession.sync_chart_shared_fields(chart)
	var safe_name := chart.metadata.difficulty_name.to_lower().replace(" ", "_")
	var path := "user://%s.oct" % (safe_name if not safe_name.is_empty() else "chart")
	var err := OctIO.save_oct(chart, path)
	_status_label.text = ("Saved %s." % path) if err == OK else ("Save failed (error %d)." % err)


func _on_export_bundle_pressed() -> void:
	if EditorSession.audio_source_path.is_empty():
		_status_label.text = "Import audio before exporting a bundle."
		return

	var charts: Array[Chart] = []
	for chart in EditorSession.difficulties:
		EditorSession.sync_chart_shared_fields(chart)
		charts.append(chart)

	var manifest := {
		"title": charts[0].metadata.title if not charts.is_empty() else "",
		"artist": charts[0].metadata.artist if not charts.is_empty() else "",
	}
	var bundle_path := "user://%s.octet" % (charts[0].metadata.title.to_lower().replace(" ", "_") if not charts.is_empty() and not charts[0].metadata.title.is_empty() else "map")
	var err := OctetBundle.write_bundle(bundle_path, EditorSession.audio_source_path, charts, manifest)
	_status_label.text = ("Exported %s." % bundle_path) if err == OK else ("Export failed (error %d)." % err)


func _on_playtest_pressed() -> void:
	var chart := EditorSession.active_chart()
	if chart == null or EditorSession.audio_stream == null:
		_status_label.text = "Import audio and place some notes before playtesting."
		return

	_ensure_analysis_thread_finished()
	EditorSession.sync_chart_shared_fields(chart)
	PlaySession.pending_chart = chart
	PlaySession.pending_audio_stream = EditorSession.audio_stream
	PlaySession.mods = GameplayMods.new()
	SceneRouter.goto_scene_pushed("res://game/gameplay.tscn")


func _on_back_pressed() -> void:
	_ensure_analysis_thread_finished()
	Conductor.stop()
	SceneRouter.go_back()


# ---------------------------------------------------------------------------
# Refresh helpers
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_refresh_waveform()
	_refresh_notes()
	_refresh_timing_points_row()
	_update_bpm_offset_fields()
	_apply_zoom()


func _refresh_waveform() -> void:
	_waveform_view.call("set_data", EditorSession.waveform_peaks, EditorSession.audio_data.duration_ms, BeatGrid.beat_times_ms(EditorSession.timing_points, EditorSession.audio_data.duration_ms))
	_refresh_notes()


func _refresh_notes() -> void:
	var chart := EditorSession.active_chart()
	var notes: Array[ChartNote] = chart.notes if chart != null else []
	var beats := BeatGrid.beat_times_ms(EditorSession.timing_points, EditorSession.audio_data.duration_ms)
	_note_timeline_view.call("set_data", notes, EditorSession.audio_data.duration_ms, beats, EditorSession.timing_points)
	_note_timeline_view.call("set_selection", _selected_notes)
	_refresh_inspector()


func _apply_colours() -> void:
	_background.color = DesignTokens.COLOR_INK
	_style_transport_buttons()


## Fidelity-pass fix (CLAUDE.md design-fidelity rule, re-audited against the
## real "Octet - Editor.dc.html" 2a layout): the top bar's Play/Stop
## transport controls were plain default-theme text buttons; the mockup
## draws them as the same 34px rounded icon-squares used everywhere else in
## 2a's top bar (Play filled pink, Stop dark-bordered), matching the same
## visual language _tool_style() already establishes for the tool rail.
func _style_transport_buttons() -> void:
	for button in [_play_button, _stop_button]:
		button.custom_minimum_size = Vector2(48, 34)
		button.add_theme_stylebox_override("normal", _tool_style(button == _play_button))
		button.add_theme_stylebox_override("hover", _tool_style(button == _play_button))
		button.add_theme_stylebox_override("pressed", _tool_style(button == _play_button))
		button.add_theme_color_override("font_color", DesignTokens.COLOR_INK if button == _play_button else DesignTokens.COLOR_TEXT_PRIMARY)
