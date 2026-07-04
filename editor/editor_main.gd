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
const BASE_WAVEFORM_WIDTH: float = 1800.0
## Note timeline is now vertical (time flows down, matching 2a) -- length
## is its height (scaled by _time_zoom), breadth is its width (the 8 lane
## columns' total width, scaled by _row_zoom).
const BASE_TIMELINE_LENGTH: float = 1800.0
const BASE_TIMELINE_BREADTH: float = 800.0

@onready var _background: ColorRect = %Background
@onready var _filename_label: Label = %FilenameLabel
@onready var _waveform_scroll: ScrollContainer = %WaveformScroll
@onready var _waveform_view: Control = %WaveformView
@onready var _timeline_scroll: ScrollContainer = %TimelineScroll
@onready var _note_timeline_view: Control = %NoteTimelineView
@onready var _import_button: Button = %ImportButton
@onready var _open_beatmap_button: Button = %OpenBeatmapButton
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _open_beatmap_dialog: FileDialog = %OpenBeatmapDialog
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
@onready var _difficulty_tabs_row: HBoxContainer = %DifficultyTabsRow
@onready var _add_difficulty_button: Button = %AddDifficultyButton
@onready var _remove_difficulty_button: Button = %RemoveDifficultyButton
@onready var _selected_note_fields: VBoxContainer = %SelectedNoteFields
@onready var _timing_point_fields: VBoxContainer = %TimingPointFields
@onready var _delete_note_button: Button = %DeleteNoteButton
@onready var _undo_button: Button = %UndoButton
@onready var _redo_button: Button = %RedoButton
@onready var _duplicate_button: Button = %DuplicateButton
@onready var _analyze_button: Button = %AnalyzeButton
@onready var _save_beatmap_button: Button = %SaveBeatmapButton
@onready var _save_beatmap_dialog: FileDialog = %SaveBeatmapDialog
@onready var _playtest_button: Button = %PlaytestButton
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _metronome_player: AudioStreamPlayer = %MetronomePlayer
@onready var _autosave_timer: Timer = %AutosaveTimer
@onready var _start_overlay: Control = %StartOverlay
@onready var _import_song_overlay_button: Button = %ImportSongButton
@onready var _open_beatmap_overlay_button: Button = %OpenBeatmapOverlayButton
@onready var _recover_autosave_button: Button = %RecoverAutosaveButton

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
var _difficulty_tab_group: ButtonGroup

var _analysis_thread: Thread = null
var _analysis_pending: bool = false
var _analysis_is_auto: bool = false


func _ready() -> void:
	_apply_colours()
	_populate_rate_options()
	_build_snap_row()
	_build_tool_rail()
	_wire_signals()
	_metronome_player.stream = Metronome.build_single_click()

	if EditorSession.returning_from_playtest:
		# Scene was destroyed/recreated by the playtest round trip (Back from
		# gameplay/results routes here) -- keep the in-progress project as-is,
		# no start overlay.
		EditorSession.returning_from_playtest = false
		_rebuild_difficulty_tabs()
		_refresh_all()
	else:
		# A genuinely fresh open of the editor (from the main menu). Used to
		# silently auto-create a blank "Normal" chart here; now it opens
		# blank behind a start overlay instead, so the user explicitly
		# chooses import / open / recover rather than discovering an
		# unlabelled empty project.
		EditorSession.reset()
		_rebuild_difficulty_tabs()
		_refresh_all()
		_show_start_overlay()

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


# ---------------------------------------------------------------------------
# Start overlay -- shown on every fresh editor open (not on the playtest
# round trip) so the user explicitly picks import / open / recover instead
# of landing in a silently auto-created blank "Normal" chart.
# ---------------------------------------------------------------------------

func _show_start_overlay() -> void:
	_recover_autosave_button.visible = EditorSession.has_autosave()
	_start_overlay.visible = true


func _hide_start_overlay() -> void:
	_start_overlay.visible = false


func _on_recover_autosave_pressed() -> void:
	if EditorSession.load_autosave():
		_status_label.text = "Recovered previous session from autosave."
	else:
		_status_label.text = "No autosave to recover -- starting fresh."
		_init_fresh_project()
	_hide_start_overlay()
	_rebuild_difficulty_tabs()
	_refresh_all()


