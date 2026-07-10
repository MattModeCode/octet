extends Control
## Map Hub — real community browse/download screen, built against
## net/net_client.gd's Map Hub API (WP-M backend). Two views in one scene:
## a searchable/sortable grid of community maps, and a per-map detail page
## (two-column layout: info+actions on the left, a fixed-width leaderboard
## panel on the right) with a download flow and an honest leaderboard stub.
##
## Re-fetched and verified against "Octet - Map Hub.dc.html" live from the
## Claude Design MCP (project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) —
## structure, colours, type, and spacing below follow that mockup directly
## (an earlier pass of this screen was built without DesignSync access and
## got the detail view's layout wrong — stacked instead of two-column — since
## corrected).
##
## Known, explicitly flagged decisions (see docs/MAP_HUB_PUBLISHING.md for
## the manifest schema this reads):
## - Leaderboard: no backend exists for this ever (manifest has no
##   leaderboard field, by design). Rendered as a clearly labeled
##   "coming soon" state, never fabricated sample rows.
## - Preview: there is no preview-audio endpoint separate from the full
##   bundle download. Preview is disabled until a map is actually downloaded
##   (matching Song Select's on-disk audio), then plays the local file.
## - Stats row shows Rating + Downloads only. The manifest has no distinct
##   "plays" field separate from download_count, so a three-stat "rating /
##   downloads / plays" row (implied by the WP brief) isn't buildable as
##   described without inventing a field — flagged rather than guessed.
## - Filters: present as a visible chip but intentionally left unwired
##   (disabled, with a tooltip) — the brief calls for keeping this scoped
##   small rather than building a full filter panel this pass.

## First-visit onboarding id (core/settings_store.gd) -- walks a newcomer
## through search -> pick a map -> download, since this is the only source
## of new songs on a fresh install (core/song_library.gd's TUTORIAL_DIR is
## the only other entry until something is downloaded here).
const COACH_ID: String = "maphub_intro"

const GRID_COLUMNS: int = 5
const COVER_TILE_SIZE: int = 64
const CARD_COVER_HEIGHT: int = 150
const DETAIL_COVER_HEIGHT: int = 280
const PREVIEW_LOOP_SECONDS: float = 12.0
const PREVIEW_VOLUME_DB: float = -6.0

enum SortMode { TOP_RATED, NEWEST, MOST_PLAYED }
enum ViewState { LOADING, ERROR, EMPTY, GRID, DETAIL }

@onready var _search_field: LineEdit = %SearchField
@onready var _sort_row: HBoxContainer = %SortRow
@onready var _filters_button: Button = %FiltersButton
@onready var _back_button: Button = %BackButton

@onready var _loading_state: Control = %LoadingState
@onready var _error_state: Control = %ErrorState
@onready var _error_message_label: Label = %ErrorMessageLabel
@onready var _retry_button: Button = %RetryButton
@onready var _empty_state: Control = %EmptyState
@onready var _grid_scroll: ScrollContainer = %GridScroll
@onready var _map_grid: GridContainer = %MapGrid
@onready var _detail_scroll: ScrollContainer = %DetailScroll

@onready var _detail_back_button: Button = %DetailBackButton
@onready var _cover_panel: PanelContainer = %CoverPanel
@onready var _detail_title: Label = %DetailTitle
@onready var _detail_sub_label: RichTextLabel = %DetailSubLabel
@onready var _detail_difficulty_row: HBoxContainer = %DetailDifficultyRow
@onready var _detail_stats_row: HBoxContainer = %DetailStatsRow
@onready var _download_button: Button = %DownloadButton
@onready var _preview_button: Button = %PreviewButton
@onready var _download_status_label: Label = %DownloadStatusLabel
@onready var _leaderboard_header: Label = %LeaderboardHeader
@onready var _leaderboard_state_label: Label = %LeaderboardStateLabel

var _maps: Array = []
var _sort_mode: SortMode = SortMode.TOP_RATED
var _search_text: String = ""
var _sort_buttons: Array[Button] = []
var _card_panels: Array[Control] = []

