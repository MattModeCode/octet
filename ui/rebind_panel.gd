extends PanelContainer
## Rebind panel (PROJECT_BRIEF §2.1 -- "key bindings are fully rebindable").
## Builds one row per lane (colour swatch + label + current-key button) from
## LaneInput/DesignTokens, and lets the player click a key button then press
## a new key to rebind it. LaneInput.rebind() rejects a key already used by
## another lane; StatusLabel surfaces that rejection.
##
## Reached from the Settings screen's "Rebind lane keys" button
## (ui/settings.gd) as well as directly, so it keeps working standalone.

@onready var _rows_container: VBoxContainer = %RowsContainer
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton

var _capturing_lane: int = -1
var _key_buttons: Array[Button] = []


func _ready() -> void:
	_build_rows()
	_back_button.pressed.connect(_on_back_pressed)


func _build_rows() -> void:
	for lane in KeybindDefaults.DEFAULT_LANE_KEYS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.color = DesignTokens.lane_color(lane)
		row.add_child(swatch)

		var label := Label.new()
		label.text = "Lane %d" % (lane + 1)
		label.custom_minimum_size = Vector2(100, 0)
		row.add_child(label)

		var key_button := Button.new()
		key_button.text = LaneInput.current_key_string(lane)
		key_button.custom_minimum_size = Vector2(120, 0)
		key_button.pressed.connect(_on_key_button_pressed.bind(lane, key_button))
		row.add_child(key_button)
		_key_buttons.append(key_button)

		_rows_container.add_child(row)


func _on_key_button_pressed(lane: int, button: Button) -> void:
	_capturing_lane = lane
	button.text = "Press a key..."
	_status_label.text = ""


## Captures the next key press while a rebind is pending. Uses
## _unhandled_key_input (rather than the lane_N actions themselves) so
## rebinding works even for a key not currently bound to any lane.
##
## LaneInput.rebind() rejects a key already bound to a different lane (no two
## lanes may share a key) -- on rejection, restore this button's previous
## text and show which lane already owns the key instead of silently
## discarding the keypress.
func _unhandled_key_input(event: InputEvent) -> void:
	if _capturing_lane == -1:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var lane := _capturing_lane
		_capturing_lane = -1
		var key_string := OS.get_keycode_string(event.keycode)
		var conflicting_lane := LaneInput.lane_using_key(key_string, lane)
		if LaneInput.rebind(lane, event.keycode):
			_status_label.text = ""
		else:
			_status_label.text = "\"%s\" is already used by Lane %d" % [key_string, conflicting_lane + 1]
		_key_buttons[lane].text = LaneInput.current_key_string(lane)
		get_viewport().set_input_as_handled()


## This screen was previously a hard trap: it had no Back button and no
## ui_cancel handler, so once reached from the main menu (via the
## non-pushing goto_scene(), which leaves SceneRouter's back-stack empty)
## there was no in-game way to leave it. Skip while a rebind capture is
## pending so Escape can still be bound to a lane, same as any other key.
func _unhandled_input(event: InputEvent) -> void:
	if _capturing_lane != -1:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


## Reached only via ui/settings.gd's "Rebind lane keys" button, which uses
## SceneRouter.goto_scene_pushed() -- so go_back() correctly returns to
## Settings instead of hard-jumping past it to the main menu.
func _on_back_pressed() -> void:
	SceneRouter.go_back()
