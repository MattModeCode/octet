extends Control
## Component sheet demo harness (WP-N, docs/FEATURE_FIXES_BREAKDOWN.md).
##
## Runnable proof that the shared ui/components/ primitives + the
## assets/theme/octet_theme.tres additions match the live
## "Octet - Components.dc.html" mockup: buttons (primary/secondary/
## ghost/destructive incl. disabled), inputs/dropdowns, pill tabs,
## sliders, cards, health bar, note skins, judgment popups. Built
## entirely in code (same convention as game/song_select.gd's chip rows
## and editor/editor_main.gd's tool rail) rather than hand-authored as a
## large static .tscn.
##
## Run this scene directly (F6 in the editor, or
## `godot --path . res://ui/components/component_sheet.tscn`) to see
## every component/state side by side with the mockup.

const PILL_TAB_BAR := preload("res://ui/components/pill_tab_bar.tscn")
const ACCENT_SLIDER := preload("res://ui/components/accent_slider.tscn")
const HEALTH_BAR := preload("res://ui/components/health_bar.tscn")
const NOTE_SKIN_PREVIEW := preload("res://ui/components/note_skin_preview.tscn")
const NoteSkinScript := preload("res://ui/components/note_skin_preview.gd")

const FONT_DISPLAY := preload("res://assets/fonts/font_display.tres")
const FONT_MONO := preload("res://assets/fonts/font_mono.tres")
const FONT_MONO_BOLD := preload("res://assets/fonts/font_mono_bold.tres")
const FONT_UI := preload("res://assets/fonts/font_ui.tres")

var _root: VBoxContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = DesignTokens.COLOR_INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 0)
	_root.custom_minimum_size = Vector2(1200, 0)
	_root.add_theme_constant_override("margin", 0)
	scroll.add_child(_root)

	_build_header()
	_build_buttons_section()
	_build_inputs_section()
	_build_tabs_and_sliders_section()
	_build_cards_section()
	_build_health_bar_section()
	_build_note_skins_section()
	_build_judgment_popups_section()


func _build_header() -> void:
	var tag := Label.new()
	tag.text = "OCTET"
	tag.add_theme_font_override("font", FONT_MONO_BOLD)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", DesignTokens.COLOR_PINK)
	tag.add_theme_constant_override("outline_size", 0)
	_root.add_child(tag)
	_add_spacer(10.0)

	var title := Label.new()
	title.text = "Component sheet"
	title.add_theme_font_override("font", FONT_DISPLAY)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	_root.add_child(title)
	_add_spacer(40.0)


func _section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_DISPLAY)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	_root.add_child(label)
	_add_spacer(16.0)


func _add_spacer(pixels: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, pixels)
	_root.add_child(spacer)


func _row(separation: int = 20) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	_root.add_child(row)
	return row


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _build_buttons_section() -> void:
	_section_header("Buttons")
	var row := _row()

	row.add_child(_make_button("Primary", "PrimaryButton"))
	row.add_child(_make_button("Primary · disabled", "PrimaryButton", true))
	row.add_child(_make_button("Secondary", "SecondaryButton"))
	row.add_child(_make_button("Ghost", "GhostButton"))
	row.add_child(_make_button("Destructive", "DestructiveButton"))

	var hint := Label.new()
	hint.text = "Hover/press/focus each button above to see its live state (matches the mockup's static hover/disabled swatches)."
	hint.add_theme_font_override("font", FONT_UI)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	_root.add_child(hint)
	_add_spacer(56.0)