var _view_state: ViewState = ViewState.LOADING
var _selected_map: Dictionary = {}
## Difficulty name currently highlighted in the detail view's chip row --
## drives the "Leaderboard — <name>" header (mockup: the chip row's
## selection and the leaderboard label track the same chosen difficulty).
var _selected_difficulty_name: String = ""
## map_id -> true while a download for that map is in flight.
var _downloads_in_progress: Dictionary = {}

var _stripe_texture: ImageTexture
var _preview_player: AudioStreamPlayer
var _preview_loop_timer: Timer
var _preview_start_sec: float = 0.0
## Mockup's cover-art scrubber overlay (a play/pause glyph + a thin progress
## bar baked onto the bottom of the cover art) -- built at runtime alongside
## the stripe-texture placeholder since both are non-.tscn content.
var _cover_progress_fill: ColorRect
## cover_url -> Texture2D (or null for "fetched, failed to decode"), so the
## same map's cover is only ever downloaded once per session regardless of
## how many times its card re-renders or its detail view is revisited.
var _cover_texture_cache: Dictionary = {}
## The detail view's cover TextureRect, kept so _populate_detail() can swap
## its texture per selected map (real cover art if the manifest entry has a
## cover_url, else back to the shared stripe placeholder).
var _detail_cover_rect: TextureRect


func _ready() -> void:
	_stripe_texture = _build_stripe_texture()
	_apply_cover_placeholder_style()
	_build_preview_player()
	_style_download_button()
	_build_sort_row()

	_search_field.text_changed.connect(_on_search_changed)
	_filters_button.disabled = true
	_filters_button.tooltip_text = "Filter panel — coming soon."
	_back_button.pressed.connect(_on_back_pressed)
	_retry_button.pressed.connect(_on_retry_pressed)
	_detail_back_button.pressed.connect(_on_detail_back_pressed)
	_download_button.pressed.connect(_on_download_pressed)
	_preview_button.pressed.connect(_on_preview_pressed)

	Net.manifest_fetched.connect(_on_manifest_fetched)
	Net.manifest_fetch_failed.connect(_on_manifest_fetch_failed)
	Net.map_downloaded.connect(_on_map_downloaded)
	Net.map_download_failed.connect(_on_map_download_failed)

	_leaderboard_state_label.text = "Leaderboard coming soon — online scores aren't tracked yet."
	_leaderboard_state_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)

	_start_fetch()


func _start_fetch() -> void:
	_set_view_state(ViewState.LOADING)
	Net.fetch_map_manifest()


func _on_manifest_fetched(maps: Array) -> void:
	_maps = maps
	if _maps.is_empty():
		_set_view_state(ViewState.EMPTY)
	else:
		_set_view_state(ViewState.GRID)
		_rebuild_grid()
		# Deferred so the freshly-built card panels have been through a
		# layout pass (their get_global_rect() would be zero-sized on the
		# very first frame). Only ever reached once per fetch, so this
		# naturally fires once per visit -- has_seen_coach() gates repeats
		# across visits/launches.
		_maybe_show_coach_marks.call_deferred()


func _on_manifest_fetch_failed(error_message: String) -> void:
	_error_message_label.text = error_message
	_set_view_state(ViewState.ERROR)


func _on_retry_pressed() -> void:
	_start_fetch()


func _set_view_state(state: ViewState) -> void:
	_view_state = state
	_loading_state.visible = state == ViewState.LOADING
	_error_state.visible = state == ViewState.ERROR
	_empty_state.visible = state == ViewState.EMPTY
	_grid_scroll.visible = state == ViewState.GRID
	_detail_scroll.visible = state == ViewState.DETAIL
	if state != ViewState.DETAIL:
		_stop_preview()


# ---------------------------------------------------------------------------
# Sort / search
# ---------------------------------------------------------------------------

func _build_sort_row() -> void:
	var labels := ["Top rated", "Newest", "Most played"]
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
	_rebuild_grid()


func _update_sort_row_styles() -> void:
	for i in _sort_buttons.size():
		var button := _sort_buttons[i]
		var active := (i == int(_sort_mode))
		var style := StyleBoxFlat.new()
		style.content_margin_left = 18.0
		style.content_margin_right = 18.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		style.bg_color = DesignTokens.COLOR_AMBER if active else Color(0, 0, 0, 0)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_color_override("font_color", DesignTokens.COLOR_INK if active else DesignTokens.COLOR_TEXT_SECONDARY)


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text.to_lower()
	if _view_state == ViewState.GRID:
		_rebuild_grid()