func _wire_signals() -> void:
	_import_button.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	_file_dialog.file_selected.connect(_on_file_selected)
	_open_beatmap_button.pressed.connect(func() -> void: _open_beatmap_dialog.popup_centered_ratio(0.7))
	_open_beatmap_dialog.file_selected.connect(_on_open_beatmap_file_selected)
	_import_song_overlay_button.pressed.connect(func() -> void: _file_dialog.popup_centered_ratio(0.7))
	_open_beatmap_overlay_button.pressed.connect(func() -> void: _open_beatmap_dialog.popup_centered_ratio(0.7))
	_recover_autosave_button.pressed.connect(_on_recover_autosave_pressed)
	_play_button.pressed.connect(_on_play_pressed)
	_stop_button.pressed.connect(_on_stop_pressed)
	_rate_option.item_selected.connect(_on_rate_selected)
	_waveform_view.gui_input.connect(_on_waveform_gui_input)

	_bpm_spinbox.value_changed.connect(_on_bpm_changed)
	_offset_spinbox.value_changed.connect(_on_offset_changed)
	_add_timing_point_button.pressed.connect(_on_add_timing_point_pressed)

	_time_zoom_slider.value_changed.connect(_on_time_zoom_changed)
	_row_zoom_slider.value_changed.connect(_on_row_zoom_changed)

	_add_difficulty_button.pressed.connect(_on_add_difficulty_pressed)
	_remove_difficulty_button.pressed.connect(_on_remove_difficulty_pressed)

	_delete_note_button.pressed.connect(_on_delete_pressed)
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_analyze_button.pressed.connect(_on_analyze_pressed)
	_save_beatmap_button.pressed.connect(_on_save_beatmap_pressed)
	_save_beatmap_dialog.file_selected.connect(_on_save_beatmap_file_selected)
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

	if _metronome_check.button_pressed and Conductor.is_playing():
		_check_metronome_beat(song_ms)

	if _analysis_pending and _analysis_thread != null and not _analysis_thread.is_alive():
		var result: Dictionary = _analysis_thread.wait_to_finish()
		_analysis_thread = null
		_analysis_pending = false
		_apply_analysis_result(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return
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

## Order/grouping matches 2a's rail exactly: four tool icons (tap, hold,
## select, free-place) above the divider, two action icons (mirror, delete)
## below it -- not the earlier 3-then-3 split, which put free-place in the
## action group.
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

	var free_place_check := _make_rail_toggle("◈")
	free_place_check.toggled.connect(func(pressed: bool) -> void:
		_free_place = pressed
		_note_timeline_view.call("set_free_place", pressed))
	_tool_rail.add_child(free_place_check)

	var divider := ColorRect.new()
	divider.color = DesignTokens.COLOR_HAIRLINE
	divider.custom_minimum_size = Vector2(0, 1)
	_tool_rail.add_child(divider)

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

## Loads and decodes the audio file at [param path] into EditorSession
## (stream, source path, ChartAudio metadata, PCM/waveform data) and starts
## it paused on the Conductor. Shared by a fresh "Import audio" pick
## (_on_file_selected below), a .oct's sibling-audio auto-attach, and a
## .octet bundle's extracted audio (_on_open_beatmap_file_selected) --
## decoding a multi-minute song is real work, worth writing once. Returns
## false (with a status message already set) if the file fails to load.
func _load_audio_from_path(path: String) -> bool:
	var stream := AudioImport.load_audio_file(path)
	if stream == null:
		_status_label.text = "Failed to import %s -- see error log." % path.get_file()
		return false

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
	return true


func _on_file_selected(path: String) -> void:
	# Reachable from the toolbar's "Import audio" (an existing project) or
	# the start overlay's "Import a song" (no project yet) -- create the
	# blank Normal chart the old always-on-_ready() bootstrap used to make
	# automatically, but only now, on the user's explicit choice.
	var is_fresh_project := EditorSession.difficulties.is_empty()
	if is_fresh_project:
		_init_fresh_project()
	_hide_start_overlay()

	if not _load_audio_from_path(path):
		return

	# Fresh import: a new file means any earlier hand-tuned BPM/offset no
	# longer applies to this audio, so the clobber guard resets here and the
	# auto-detect pass below is free to populate the fields.
	EditorSession.bpm_offset_user_edited = false
	if is_fresh_project:
		_rebuild_difficulty_tabs()
	_refresh_all()
	_status_label.text = "Imported %s (%.1fs)." % [path.get_file(), EditorSession.audio_stream.get_length()]
	_start_analysis(true)


# ---------------------------------------------------------------------------
# Open an existing beatmap (.oct or .octet) -- previously the editor could
# only save/export, never reopen a saved beatmap for further editing except
# via implicit autosave recovery. Neither branch runs auto BPM/onset
# analysis: the opened chart's timing points and notes are real, already-
# tuned data, not a blank slate to auto-detect over.
# ---------------------------------------------------------------------------

func _on_open_beatmap_file_selected(path: String) -> void:
	match path.get_extension().to_lower():
		"oct":
			_open_oct_file(path)
		"octet":
			_open_octet_bundle(path)
		_:
			_status_label.text = "Unsupported beatmap file: %s" % path.get_file()


## Opens a single-difficulty .oct chart. Its audio isn't embedded (.oct
## only stores a filename reference, per core/chart_audio.gd), so this
## looks for a same-named sibling file next to the .oct and auto-attaches
## it if found; otherwise it leaves audio unattached and tells the user to
## use Import audio, rather than failing the whole open.
func _open_oct_file(path: String) -> void:
	var chart := OctIO.load_oct(path)
	if chart == null:
		_status_label.text = "Failed to open %s -- see error log." % path.get_file()
		return

	_ensure_analysis_thread_finished()
	Conductor.stop()
	EditorSession.reset()
	EditorSession.difficulties = [chart]
	EditorSession.timing_points = chart.timing_points
	EditorSession.audio_data = chart.audio
	EditorSession.active_difficulty_index = 0
	EditorSession.bpm_offset_user_edited = true # protect the loaded timing from auto-analysis
	_selected_notes.clear()
	_undo_stack.clear()
	_hide_start_overlay()

	var audio_loaded := false
	if not chart.audio.filename.is_empty():
		var sibling_path := path.get_base_dir().path_join(chart.audio.filename)
		if FileAccess.file_exists(sibling_path):
			audio_loaded = _load_audio_from_path(sibling_path)

	_rebuild_difficulty_tabs()
	_refresh_all()
	_status_label.text = ("Opened %s." % path.get_file()) if audio_loaded \
		else "Opened %s -- audio not found, use Import audio to attach the song." % path.get_file()


## Opens a full .octet bundle: every difficulty plus its packed audio.
## Audio is extracted to a user:// temp file and run through the normal
## import/decode pipeline (OctetBundle only hands back raw bytes, not a
## path on disk) -- EditorSession.audio_source_path ends up pointing at
## that temp copy, so a later Save beatmap has real bytes to re-read.
func _open_octet_bundle(path: String) -> void:
	var bundle := OctetBundle.read_bundle(path)
	if bundle.is_empty():
		_status_label.text = "Failed to open %s -- see error log." % path.get_file()
		return

	_ensure_analysis_thread_finished()
	Conductor.stop()
	EditorSession.reset()
	var charts: Array[Chart] = bundle["charts"]
	EditorSession.difficulties = charts
	EditorSession.timing_points = charts[0].timing_points
	EditorSession.audio_data = charts[0].audio
	EditorSession.active_difficulty_index = 0
	EditorSession.bpm_offset_user_edited = true # protect the loaded timing from auto-analysis
	_selected_notes.clear()
	_undo_stack.clear()
	_hide_start_overlay()

	var audio_filename: String = bundle["audio_filename"]
	var temp_path := "user://tmp_open_bundle.%s" % audio_filename.get_extension()
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	var audio_loaded := false
	if temp_file != null:
		temp_file.store_buffer(bundle["audio_bytes"])
		temp_file.close()
		audio_loaded = _load_audio_from_path(temp_path)
		if audio_loaded:
			# _load_audio_from_path names things after the temp path; restore
			# the real song filename for display/persistence.
			EditorSession.audio_data.filename = audio_filename
			_filename_label.text = audio_filename
	else:
		push_error("EditorMain._open_octet_bundle: failed to write temp audio file %s (error %d)" % [temp_path, FileAccess.get_open_error()])

	_rebuild_difficulty_tabs()
	_refresh_all()
	_status_label.text = ("Opened %s (%d difficulties)." % [path.get_file(), charts.size()]) if audio_loaded \
		else "Opened %s, but audio failed to load -- see error log." % path.get_file()


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
	var active: TimingPoint = BeatGrid.active_timing_point(EditorSession.timing_points, song_ms)
	var interval := Metronome.beat_interval_ms(active.bpm)
	var beat_index := int(roundf(song_ms / interval))
	if beat_index != _last_beat_flashed:
		_last_beat_flashed = beat_index
		_metronome_player.play()


# ---------------------------------------------------------------------------
# Automatic analysis (Stage 6 / M3, PROJECT_BRIEF §3.2)
# ---------------------------------------------------------------------------

func _on_analyze_pressed() -> void:
	_start_analysis(false)


## Kicks off the background-thread BPM/offset/onset analysis.
## [param is_auto] distinguishes the automatic post-import run from an
## explicit press of the Re-analyze button: only the auto path respects
## [member EditorSession.bpm_offset_user_edited] and skips overwriting
## fields the user has since hand-tuned; a manual press is an explicit
## request to re-detect and always applies its result.
func _start_analysis(is_auto: bool) -> void:
	if EditorSession.pcm_samples.is_empty():
		if not is_auto:
			_status_label.text = "Import audio before analyzing."
		return
	if _analysis_thread != null and _analysis_thread.is_alive():
		return

	_status_label.text = "Auto-detecting BPM/offset..." if is_auto else "Re-analyzing (onset detection + tempo estimation)..."
	# Bound as local copies (not read from EditorSession inside the thread
	# function) so the background thread never touches the autoload --
	# PackedFloat32Array's copy-on-write semantics make this a cheap,
	# race-free snapshot.
	var pcm := EditorSession.pcm_samples
	var rate := EditorSession.pcm_sample_rate
	_analysis_thread = Thread.new()
	_analysis_pending = true
	_analysis_is_auto = is_auto
	_analysis_thread.start(AudioAnalysis.analyze.bind(pcm, rate))


func _apply_analysis_result(result: Dictionary) -> void:
	var is_auto := _analysis_is_auto
	if is_auto and EditorSession.bpm_offset_user_edited:
		# User hand-edited BPM/offset while the background analysis was
		# still running -- don't stomp on it with a value they didn't ask
		# for. Onset seeding below still runs since it's independently
		# gated on the chart already having zero notes.
		_status_label.text = "Analysis complete, but BPM/offset already hand-edited -- kept your values."
	else:
		if EditorSession.timing_points.is_empty():
			EditorSession.timing_points = [_default_timing_point()]
		EditorSession.timing_points[0].bpm = result.bpm
		EditorSession.timing_points[0].time_ms = int(round(result.offset_ms))
		EditorSession.bpm_offset_user_edited = false
		_update_bpm_offset_fields()
		_refresh_timing_points_row()
		_refresh_waveform()

		var detected_note := "Auto-detected" if is_auto else "Analysis complete"
		_status_label.text = "%s: %.1f BPM, offset %.1fms -- press Re-analyze if this looks wrong." % [detected_note, result.bpm, result.offset_ms]

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

	if seeded_count > 0:
		_status_label.text += " -- seeded %d draft notes" % seeded_count


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
	EditorSession.bpm_offset_user_edited = true
	_refresh_waveform()
	_refresh_timing_points_row()


func _on_offset_changed(value: float) -> void:
	if EditorSession.timing_points.is_empty():
		return
	EditorSession.timing_points[0].time_ms = int(value)
	EditorSession.bpm_offset_user_edited = true
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
	_refresh_timing_point_fields()
	if EditorSession.timing_points.is_empty():
		return
	_bpm_spinbox.set_value_no_signal(EditorSession.timing_points[0].bpm)
	_offset_spinbox.set_value_no_signal(EditorSession.timing_points[0].time_ms)


## Mirrors the difficulty bar's BPM/offset SpinBoxes into the inspector's
## "Timing point" chip row block (mockup 2a shows both -- the difficulty
## bar for editing, the inspector as an always-visible read-out).
func _refresh_timing_point_fields() -> void:
	for child in _timing_point_fields.get_children():
		child.queue_free()
	if EditorSession.timing_points.is_empty():
		return
	var tp := EditorSession.timing_points[0]
	_timing_point_fields.add_child(_make_field_row("BPM", "%.2f" % tp.bpm, DesignTokens.COLOR_TEXT_PRIMARY))
	_timing_point_fields.add_child(_make_field_row("OFFSET", "%d ms" % tp.time_ms, DesignTokens.COLOR_TEXT_PRIMARY))


# ---------------------------------------------------------------------------
# Snap segmented control (§3.5: 1/1-1/16), zoom
# ---------------------------------------------------------------------------

func _populate_rate_options() -> void:
	for rate in RATE_OPTIONS:
		_rate_option.add_item("%.2fx" % rate)
	_rate_option.select(RATE_OPTIONS.find(1.0))


## Builds one joined segmented control (SnapPanel's rounded-border group
## provides the outer pill shape; each button here is flat/borderless so
## the seams disappear and only the active segment's amber fill shows,
## matching 2a's SNAP control instead of six separately-bordered buttons.
func _build_snap_row() -> void:
	var group := ButtonGroup.new()
	for division in BeatGrid.SNAP_DIVISIONS:
		var button := Button.new()
		button.text = "1/%d" % division
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = division == 4
		button.custom_minimum_size = Vector2(40, 0)
		button.add_theme_stylebox_override("normal", _segment_style(false))
		button.add_theme_stylebox_override("hover", _segment_style(false))
		button.add_theme_stylebox_override("pressed", _segment_style(true))
		button.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
		button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_INK)
		button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_MUTED)
		button.pressed.connect(_on_snap_selected.bind(division))
		_snap_row.add_child(button)


