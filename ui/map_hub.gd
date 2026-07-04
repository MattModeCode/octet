extends Control
## Map Hub placeholder, visually built from "Octet - Map Hub.dc.html"
## (Claude Design MCP, project cc6f9e35-9183-4b42-8d8a-be6dfc135fe1) per
## CLAUDE.md's design-fidelity rule -- header chrome (title, search field,
## sort/filter chips) matches the mockup's browser view exactly.
##
## Known, explicitly flagged deviation: the mockup's map grid and
## leaderboard show sample community data (Nightfall Circuit, voltessa,
## leaderboard scores, etc.). There is no map-sharing backend yet (Net is a
## hard stub -- see core/score_store.gd's header comment), so this screen
## shows an honest "coming soon" empty state instead of fabricating that
## data, matching main.gd's existing Guest/OFFLINE placeholder convention.
## The search field and sort/filter chips are rendered but inert (disabled)
## for the same reason -- nothing exists yet for them to query.

@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	SceneRouter.goto_scene("res://ui/main.tscn")