func _filtered_sorted_maps() -> Array:
	var filtered: Array = []
	for map_entry in _maps:
		var map_dict: Dictionary = map_entry
		if _search_text.is_empty() \
				or String(map_dict.get("title", "")).to_lower().contains(_search_text) \
				or String(map_dict.get("artist", "")).to_lower().contains(_search_text) \
				or String(map_dict.get("mapper", "")).to_lower().contains(_search_text):
			filtered.append(map_dict)

	match _sort_mode:
		SortMode.TOP_RATED:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("rating", 0.0)) > float(b.get("rating", 0.0)))
		SortMode.NEWEST:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _parse_updated_at(a.get("updated_at", "")) > _parse_updated_at(b.get("updated_at", "")))
		SortMode.MOST_PLAYED:
			filtered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("download_count", 0)) > int(b.get("download_count", 0)))
	return filtered


func _parse_updated_at(value) -> int:
	var text := String(value)
	if text.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_string(text))


func _max_star(map_dict: Dictionary) -> float:
	var best := 0.0
	for diff in map_dict.get("difficulties", []):
		best = maxf(best, float(diff.get("star_rating", 0.0)))
	return best


# ---------------------------------------------------------------------------
# Grid
# ---------------------------------------------------------------------------

func _rebuild_grid() -> void:
	for panel in _card_panels:
		panel.queue_free()
	_card_panels.clear()

	for map_dict in _filtered_sorted_maps():
		_map_grid.add_child(_build_card(map_dict))


func _build_card(map_dict: Dictionary) -> Control:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	# Mockup highlights one card with a 2px pink border rather than the
	# default 1px hairline -- here that's a map the player already has
	# downloaded (a real, meaningful "you own this" state), not an arbitrary
	# sample.
	var is_downloaded := _is_map_downloaded(String(map_dict.get("id", "")))
	card_style.border_width_left = 2 if is_downloaded else 1
	card_style.border_width_top = 2 if is_downloaded else 1
	card_style.border_width_right = 2 if is_downloaded else 1
	card_style.border_width_bottom = 2 if is_downloaded else 1
	card_style.border_color = DesignTokens.COLOR_PINK if is_downloaded else DesignTokens.COLOR_HAIRLINE
	card_style.corner_radius_top_left = DesignTokens.CORNER_RADIUS_CARD
	card_style.corner_radius_top_right = DesignTokens.CORNER_RADIUS_CARD
	card_style.corner_radius_bottom_right = DesignTokens.CORNER_RADIUS_CARD
	card_style.corner_radius_bottom_left = DesignTokens.CORNER_RADIUS_CARD
	card_style.content_margin_left = 14.0
	card_style.content_margin_right = 14.0
	card_style.content_margin_top = 14.0
	card_style.content_margin_bottom = 14.0

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var cover := TextureRect.new()
	cover.texture = _stripe_texture
	cover.stretch_mode = TextureRect.STRETCH_TILE
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.clip_contents = true
	cover.custom_minimum_size = Vector2(0, CARD_COVER_HEIGHT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cover)

	var cover_url := String(map_dict.get("cover_url", ""))
	if not cover_url.is_empty():
		_request_cover_texture(cover_url, func(texture: Texture2D) -> void:
			# The grid may have been rebuilt (re-sort/re-search) by the time
			# this async fetch lands -- never touch a freed card.
			if texture == null or not is_instance_valid(cover):
				return
			cover.texture = texture
			cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		)

	var title_label := Label.new()
	title_label.text = String(map_dict.get("title", ""))
	title_label.clip_text = true
	title_label.add_theme_font_override("font", _display_font())
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	vbox.add_child(title_label)

	var mapper_label := Label.new()
	mapper_label.text = "mapped by %s" % String(map_dict.get("mapper", "Unknown"))
	mapper_label.clip_text = true
	mapper_label.add_theme_font_override("font", _ui_font())
	mapper_label.add_theme_font_size_override("font_size", 12)
	mapper_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	vbox.add_child(mapper_label)

	var bottom_row := HBoxContainer.new()
	vbox.add_child(bottom_row)

	var star_badge := Label.new()
	star_badge.text = "%.1f★" % _max_star(map_dict)
	star_badge.add_theme_font_override("font", _mono_font())
	star_badge.add_theme_font_size_override("font_size", 11)
	star_badge.add_theme_color_override("font_color", DesignTokens.COLOR_INK)
	var badge_bg := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = DesignTokens.COLOR_AMBER
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
	bottom_row.add_child(badge_bg)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

	var downloads_label := Label.new()
	downloads_label.text = "↓ %d" % int(map_dict.get("download_count", 0))
	downloads_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	downloads_label.add_theme_font_override("font", _mono_font())
	downloads_label.add_theme_font_size_override("font_size", 12)
	downloads_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	bottom_row.add_child(downloads_label)

	var click_button := Button.new()
	click_button.flat = true
	click_button.focus_mode = Control.FOCUS_NONE
	click_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_button.pressed.connect(_on_card_pressed.bind(map_dict))
	card.add_child(click_button)

	_card_panels.append(card)
	return card