func _segment_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_AMBER if active else Color.TRANSPARENT
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


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
	_waveform_view.custom_minimum_size.x = BASE_WAVEFORM_WIDTH * _time_zoom
	_note_timeline_view.custom_minimum_size = Vector2(BASE_TIMELINE_BREADTH * _row_zoom, BASE_TIMELINE_LENGTH * _time_zoom)


# ---------------------------------------------------------------------------
# Difficulty tabs
# ---------------------------------------------------------------------------

## Native TabBar's default theme (underline-style tabs) doesn't match 2a's
## pill tabs (rounded, pink border + raised bg when active) -- built as
## procedural toggle buttons instead, same pattern as the tool rail and
## snap row.
func _rebuild_difficulty_tabs() -> void:
	var target_index := EditorSession.active_difficulty_index
	for child in _difficulty_tabs_row.get_children():
		child.queue_free()
	_difficulty_tab_group = ButtonGroup.new()

	for i in EditorSession.difficulties.size():
		var chart := EditorSession.difficulties[i]
		var button := Button.new()
		button.text = _difficulty_tab_label(chart)
		button.toggle_mode = true
		button.button_group = _difficulty_tab_group
		button.button_pressed = i == target_index
		button.add_theme_stylebox_override("normal", _difficulty_tab_style(false))
		button.add_theme_stylebox_override("hover", _difficulty_tab_style(false))
		button.add_theme_stylebox_override("pressed", _difficulty_tab_style(true))
		button.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
		button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_SECONDARY)
		button.pressed.connect(_on_difficulty_tab_changed.bind(i))
		_difficulty_tabs_row.add_child(button)

	if EditorSession.difficulties.is_empty():
		return
	EditorSession.active_difficulty_index = target_index


