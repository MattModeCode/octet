extends Control
## Main menu, rebuilt to match "Octet - Main Menu.dc.html" (Claude Design
## MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per CLAUDE.md's
## design-fidelity rule. Supersedes the Stage 0 centered placeholder.
##
## Visual layout only — all navigation targets and the autoload-defensive
## lookups below are carried over unchanged from the Stage 0 version.

const PLAY_SCENE := "res://game/song_select.tscn"
const EDITOR_SCENE := "res://editor/editor_main.tscn"
const BROWSE_MAPS_SCENE := "res://ui/map_hub.tscn"
const PROFILE_SCENE := "res://ui/profile.tscn"
## Settings destination — a real settings screen (display/volume/
## accessibility, with a link through to lane rebinding).
const SETTINGS_SCENE := "res://ui/settings.tscn"

## DesignTokens is an autoload singleton, but lane_color() is static -- call
## it on the script itself rather than the instance to avoid Godot's
## STATIC_CALLED_ON_INSTANCE warning.
const DesignTokensScript := preload("res://core/design_tokens.gd")

## Wordmark glow-pulse tuning (mockup's `octetLogoGlow`, 3.4s ease-in-out
## infinite, text-shadow alpha .35<->.6). Approximated here via an animated
## font outline alpha, since Godot Label has no blurred text-shadow.
const GLOW_MIN_ALPHA := 0.35
const GLOW_MAX_ALPHA := 0.65
const GLOW_PERIOD_SEC := 1.7 # half of the 3.4s full breathe cycle

## Tick-row pulse tuning (mockup's `octetTickPulse`, 1.6s ease-in-out
## infinite, staggered .1s per bar).
const TICK_MIN_SCALE := 1.0
const TICK_MAX_SCALE := 1.25
const TICK_PERIOD_SEC := 0.8
const TICK_STAGGER_SEC := 0.1
const TICK_BAR_SIZE := Vector2(6, 34)

## Ambient lane-column drift (mockup's `octetDrift`, translateY 0 -> -120px
## linear infinite, four columns at slightly different speeds).
const DRIFT_DISTANCE := 120.0
const DRIFT_DURATIONS := [5.0, 6.5, 4.2, 5.8]
const LANE_PILL_SIZE := Vector2(0, 64)
const LANE_PILLS_PER_COLUMN := 12 # generous run so the clipped drift never shows a gap

## Home-screen ambient music (WP-F) -- quiet background cycling, not the
## focus of the screen, so it plays well under Song Select's preview volume.
const AMBIENT_VOLUME_DB := -14.0

@onready var _tick_row: HBoxContainer = %TickRow
@onready var _wordmark: Label = %WordmarkLabel
@onready var _play_button: Button = %PlayButton
@onready var _editor_button: Button = %EditorButton
@onready var _browse_maps_button: Button = %BrowseMapsButton
@onready var _profile_button: Button = %ProfileButton
@onready var _settings_button: Button = %SettingsButton
@onready var _columns_row: HBoxContainer = %ColumnsRow
@onready var _name_label: Label = %NameLabel
@onready var _rank_label: Label = %RankLabel
@onready var _confirm_quit_overlay: ColorRect = %ConfirmQuitOverlay
@onready var _confirm_quit_button: Button = %ConfirmQuitButton
@onready var _cancel_quit_button: Button = %CancelButton

var _glow_tween: Tween

var _ambient_player: AudioStreamPlayer
var _ambient_tracks: Array[String] = []
var _ambient_index: int = -1


func _ready() -> void:
	_build_tick_row()
	_build_ambient_lanes()
	_apply_profile_placeholder()
	_wire_buttons()
	_start_wordmark_glow()
	_start_ambient_music()


## Eight bars, mirrored lane spectrum (same order as DesignTokens.LANE_COLORS),
## each with a staggered breathing scale/opacity pulse.
func _build_tick_row() -> void:
	for i in range(8):
		var bar := ColorRect.new()
		bar.custom_minimum_size = TICK_BAR_SIZE
		bar.color = _lane_color(i)
		bar.pivot_offset = TICK_BAR_SIZE / 2.0
		_tick_row.add_child(bar)
		_start_tick_pulse(bar, i * TICK_STAGGER_SEC)