func _on_card_pressed(map_dict: Dictionary) -> void:
	_selected_map = map_dict
	_set_view_state(ViewState.DETAIL)
	_populate_detail(map_dict)


# ---------------------------------------------------------------------------
# Detail view
# ---------------------------------------------------------------------------

func _populate_detail(map_dict: Dictionary) -> void:
	_stop_preview()

	# Reset to the placeholder immediately (not just on failure) so a slow
	# cover fetch never leaves the previously-viewed map's cover showing
	# under this map's title/stats while it loads.
	_detail_cover_rect.texture = _stripe_texture
	_detail_cover_rect.stretch_mode = TextureRect.STRETCH_TILE
	var cover_url := String(map_dict.get("cover_url", ""))
	var map_id := String(map_dict.get("id", ""))
	if not cover_url.is_empty():
		_request_cover_texture(cover_url, func(texture: Texture2D) -> void:
			# The player may have navigated to a different map by the time
			# this async fetch lands -- never overwrite a newer selection.
			if texture == null or _current_map_id() != map_id:
				return
			_detail_cover_rect.texture = texture
			_detail_cover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		)

	_detail_title.text = String(map_dict.get("title", ""))
	_detail_sub_label.text = "%s [color=#6E6676]· mapped by[/color] %s [color=#6E6676]· %d BPM[/color]" % [
		String(map_dict.get("artist", "Unknown Artist")),
		String(map_dict.get("mapper", "Unknown")),
		int(map_dict.get("bpm", 0)),
	]

	var difficulties: Array = map_dict.get("difficulties", [])
	# Default to the highest-star difficulty, matching Song Select's own
	# "default to hardest" convention -- also what the leaderboard header
	# reflects until the player taps another chip.
	_selected_difficulty_name = ""
	var best_star := -1.0
	for diff in difficulties:
		if float(diff.get("star_rating", 0.0)) > best_star:
			best_star = float(diff.get("star_rating", 0.0))
			_selected_difficulty_name = String(diff.get("name", ""))

	for child in _detail_difficulty_row.get_children():
		child.queue_free()
	for diff in difficulties:
		_detail_difficulty_row.add_child(_build_difficulty_chip(diff))
	_update_leaderboard_header()

	for child in _detail_stats_row.get_children():
		child.queue_free()
	var rating := float(map_dict.get("rating", 0.0))
	var rating_text := "%.1f ★" % rating if rating > 0.0 else "No ratings yet"
	_detail_stats_row.add_child(_build_stat_block("RATING", rating_text))
	_detail_stats_row.add_child(_build_stat_block("DOWNLOADS", "%d" % int(map_dict.get("download_count", 0))))
	_detail_stats_row.add_child(_build_stat_block("PLAYS", "%d" % int(map_dict.get("play_count", 0))))

	_refresh_download_state()