func _make_button(text: String, variation: StringName, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.disabled = disabled
	return button


# ---------------------------------------------------------------------------
# Inputs & dropdowns
# ---------------------------------------------------------------------------

func _build_inputs_section() -> void:
	_section_header("Inputs & dropdowns")
	var row := _row()

	row.add_child(_labelled_field("TEXT INPUT", _make_line_edit("Nightfall Circuit")))

	var dropdown := OptionButton.new()
	dropdown.custom_minimum_size = Vector2(280, 0)
	dropdown.add_item("Sort: Top rated")
	dropdown.add_item("Sort: Newest")
	dropdown.add_item("Sort: Most played")
	row.add_child(_labelled_field("DROPDOWN", dropdown))

	var locked := _make_line_edit("Locked field")
	locked.editable = false
	row.add_child(_labelled_field("DISABLED", locked))
	_add_spacer(56.0)


func _make_line_edit(text: String) -> LineEdit:
	var line_edit := LineEdit.new()
	line_edit.text = text
	line_edit.custom_minimum_size = Vector2(280, 0)
	return line_edit


func _labelled_field(label_text: String, field: Control) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", FONT_MONO_BOLD)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	container.add_child(label)
	container.add_child(field)
	return container


# ---------------------------------------------------------------------------
# Tabs & sliders
# ---------------------------------------------------------------------------

func _build_tabs_and_sliders_section() -> void:
	var row := _row(64)

	var tabs_col := VBoxContainer.new()
	tabs_col.add_theme_constant_override("separation", 20)
	var tabs_header := Label.new()
	tabs_header.text = "Tabs"
	tabs_header.add_theme_font_override("font", FONT_DISPLAY)
	tabs_header.add_theme_font_size_override("font_size", 20)
	tabs_header.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	tabs_col.add_child(tabs_header)
	var tab_bar := PILL_TAB_BAR.instantiate()
	tabs_col.add_child(tab_bar)
	row.add_child(tabs_col)
	tab_bar.set_tabs(PackedStringArray(["Hard", "Normal", "Expert"]), 0)

	var sliders_col := VBoxContainer.new()
	sliders_col.add_theme_constant_override("separation", 20)
	var sliders_header := Label.new()
	sliders_header.text = "Sliders"
	sliders_header.add_theme_font_override("font", FONT_DISPLAY)
	sliders_header.add_theme_font_size_override("font_size", 20)
	sliders_header.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	sliders_col.add_child(sliders_header)

	var scroll_speed := ACCENT_SLIDER.instantiate()
	sliders_col.add_child(scroll_speed)
	var offset_slider := ACCENT_SLIDER.instantiate()
	sliders_col.add_child(offset_slider)
	row.add_child(sliders_col)

	# Configured only after entering the tree, so each slider's @onready
	# label references (%NameLabel/%ValueLabel) are already resolved.
	scroll_speed.label_text = "SCROLL SPEED"
	scroll_speed.accent_color = DesignTokens.COLOR_PINK
	scroll_speed.min_value = 1.0
	scroll_speed.max_value = 30.0
	scroll_speed.value = 18.0
	scroll_speed.set_display_value("18")
	scroll_speed.value_changed.connect(func(v: float) -> void: scroll_speed.set_display_value(str(int(round(v)))))

	offset_slider.label_text = "OFFSET"
	offset_slider.accent_color = DesignTokens.COLOR_AMBER
	offset_slider.min_value = -50.0
	offset_slider.max_value = 50.0
	offset_slider.value = -12.0
	offset_slider.set_display_value("-12ms")
	offset_slider.value_changed.connect(func(v: float) -> void: offset_slider.set_display_value("%dms" % int(round(v))))

	_add_spacer(56.0)


# ---------------------------------------------------------------------------
# Cards
# ---------------------------------------------------------------------------

func _build_cards_section() -> void:
	_section_header("Cards")
	var row := _row()

	row.add_child(_make_map_card("Map card", "by mapper", false))
	row.add_child(_make_map_card("Selected state", "by mapper", true))
	row.add_child(_make_stat_card("STAT CARD", "98.42%"))
	_add_spacer(56.0)


func _make_map_card(title: String, subtitle: String, selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	if selected:
		panel.theme_type_variation = &"CardSelected"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var cover := ColorRect.new()
	cover.custom_minimum_size = Vector2(0, 110)
	cover.color = DesignTokens.COLOR_SURFACE_RAISED
	vbox.add_child(cover)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", FONT_DISPLAY)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	vbox.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_override("font", FONT_UI)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	vbox.add_child(subtitle_label)

	panel.add_child(vbox)
	return panel


func _make_stat_card(label_text: String, value_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"StatCard"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", FONT_MONO_BOLD)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	vbox.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_override("font", FONT_MONO_BOLD)
	value.add_theme_font_size_override("font_size", 30)
	value.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	vbox.add_child(value)

	panel.add_child(vbox)
	return panel


# ---------------------------------------------------------------------------
# Health bar
# ---------------------------------------------------------------------------

func _build_health_bar_section() -> void:
	_section_header("Health bar")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(500, 0)

	var healthy := HEALTH_BAR.instantiate()
	col.add_child(healthy)
	healthy.value01 = 0.82

	var low := HEALTH_BAR.instantiate()
	col.add_child(low)
	low.value01 = 0.22

	_root.add_child(col)
	_add_spacer(56.0)


# ---------------------------------------------------------------------------
# Note skins
# ---------------------------------------------------------------------------

func _build_note_skins_section() -> void:
	_section_header("Note skins")
	var caption := Label.new()
	caption.text = "Tap = circle · Hold = circle + tail · Chord = simultaneous taps across lanes. States: idle, hit, missed."
	caption.add_theme_font_override("font", FONT_UI)
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_SECONDARY)
	_root.add_child(caption)
	_add_spacer(22.0)

	var row := _row()
	row.add_child(_make_note_lane_card("ORCHID · A / ;", DesignTokens.LANE_COLOR_ORCHID, NoteSkinScript.State.MISSED))
	row.add_child(_make_note_lane_card("OCTET PINK · S / L", DesignTokens.LANE_COLOR_PINK, NoteSkinScript.State.HIT_BURST))
	row.add_child(_make_note_lane_card("CORAL · D / K", DesignTokens.LANE_COLOR_CORAL, NoteSkinScript.State.MISSED))
	row.add_child(_make_note_lane_card("AMBER · F / J", DesignTokens.LANE_COLOR_AMBER, NoteSkinScript.State.MISSED))
	_add_spacer(56.0)


func _make_note_lane_card(label_text: String, lane_color: Color, third_state: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", FONT_MONO_BOLD)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", lane_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 16)
	swatches.alignment = BoxContainer.ALIGNMENT_END

	swatches.add_child(_make_note_swatch("TAP", lane_color, NoteSkinScript.State.TAP, Vector2(56, 56)))
	swatches.add_child(_make_note_swatch("HOLD", lane_color, NoteSkinScript.State.HOLD, Vector2(56, 110)))
	var third_label := "HIT / BURST" if third_state == NoteSkinScript.State.HIT_BURST else "MISSED"
	swatches.add_child(_make_note_swatch(third_label, lane_color, third_state, Vector2(56, 56)))

	vbox.add_child(swatches)
	panel.add_child(vbox)
	return panel


func _make_note_swatch(caption_text: String, lane_color: Color, state: int, box_size: Vector2) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var preview := NOTE_SKIN_PREVIEW.instantiate()
	preview.custom_minimum_size = box_size
	vbox.add_child(preview)
	preview.lane_color = lane_color
	preview.state = state

	var caption := Label.new()
	caption.text = caption_text
	caption.add_theme_font_override("font", FONT_MONO)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(caption)
	return vbox


# ---------------------------------------------------------------------------
# Judgment popups
# ---------------------------------------------------------------------------

func _build_judgment_popups_section() -> void:
	_section_header("Judgment popups")
	var row := _row(36)
	row.add_child(_make_judgment_label("PERFECT", DesignTokens.COLOR_PERFECT_FLASH))
	row.add_child(_make_judgment_label("GREAT", DesignTokens.COLOR_AMBER))
	row.add_child(_make_judgment_label("GOOD", DesignTokens.LANE_COLOR_CORAL))
	row.add_child(_make_judgment_label("MISS", DesignTokens.COLOR_MISS))
	_add_spacer(40.0)


func _make_judgment_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT_DISPLAY)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	return label