func _start_tick_pulse(bar: ColorRect, delay_sec: float) -> void:
	if _reduced_motion():
		bar.modulate.a = 0.7
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_interval(delay_sec)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bar, "scale:y", TICK_MAX_SCALE, TICK_PERIOD_SEC)
	tween.parallel().tween_property(bar, "modulate:a", 1.0, TICK_PERIOD_SEC)
	tween.tween_property(bar, "scale:y", TICK_MIN_SCALE, TICK_PERIOD_SEC)
	tween.parallel().tween_property(bar, "modulate:a", 0.35, TICK_PERIOD_SEC)


## Four columns of alternating lane-colour / surface-raised pills, drifting
## upward and looping (mockup: right-side ambient embellishment, masked to
## fade in from the left — the left-edge fade is a documented deviation,
## see main.tscn's colour-comment block; Godot Control has no CSS
## mask-image equivalent without a custom shader).
##
## The mockup checkerboards which tile starts each column: columns 1 & 3
## begin with a lane-colour tile, columns 2 & 4 begin with a surface tile
## (confirmed against the live "Octet - Main Menu.dc.html" markup) — so the
## starting parity alternates per column, not just per row.
func _build_ambient_lanes() -> void:
	var column_lane_pairs := [[0, 1], [6, 1], [2, 1], [4, 1]]
	for col_index in range(4):
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 36)
		_columns_row.add_child(column)
		var lane_index: int = column_lane_pairs[col_index][0]
		var color_first: bool = col_index % 2 == 0
		for row in range(LANE_PILLS_PER_COLUMN):
			var pill := PanelContainer.new()
			pill.custom_minimum_size = LANE_PILL_SIZE
			var style := StyleBoxFlat.new()
			style.corner_radius_top_left = 32
			style.corner_radius_top_right = 32
			style.corner_radius_bottom_right = 32
			style.corner_radius_bottom_left = 32
			var row_is_color: bool = (row % 2 == 0) == color_first
			style.bg_color = _lane_color(lane_index) if row_is_color else _surface_raised_color()
			pill.add_theme_stylebox_override("panel", style)
			column.add_child(pill)
		_start_column_drift(column, DRIFT_DURATIONS[col_index])


func _start_column_drift(column: VBoxContainer, duration_sec: float) -> void:
	if _reduced_motion():
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(column, "position:y", -DRIFT_DISTANCE, duration_sec) \
		.from(0.0).set_trans(Tween.TRANS_LINEAR)


## Cycles through the same chart pool Song Select scans (core/song_library.gd,
## WP-F), one shared audio track per song regardless of how many difficulties
## it has. Silently does nothing if no songs are found (e.g. a fresh install
## with no res://songs content and no user songs yet) -- ambient music is a
## nicety, not something worth erroring over.
func _start_ambient_music() -> void:
	_ambient_tracks = _collect_ambient_tracks()
	if _ambient_tracks.is_empty():
		return
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Music"
	_ambient_player.volume_db = AMBIENT_VOLUME_DB
	_ambient_player.finished.connect(_on_ambient_track_finished)
	add_child(_ambient_player)
	_ambient_tracks.shuffle()
	_play_ambient_track_from(0)


## Unique resolved audio paths across the scanned chart pool -- multiple
## difficulties of the same song share one audio file, so this dedupes
## before building the cycle order.
func _collect_ambient_tracks() -> Array[String]:
	var seen: Dictionary = {}
	var tracks: Array[String] = []
	for entry in SongLibrary.scan_charts():
		var audio_path := SongLibrary.resolve_audio_path(String(entry.path), entry.chart)
		if audio_path.is_empty() or seen.has(audio_path) or not FileAccess.file_exists(audio_path):
			continue
		seen[audio_path] = true
		tracks.append(audio_path)
	return tracks


## Tries each track starting at [param start_index], wrapping once through
## the full list, so a handful of unreadable files can't spin this into an
## infinite finished->play->finished loop -- if every track fails to load,
## this gives up quietly rather than looping forever.
func _play_ambient_track_from(start_index: int) -> void:
	for attempt in _ambient_tracks.size():
		var index := (start_index + attempt) % _ambient_tracks.size()
		var stream := AudioImport.load_audio_file(_ambient_tracks[index])
		if stream != null:
			_ambient_index = index
			_ambient_player.stream = stream
			_ambient_player.play()
			return