func _build_difficulty_chip(diff: Dictionary) -> Control:
	var diff_name := String(diff.get("name", ""))
	var selected := diff_name == _selected_difficulty_name

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	chip_style.border_width_left = 2 if selected else 1
	chip_style.border_width_top = 2 if selected else 1
	chip_style.border_width_right = 2 if selected else 1
	chip_style.border_width_bottom = 2 if selected else 1
	chip_style.border_color = DesignTokens.COLOR_PINK if selected else DesignTokens.COLOR_HAIRLINE
	chip_style.corner_radius_top_left = DesignTokens.CORNER_RADIUS_CONTROL
	chip_style.corner_radius_top_right = DesignTokens.CORNER_RADIUS_CONTROL
	chip_style.corner_radius_bottom_right = DesignTokens.CORNER_RADIUS_CONTROL
	chip_style.corner_radius_bottom_left = DesignTokens.CORNER_RADIUS_CONTROL
	chip_style.content_margin_left = 14.0
	chip_style.content_margin_right = 14.0
	chip_style.content_margin_top = 8.0
	chip_style.content_margin_bottom = 8.0

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.text = "%s %.1f" % [diff_name, float(diff.get("star_rating", 0.0))]
	button.add_theme_font_override("font", _mono_font())
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", chip_style)
	button.add_theme_stylebox_override("hover", chip_style)
	button.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY if selected else DesignTokens.COLOR_TEXT_SECONDARY)
	button.pressed.connect(_on_difficulty_chip_pressed.bind(diff_name))
	return button


func _on_difficulty_chip_pressed(diff_name: String) -> void:
	_selected_difficulty_name = diff_name
	for child in _detail_difficulty_row.get_children():
		child.queue_free()
	for diff in _selected_map.get("difficulties", []):
		_detail_difficulty_row.add_child(_build_difficulty_chip(diff))
	_update_leaderboard_header()


func _update_leaderboard_header() -> void:
	_leaderboard_header.text = "Leaderboard — %s" % _selected_difficulty_name if not _selected_difficulty_name.is_empty() else "Leaderboard"


