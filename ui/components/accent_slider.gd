extends Control
## Reusable labelled slider (Components mockup "Sliders": header row with
## a muted label + primary-coloured value on the right, a thin track, an
## accent-coloured fill, and a circular grabber). Used for both the pink
## "SCROLL SPEED" and amber "OFFSET" examples in the mockup -- accent
## colour and value formatting are per-instance, everything else shared.
##
## Pure custom-draw for the track/fill/handle (no Font resource needed
## for that part), backed by two real Label nodes for the header row so
## they inherit the project theme's mono font automatically. No
## class_name (same convention as ui/radial_background.gd) -- instanced
## as a packed scene.

@export var label_text: String = "":
	set(v):
		label_text = v
		if is_inside_tree():
			%NameLabel.text = v
@export var accent_color: Color = DesignTokens.COLOR_PINK:
	set(v):
		accent_color = v
		queue_redraw()
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var value: float = 50.0:
	set(v):
		value = clampf(v, min_value, max_value)
		queue_redraw()

signal value_changed(new_value: float)

const _HEADER_HEIGHT: float = 19.0
const _TRACK_Y_OFFSET: float = 8.0
const _TRACK_HEIGHT: float = 6.0
const _HANDLE_RADIUS: float = 8.0

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

var _dragging: bool = false


func _ready() -> void:
	_name_label.text = label_text


## Caller-formatted value text (e.g. "18" or "−12ms") -- kept separate
## from the numeric `value` since the two example sliders in the mockup
## format their values completely differently.
func set_display_value(text: String) -> void:
	_value_label.text = text


func _track_rect() -> Rect2:
	var y := _HEADER_HEIGHT + _TRACK_Y_OFFSET
	return Rect2(0.0, y - _TRACK_HEIGHT / 2.0, size.x, _TRACK_HEIGHT)


func _draw() -> void:
	var track := _track_rect()
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	track_style.set_corner_radius_all(int(_TRACK_HEIGHT / 2.0))
	draw_style_box(track_style, track)

	var fraction := 0.0
	if max_value > min_value:
		fraction = clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
	var fill_width := track.size.x * fraction
	if fill_width > 0.0:
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = accent_color
		fill_style.set_corner_radius_all(int(_TRACK_HEIGHT / 2.0))
		draw_style_box(fill_style, Rect2(track.position, Vector2(fill_width, track.size.y)))

	var handle_x := track.position.x + fill_width
	var handle_y := track.position.y + track.size.y / 2.0
	draw_circle(Vector2(handle_x, handle_y), _HANDLE_RADIUS, DesignTokens.COLOR_TEXT_PRIMARY)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_set_value_from_x(mb.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_value_from_x((event as InputEventMouseMotion).position.x)
		accept_event()


func _set_value_from_x(x: float) -> void:
	if size.x <= 0.0:
		return
	var fraction := clampf(x / size.x, 0.0, 1.0)
	value = min_value + fraction * (max_value - min_value)
	value_changed.emit(value)