## "Lv.N" in the mockup reads as a difficulty level distinct from the
## chart's star_rating field, but nothing else tracks such a number --
## showing a rounded star_rating is the closest honest value rather than
## fabricating a separate level; suppressed entirely for the default
## (never-rated) 0.0 chart rather than showing a misleading "Lv.0".
func _difficulty_tab_label(chart: Chart) -> String:
	var chart_name := chart.metadata.difficulty_name
	if chart.metadata.star_rating > 0.0:
		return "%s Lv.%d" % [chart_name, int(round(chart.metadata.star_rating))]
	return chart_name


func _difficulty_tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_SURFACE_RAISED if active else Color.TRANSPARENT
	style.set_corner_radius_all(6)
	if active:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = DesignTokens.COLOR_PINK
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


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
	for child in _selected_note_fields.get_children():
		child.queue_free()

	if _selected_notes.is_empty():
		_delete_note_button.disabled = true
		var empty_label := Label.new()
		empty_label.text = "No note selected."
		empty_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
		_selected_note_fields.add_child(empty_label)
		return

	_delete_note_button.disabled = false
	var note := _selected_notes[0]
	var lane_key := KeybindDefaults.DEFAULT_LANE_KEYS[note.lane] if note.lane >= 0 and note.lane < 8 else "?"
	var suffix := "" if _selected_notes.size() == 1 else " (+%d more)" % (_selected_notes.size() - 1)

	var beat_text := "--"
	if not EditorSession.timing_points.is_empty():
		var active: TimingPoint = BeatGrid.active_timing_point(EditorSession.timing_points, note.time_ms)
		var beat_interval := Metronome.beat_interval_ms(active.bpm)
		var beat_number := (note.time_ms - active.time_ms) / beat_interval
		beat_text = "1/%d · beat %.2f" % [_snap_division, beat_number]

	_selected_note_fields.add_child(_make_field_row("LANE", "%s · lane %d%s" % [lane_key, note.lane, suffix], DesignTokens.lane_color(note.lane)))
	_selected_note_fields.add_child(_make_type_row(note.type))
	_selected_note_fields.add_child(_make_field_row("TIME", _format_time_ms(note.time_ms), DesignTokens.COLOR_TEXT_PRIMARY))
	_selected_note_fields.add_child(_make_field_row("BEAT SNAP", beat_text, DesignTokens.COLOR_TEXT_PRIMARY))