func _build_stat_block(overline_text: String, value_text: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var overline := Label.new()
	overline.text = overline_text
	overline.add_theme_font_override("font", _mono_font())
	overline.add_theme_font_size_override("font_size", 10)
	overline.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	vbox.add_child(overline)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_override("font", _mono_font())
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	vbox.add_child(value)

	return vbox


func _on_detail_back_pressed() -> void:
	_return_to_grid()


func _return_to_grid() -> void:
	_stop_preview()
	if _maps.is_empty():
		_set_view_state(ViewState.EMPTY)
	else:
		_set_view_state(ViewState.GRID)


# ---------------------------------------------------------------------------
# Download flow
# ---------------------------------------------------------------------------

func _current_map_id() -> String:
	return String(_selected_map.get("id", ""))


func _song_dir(map_id: String) -> String:
	return SongLibrary.USER_SONGS_DIR.path_join(map_id)


func _is_map_downloaded(map_id: String) -> bool:
	return not _find_local_audio_path(map_id).is_empty()


## Finds the unpacked audio file Net.unpack_bundle_bytes() wrote as
## "song.<ext>" under user://songs/<map_id>/, or "" if the map hasn't been
## downloaded (or was downloaded but is missing its audio somehow).
func _find_local_audio_path(map_id: String) -> String:
	var dir_path := _song_dir(map_id)
	if not DirAccess.dir_exists_absolute(dir_path):
		return ""
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.begins_with("song."):
			return dir_path.path_join(file_name)
		file_name = dir.get_next()
	return ""


## Reads preview_time_ms from the first downloaded .oct chart for this map,
## if any -- lets the local preview start at the same point Song Select
## would, rather than always from 0:00.
func _find_local_preview_start_sec(map_id: String) -> float:
	var dir_path := _song_dir(map_id)
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0.0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension() == "oct":
			var chart: Chart = OctIO.load_oct(dir_path.path_join(file_name))
			if chart != null:
				return chart.metadata.preview_time_ms / 1000.0
		file_name = dir.get_next()
	return 0.0


func _on_download_pressed() -> void:
	var map_id := _current_map_id()
	if map_id.is_empty() or _downloads_in_progress.get(map_id, false):
		return
	_downloads_in_progress[map_id] = true
	_refresh_download_state()
	Net.download_map(_selected_map)


func _on_map_downloaded(map_id: String, _song_dir_path: String) -> void:
	_downloads_in_progress.erase(map_id)
	if map_id == _current_map_id():
		_download_status_label.text = "Downloaded — it'll appear in Song Select."
		_download_status_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
		_refresh_download_state()


func _on_map_download_failed(map_id: String, error_message: String) -> void:
	_downloads_in_progress.erase(map_id)
	if map_id == _current_map_id():
		_download_status_label.text = "Download failed: %s" % error_message
		_download_status_label.add_theme_color_override("font_color", DesignTokens.COLOR_DANGER)
		_refresh_download_state()


## Recomputes Download/Preview button state from disk + in-flight status.
## Called after populating detail, and after every download signal.
func _refresh_download_state() -> void:
	var map_id := _current_map_id()
	if map_id.is_empty():
		return

	var in_progress: bool = _downloads_in_progress.get(map_id, false)
	var downloaded := _is_map_downloaded(map_id)

	if in_progress:
		_download_button.text = "Downloading…"
		_download_button.disabled = true
		_download_status_label.text = "Downloading…"
		_download_status_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	elif downloaded:
		_download_button.text = "Downloaded"
		_download_button.disabled = true
	else:
		_download_button.text = "Download"
		_download_button.disabled = false

	_preview_button.disabled = not downloaded or in_progress
	_preview_button.tooltip_text = "" if downloaded else "Download this map first to preview it."
	_preview_button.text = "Stop" if _preview_player.playing else "Preview"


func _style_download_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = DesignTokens.COLOR_PINK
	normal.corner_radius_top_left = DesignTokens.CORNER_RADIUS_CONTROL
	normal.corner_radius_top_right = DesignTokens.CORNER_RADIUS_CONTROL
	normal.corner_radius_bottom_right = DesignTokens.CORNER_RADIUS_CONTROL
	normal.corner_radius_bottom_left = DesignTokens.CORNER_RADIUS_CONTROL
	normal.content_margin_left = 24.0
	normal.content_margin_right = 24.0
	normal.content_margin_top = 12.0
	normal.content_margin_bottom = 12.0

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)
	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)
	var disabled := normal.duplicate()
	disabled.bg_color = normal.bg_color.darkened(0.4)

	_download_button.add_theme_stylebox_override("normal", normal)
	_download_button.add_theme_stylebox_override("hover", hover)
	_download_button.add_theme_stylebox_override("pressed", pressed)
	_download_button.add_theme_stylebox_override("disabled", disabled)
	_download_button.add_theme_color_override("font_color", DesignTokens.COLOR_INK)
	_download_button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_INK)
	_download_button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_INK)
	_download_button.add_theme_color_override("font_disabled_color", DesignTokens.COLOR_INK)


# ---------------------------------------------------------------------------
# Preview playback (only ever plays already-downloaded local audio -- see
# header comment for why there's no server-side preview stream).
# ---------------------------------------------------------------------------

func _build_preview_player() -> void:
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = "Music"
	_preview_player.volume_db = PREVIEW_VOLUME_DB
	_preview_player.finished.connect(_on_preview_finished)
	add_child(_preview_player)

	_preview_loop_timer = Timer.new()
	_preview_loop_timer.wait_time = PREVIEW_LOOP_SECONDS
	_preview_loop_timer.timeout.connect(_on_preview_loop_timeout)
	add_child(_preview_loop_timer)


func _on_preview_pressed() -> void:
	if _preview_player.playing:
		_stop_preview()
		_refresh_download_state()
		return

	var map_id := _current_map_id()
	var audio_path := _find_local_audio_path(map_id)
	if audio_path.is_empty():
		return
	var stream := AudioImport.load_audio_file(audio_path)
	if stream == null:
		return

	_preview_loop_timer.stop()
	_preview_start_sec = _find_local_preview_start_sec(map_id)
	_preview_player.stream = stream
	_preview_player.play(_preview_start_sec)
	_preview_loop_timer.start()
	_refresh_download_state()


func _stop_preview() -> void:
	_preview_loop_timer.stop()
	_preview_player.stop()


func _on_preview_loop_timeout() -> void:
	if _preview_player.playing:
		_preview_player.seek(_preview_start_sec)


