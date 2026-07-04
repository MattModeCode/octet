extends PanelContainer
## Rebind panel foundation (Stage 1 / M0 scope per PROJECT_BRIEF §2.1 --
## "key bindings are fully rebindable"). Builds one row per lane (colour
## swatch + label + current-key button) from LaneInput/DesignTokens, and
## lets the player click a key button then press a new key to rebind it.
##
## This is the rebinding *foundation*, not the final settings screen --
## later stages may fold this into a full settings/calibration surface
## (Stage 3, §2.8) without changing LaneInput's public API.

@onready var _rows_container: VBoxContainer = %RowsContainer
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


## Captures the next key press while a rebind is pending. Uses
## _unhandled_key_input (rather than the lane_N actions themselves) so
## rebinding works even for a key not currently bound to any lane.
func _unhandled_key_input(event: InputEvent) -> void:
	if _capturing_lane == -1:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var lane := _capturing_lane
		_capturing_lane = -1
		LaneInput.rebind(lane, event.keycode)
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


func _on_back_pressed() -> void:
	SceneRouter.goto_scene("res://ui/main.tscn")