## mm:ss.mmm, matching the mockup's inspector time read-out ("00:14.375").
func _format_time_ms(time_ms: int) -> String:
	var total_seconds := time_ms / 1000.0
	var minutes := int(total_seconds / 60.0)
	var seconds := fmod(total_seconds, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]


## Caption label + chip-styled value, the field-row idiom the mockup's
## inspector uses throughout (LANE / TIME / BEAT SNAP / BPM / OFFSET).
func _make_field_row(caption: String, value_text: String, value_colour: Color) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	row.add_child(caption_label)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _chip_style())
	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_color_override("font_color", value_colour)
	chip.add_child(value_label)
	row.add_child(chip)

	return row


## Read-only TAP/HOLD segmented display (mirrors the snap row's segment
## styling) showing which type the selected note already is -- changing a
## placed note's type isn't part of NoteEditor's API, so this doesn't
## double as a control, just a read-out matching the mockup's look.
func _make_type_row(note_type: String) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)

	var caption_label := Label.new()
	caption_label.text = "TYPE"
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	row.add_child(caption_label)

	var segment_panel := PanelContainer.new()
	segment_panel.add_theme_stylebox_override("panel", _segment_group_style())
	var segment_row := HBoxContainer.new()
	segment_row.add_theme_constant_override("separation", 0)
	for option: String in ["tap", "hold"]:
		var active := option == note_type
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = 3
		cell.add_theme_stylebox_override("panel", _segment_style(active))
		var label := Label.new()
		label.text = option.to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", DesignTokens.COLOR_INK if active else DesignTokens.COLOR_TEXT_MUTED)
		cell.add_child(label)
		segment_row.add_child(cell)
	segment_panel.add_child(segment_row)
	row.add_child(segment_panel)
	return row