func _on_preview_finished() -> void:
	if not _preview_loop_timer.is_stopped():
		_preview_player.play(_preview_start_sec)
	_refresh_download_state()


# ---------------------------------------------------------------------------
# Cover art: real cover_url images fetched over HTTP (same request pattern as
# Net.fetch_map_manifest()/download_map()), falling back to the stripe
# placeholder below when a manifest entry has no cover_url or the fetch/
# decode fails (mirrors game/song_select.gd's local-file equivalent).
# ---------------------------------------------------------------------------

func _build_stripe_texture() -> ImageTexture:
	var image := Image.create(COVER_TILE_SIZE, COVER_TILE_SIZE, false, Image.FORMAT_RGBA8)
	var color_a := DesignTokens.COLOR_HAIRLINE
	var color_b := DesignTokens.COLOR_SURFACE_RAISED
	for x in COVER_TILE_SIZE:
		for y in COVER_TILE_SIZE:
			var band := (x + y) % 24
			image.set_pixel(x, y, color_a if band < 12 else color_b)
	return ImageTexture.create_from_image(image)


## Fetches [param url] and calls [param on_texture] with the decoded
## Texture2D, or null on any failure (no network, non-200 response,
## undecodable image) -- callers must fall back to the stripe placeholder,
## never treat a missing/failed cover as fatal. Same HTTPRequest-per-call
## pattern as Net.fetch_map_manifest()/download_map(); cached by URL so a
## cover already seen this session is served straight from
## _cover_texture_cache without another round trip.
func _request_cover_texture(url: String, on_texture: Callable) -> void:
	if url.is_empty():
		on_texture.call(null)
		return
	if _cover_texture_cache.has(url):
		on_texture.call(_cover_texture_cache[url])
		return

	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			request.queue_free()
			var texture := _decode_cover_image(url, result, response_code, body)
			_cover_texture_cache[url] = texture
			on_texture.call(texture)
	)
	var err := request.request(url)
	if err != OK:
		request.queue_free()
		on_texture.call(null)


## Decodes an HTTPRequest response body as an image, picking the decoder by
## [param url]'s extension (defaulting to JPEG, the format every cover this
## project ships uses today). Returns null on any failure rather than
## crashing on a bad response or unsupported format.
func _decode_cover_image(url: String, result: int, response_code: int, body: PackedByteArray) -> Texture2D:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.is_empty():
		return null

	var image := Image.new()
	var err: Error
	match url.get_extension().to_lower():
		"png":
			err = image.load_png_from_buffer(body)
		"webp":
			err = image.load_webp_from_buffer(body)
		_:
			err = image.load_jpg_from_buffer(body)
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