func _on_ambient_track_finished() -> void:
	if _ambient_tracks.is_empty():
		return
	_play_ambient_track_from((_ambient_index + 1) % _ambient_tracks.size())


func _apply_profile_placeholder() -> void:
	# Real profile/rank data arrives with Stage 7/8 (accounts, ranks). Until
	# then this stays an honest "not signed in" state rather than the
	# mockup's sample "kayvox / RANK #1,204" — matches the CLAUDE.md rule
	# against silently faking data.
	_name_label.text = "Guest"
	_rank_label.text = "OFFLINE"


func _wire_buttons() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_editor_button.pressed.connect(_on_editor_pressed)
	_browse_maps_button.pressed.connect(_on_browse_maps_pressed)
	_profile_button.pressed.connect(_on_profile_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_confirm_quit_button.pressed.connect(_on_confirm_quit_pressed)
	_cancel_quit_button.pressed.connect(_hide_quit_confirm)


## Root menu is the only screen with no ESC handling elsewhere in the app --
## ESC here opens (or, on a second press, cancels) the quit confirmation
## rather than navigating back, since this is the scene tree's root.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm_quit_overlay.visible:
			_hide_quit_confirm()
		else:
			_show_quit_confirm()


func _show_quit_confirm() -> void:
	_confirm_quit_overlay.visible = true
	_cancel_quit_button.grab_focus() # default to the safe action


func _hide_quit_confirm() -> void:
	_confirm_quit_overlay.visible = false


func _on_confirm_quit_pressed() -> void:
	get_tree().quit()


func _on_play_pressed() -> void:
	_goto(PLAY_SCENE)


func _on_editor_pressed() -> void:
	_goto(EDITOR_SCENE)


func _on_browse_maps_pressed() -> void:
	_goto(BROWSE_MAPS_SCENE)


func _on_profile_pressed() -> void:
	_goto(PROFILE_SCENE)


func _on_settings_pressed() -> void:
	_goto(SETTINGS_SCENE)


func _goto(path: String) -> void:
	if _has_autoload("SceneRouter"):
		SceneRouter.goto_scene(path)
	else:
		push_warning("ui/main.gd: SceneRouter autoload not available; cannot navigate to %s" % path)


func _start_wordmark_glow() -> void:
	if _reduced_motion():
		_wordmark.add_theme_color_override(
			"font_outline_color",
			Color(1, 0.176471, 0.431373, (GLOW_MIN_ALPHA + GLOW_MAX_ALPHA) / 2.0)
		)
		return
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.set_trans(Tween.TRANS_SINE)
	_glow_tween.set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_method(_set_glow_alpha, GLOW_MIN_ALPHA, GLOW_MAX_ALPHA, GLOW_PERIOD_SEC)
	_glow_tween.tween_method(_set_glow_alpha, GLOW_MAX_ALPHA, GLOW_MIN_ALPHA, GLOW_PERIOD_SEC)


func _set_glow_alpha(alpha: float) -> void:
	_wordmark.add_theme_color_override("font_outline_color", Color(1, 0.176471, 0.431373, alpha))


func _lane_color(lane_index: int) -> Color:
	if _has_autoload("DesignTokens"):
		return DesignTokensScript.lane_color(lane_index)
	const FALLBACK_LANE_COLORS := [
		"#B14AED", "#FF2D6E", "#FF7A3C", "#FFC93C",
		"#FFC93C", "#FF7A3C", "#FF2D6E", "#B14AED",
	]
	return Color.html(FALLBACK_LANE_COLORS[clampi(lane_index, 0, 7)])


func _surface_raised_color() -> Color:
	if _has_autoload("DesignTokens"):
		return DesignTokens.COLOR_SURFACE_RAISED
	return Color.html("#1F1A26")


func _reduced_motion() -> bool:
	if not _has_autoload("SettingsStore"):
		return false
	if "settings" not in SettingsStore or SettingsStore.settings == null:
		return false
	return "reduced_motion" in SettingsStore.settings and SettingsStore.settings.reduced_motion


## Defensive autoload lookup so this scene still works standalone (e.g. run
## directly in the editor) even before every autoload exists.
func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