func _segment_group_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = DesignTokens.COLOR_HAIRLINE
	style.set_corner_radius_all(6)
	return style


# ---------------------------------------------------------------------------
# Save / export / playtest
# ---------------------------------------------------------------------------

## Replaces the old dual "Save chart" (active difficulty only, silent
## fixed user:// path) / "Export bundle" (all difficulties, also silent
## fixed user:// path) buttons -- confusing since it wasn't obvious which
## one to use, or where either had written to. One "Save beatmap" action
## now: pick a location, save every difficulty + the imported audio as a
## single .octet bundle (the format _open_octet_bundle() can reopen), with
## an explicit confirmation of what was written and where.
func _on_save_beatmap_pressed() -> void:
	if EditorSession.difficulties.is_empty():
		return
	_save_beatmap_dialog.current_file = "%s.octet" % _default_save_filename()
	_save_beatmap_dialog.popup_centered_ratio(0.7)


## Prefers the shared song title (same field OctetBundle's manifest uses),
## falling back to the active difficulty's name, then a generic default.
func _default_save_filename() -> String:
	var chart := EditorSession.active_chart()
	var title := chart.metadata.title if chart != null else ""
	var base := "beatmap"
	if not title.is_empty():
		base = title
	elif chart != null and not chart.metadata.difficulty_name.is_empty():
		base = chart.metadata.difficulty_name
	return base.to_lower().replace(" ", "_")