## Builds the cover art itself plus the mockup's scrubber overlay -- a thin
## translucent bar pinned to the cover's bottom edge with a play glyph and a
## progress fill. The mockup shows this as a static 24%-filled bar; here it's
## wired to real preview playback (0% idle, live position while a preview is
## playing) since Preview already exists as a real feature, not decoration.
func _apply_cover_placeholder_style() -> void:
	_detail_cover_rect = TextureRect.new()
	_detail_cover_rect.texture = _stripe_texture
	_detail_cover_rect.stretch_mode = TextureRect.STRETCH_TILE
	_detail_cover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_cover_rect.clip_contents = true
	_detail_cover_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_cover_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_panel.custom_minimum_size = Vector2(0, DETAIL_COVER_HEIGHT)
	_cover_panel.add_child(_detail_cover_rect)
	_cover_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var scrubber_style := StyleBoxFlat.new()
	scrubber_style.bg_color = Color(DesignTokens.COLOR_INK.r, DesignTokens.COLOR_INK.g, DesignTokens.COLOR_INK.b, 0.6)
	scrubber_style.corner_radius_top_left = 8
	scrubber_style.corner_radius_top_right = 8
	scrubber_style.corner_radius_bottom_right = 8
	scrubber_style.corner_radius_bottom_left = 8
	scrubber_style.content_margin_left = 14.0
	scrubber_style.content_margin_right = 14.0

	# CoverPanel is a PanelContainer, which force-fills every child to its
	# content rect and ignores anchors/offsets. A plain Control (not a Container)
	# still gets stretched to fill by the panel, but honours its OWN children's
	# anchors -- so parent the scrubber to this overlay to pin it to the bottom
	# instead of letting the panel stretch it full-height (which parked the play
	# button in the middle of the cover).
	var scrubber_overlay := Control.new()
	scrubber_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_panel.add_child(scrubber_overlay)

	var scrubber := PanelContainer.new()
	scrubber.custom_minimum_size = Vector2(0, 38)
	scrubber.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_KEEP_SIZE)
	scrubber.offset_left = 20
	scrubber.offset_right = -20
	scrubber.offset_bottom = -20
	scrubber.offset_top = scrubber.offset_bottom - 38
	scrubber.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrubber.add_theme_stylebox_override("panel", scrubber_style)
	scrubber_overlay.add_child(scrubber)

	var scrubber_hbox := HBoxContainer.new()
	scrubber_hbox.add_theme_constant_override("separation", 10)
	scrubber.add_child(scrubber_hbox)

	var play_glyph := Label.new()
	play_glyph.text = "▶"
	play_glyph.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	play_glyph.add_theme_font_size_override("font_size", 12)
	scrubber_hbox.add_child(play_glyph)

	var track := PanelContainer.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.custom_minimum_size = Vector2(0, 4)
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = DesignTokens.COLOR_HAIRLINE
	track_style.corner_radius_top_left = 2
	track_style.corner_radius_top_right = 2
	track_style.corner_radius_bottom_right = 2
	track_style.corner_radius_bottom_left = 2
	track.add_theme_stylebox_override("panel", track_style)
	scrubber_hbox.add_child(track)

	_cover_progress_fill = ColorRect.new()
	_cover_progress_fill.color = DesignTokens.COLOR_PINK
	_cover_progress_fill.custom_minimum_size = Vector2(0, 4)
	_cover_progress_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_child(_cover_progress_fill)


func _process(_delta: float) -> void:
	if _cover_progress_fill == null or _preview_player == null:
		return
	if not _preview_player.playing or _preview_player.stream == null:
		_cover_progress_fill.custom_minimum_size.x = 0
		return
	var duration := _preview_player.stream.get_length()
	if duration <= 0.0:
		return
	var fraction := clampf(_preview_player.get_playback_position() / duration, 0.0, 1.0)
	var track_width: float = _cover_progress_fill.get_parent().size.x
	_cover_progress_fill.custom_minimum_size.x = track_width * fraction


# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	if _view_state == ViewState.DETAIL:
		_return_to_grid()
	else:
		_stop_preview()
		SceneRouter.goto_scene("res://ui/main.tscn")


func _display_font() -> Font:
	return load("res://assets/fonts/font_display.tres")


func _mono_font() -> Font:
	return load("res://assets/fonts/font_mono.tres")


func _ui_font() -> Font:
	return load("res://assets/fonts/font_ui.tres")


## First-visit onboarding (ui/components/coach_mark.gd): search -> pick a
## map -> download. The download step has no live target -- Download only
## exists on the detail view, which isn't open yet from the grid -- so it
## centers with no spotlight and names the button in its copy instead. No-op
## if COACH_ID was already recorded seen.
func _maybe_show_coach_marks() -> void:
	if not _has_autoload("SettingsStore") or SettingsStore.has_seen_coach(COACH_ID):
		return
	if _view_state != ViewState.GRID:
		return

	var steps: Array[Dictionary] = [{
		"target": _search_field,
		"title": "Search the community library",
		"body": "Type a title, artist, or mapper to find something to play.",
	}]
	if not _card_panels.is_empty():
		steps.append({
			"target": _card_panels[0],
			"title": "Pick a map",
			"body": "Tap a card to open its details.",
		})
	steps.append({
		"target": null,
		"title": "Download it",
		"body": "On a map's page, press [b]Download[/b]. It'll show up in your Song Select automatically.",
	})

	var coach: Control = preload("res://ui/components/coach_mark.tscn").instantiate()
	add_child(coach)
	coach.finished.connect(func() -> void: SettingsStore.mark_coach_seen(COACH_ID))
	coach.show_sequence(steps)


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
