extends HBoxContainer
## Reusable segmented pill-tab control (Components mockup "Tabs" section:
## rounded pill row, one tab filled with `accent_color` + ink text when
## selected, the rest transparent with muted text).
##
## Generalizes the hand-rolled toggle-button-group pattern already used
## for Song Select's sort row and the Editor's difficulty tabs (see
## editor/editor_main.gd's comment on why native TabBar's underline style
## doesn't match the pill mockup) -- built the same way (Button +
## ButtonGroup + per-state StyleBoxFlat) but as one instanceable
## component instead of four call sites each redefining it. Existing
## call sites are not migrated by this pass (WP-N); adopt this in
## whichever per-screen WP touches them next.
##
## Pure display + selection signal, no class_name (same convention as
## ui/radial_background.gd) -- instanced as a packed scene.

## Colour used for the selected tab's fill (mockup default: amber, as
## shown on the "Hard" difficulty tab). Song Select's sort row would pass
## a different accent if its selected treatment differs -- caller's call.
@export var accent_color: Color = DesignTokens.COLOR_AMBER
## Font size for tab labels, matches mockup's 12px JetBrains Mono chip text.
@export var font_size: int = 12

signal tab_selected(index: int)

var _labels: PackedStringArray = PackedStringArray()
var _buttons: Array[Button] = []
var _button_group: ButtonGroup
var _selected_index: int = 0


## Rebuilds the tab row from scratch. Call again if the label set changes
## (e.g. a chart's difficulty count changes); selecting the same labels
## repeatedly is cheap enough not to warrant a diffing path here.
func set_tabs(labels: PackedStringArray, selected_index: int = 0) -> void:
	_labels = labels
	_selected_index = clampi(selected_index, 0, max(labels.size() - 1, 0))
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	_button_group = ButtonGroup.new()

	for i in labels.size():
		var button := Button.new()
		button.text = labels[i]
		button.toggle_mode = true
		button.button_group = _button_group
		button.button_pressed = i == _selected_index
		button.add_theme_font_size_override("font_size", font_size)
		_apply_button_style(button, i == _selected_index)
		button.pressed.connect(_on_tab_pressed.bind(i))
		add_child(button)
		_buttons.append(button)


## Selects a tab programmatically (e.g. restoring state) without
## re-emitting `tab_selected`.
func set_selected(index: int) -> void:
	if index < 0 or index >= _buttons.size():
		return
	_selected_index = index
	for i in _buttons.size():
		_buttons[i].button_pressed = i == index
		_apply_button_style(_buttons[i], i == index)


func _on_tab_pressed(index: int) -> void:
	_selected_index = index
	for i in _buttons.size():
		_apply_button_style(_buttons[i], i == index)
	tab_selected.emit(index)


func _apply_button_style(button: Button, active: bool) -> void:
	var style := ComponentStyles.pill_tab(active, accent_color)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", DesignTokens.COLOR_INK if active else DesignTokens.COLOR_TEXT_SECONDARY)
	button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_INK if active else DesignTokens.COLOR_TEXT_SECONDARY)
	button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_INK if active else DesignTokens.COLOR_TEXT_SECONDARY)