func _on_save_beatmap_file_selected(path: String) -> void:
	if EditorSession.difficulties.is_empty():
		return

	var charts: Array[Chart] = []
	for chart in EditorSession.difficulties:
		EditorSession.sync_chart_shared_fields(chart)
		charts.append(chart)

	if EditorSession.audio_source_path.is_empty():
		# A full .octet bundle needs packed audio, which isn't imported yet.
		# Fall back to saving just the active difficulty as a plain .oct
		# (fixing the extension, since the dialog defaults to .octet)
		# rather than silently writing an audio-less bundle.
		var fallback_path := path.get_basename() + ".oct"
		var err := OctIO.save_oct(EditorSession.active_chart(), fallback_path)
		_status_label.text = ("Saved %s (active difficulty only -- import audio, then Save again for a full beatmap)." % fallback_path) if err == OK \
			else "Save failed (error %d)." % err
		return

	var manifest := {
		"title": charts[0].metadata.title,
		"artist": charts[0].metadata.artist,
	}
	var err := OctetBundle.write_bundle(path, EditorSession.audio_source_path, charts, manifest)
	_status_label.text = ("Saved beatmap to %s." % path) if err == OK else ("Save failed (error %d)." % err)


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
	PlaySession.playtest_origin_scene = "res://editor/editor_main.tscn"
	EditorSession.returning_from_playtest = true
	SceneRouter.goto_scene_pushed("res://game/gameplay.tscn")


func _on_back_pressed() -> void:
	_ensure_analysis_thread_finished()
	Conductor.stop()
	# The editor is only ever reached from the main menu via the non-pushing
	# goto_scene(), so go_back() would find an empty stack and no-op -- route
	# home explicitly, same fix as game/song_select.gd's Back button. The
	# editor -> playtest -> gameplay -> results round trip is unaffected:
	# that path returns via PlaySession.playtest_origin_scene, not this stack.
	SceneRouter.goto_scene("res://ui/main.tscn")


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
	# Pre-existing latent bug, only now reachable: the ternary's [] literal
	# is a plain untyped Array, which GDScript can't implicitly coerce into
	# an Array[ChartNote]-typed var (SCRIPT ERROR at runtime) -- never hit
	# before because active_chart() was never null by the time this ran
	# (the old _ready() always synchronously created a chart first). Now
	# reachable with no project loaded (the start overlay is up).
	var notes: Array[ChartNote] = []
	if chart != null:
		notes = chart.notes
	var beats := BeatGrid.beat_times_ms(EditorSession.timing_points, EditorSession.audio_data.duration_ms)
	_note_timeline_view.call("set_data", notes, EditorSession.audio_data.duration_ms, beats, EditorSession.timing_points)
	_note_timeline_view.call("set_selection", _selected_notes)
	_refresh_inspector()


func _apply_colours() -> void:
	_background.color = DesignTokens.COLOR_INK
	_style_transport_buttons()
	_style_bpm_offset_chips()


## The mockup's BPM/OFFSET fields in the difficulty bar read as plain chips,
## not native SpinBoxes with visible up/down arrows -- keeps the SpinBox
## (still editable/scrollable for WP-D's auto-detect + manual override
## flow) but hides its arrow icon and restyles the internal LineEdit as a
## chip to match.
func _style_bpm_offset_chips() -> void:
	var blank_icon := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for spinbox: SpinBox in [_bpm_spinbox, _offset_spinbox]:
		spinbox.add_theme_icon_override("updown", blank_icon)
		var line_edit := spinbox.get_line_edit()
		line_edit.add_theme_stylebox_override("normal", _chip_style())
		line_edit.add_theme_stylebox_override("focus", _chip_style())
		line_edit.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)


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
