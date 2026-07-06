extends Control
## Modifiers screen -- consolidates every run-modifying toggle into one
## place, reached from game/song_select.gd's ModifiersButton. Replaces the
## old lone No-Fail checkbox on Song Select; adds Double/Half speed, Easy
## (wider hit windows), Sudden Death (fail on the first miss), and Autopilot
## (perfect auto-play, badged in game/gameplay.gd/.tscn).
##
## Session-only, same handoff as every other pre-gameplay setting: reads
## the current PlaySession.mods on entry, writes straight back to it live on
## every change (no Save step, no SettingsConfig persistence -- mods reset
## to vanilla on a fresh launch). Built in Octet's established visual
## language, mirroring ui/settings.tscn's card/spacing conventions -- no
## Claude Design MCP mockup exists for this screen (see modifiers.tscn's
## header comment).
##
## Modifier conflicts:
## - Double/Half/1x speed share a Godot ButtonGroup (radio behaviour), so
##   they're structurally mutually exclusive -- only one can ever be
##   pressed, no manual bookkeeping needed.
## - No-Fail and Sudden Death are opposite philosophies (never fail vs. fail
##   on the first miss) -- turning one on forces the other off.
## - Autopilot plays every note perfectly, so failing is moot -- turning it
##   on disables (greys out) No-Fail and Sudden Death without changing their
##   underlying values, and re-enables them if Autopilot is turned back off.

@onready var _half_button: Button = %HalfButton
@onready var _normal_button: Button = %NormalButton
@onready var _double_button: Button = %DoubleButton

@onready var _easy_check: CheckButton = %EasyCheckButton
@onready var _autopilot_check: CheckButton = %AutopilotCheckButton
@onready var _sudden_death_check: CheckButton = %SuddenDeathCheckButton
@onready var _no_fail_check: CheckButton = %NoFailCheckButton

@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_style_toggle_row_controls()
	_load_initial_state()
	_wire_signals()


## Same flattening idiom as ui/settings.gd's _style_toggle_row_controls():
## CheckButton's default theme draws a Button-style background box around
## the row, which reads wrong for a settings-style label + inline toggle
## row. Built at runtime off DesignTokens.COLOR_* since Theme/.tscn
## resources parse before the DesignTokens autoload exists.
func _style_toggle_row_controls() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)

	var check_buttons: Array[CheckButton] = [
		_easy_check, _autopilot_check, _sudden_death_check, _no_fail_check,
	]
	for check_button in check_buttons:
		check_button.add_theme_stylebox_override("normal", transparent)
		check_button.add_theme_stylebox_override("hover", transparent)
		check_button.add_theme_stylebox_override("pressed", transparent)
		check_button.add_theme_stylebox_override("hover_pressed", transparent)
		check_button.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
		check_button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_PRIMARY)
		check_button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_TEXT_PRIMARY)


func _load_initial_state() -> void:
	var mods := PlaySession.mods

	if is_equal_approx(mods.rate, GameplayMods.RATE_HALF):
		_half_button.button_pressed = true
	elif is_equal_approx(mods.rate, GameplayMods.RATE_DOUBLE):
		_double_button.button_pressed = true
	else:
		_normal_button.button_pressed = true

	_easy_check.button_pressed = not is_equal_approx(mods.window_scale, 1.0)
	_autopilot_check.button_pressed = mods.autoplay
	_sudden_death_check.button_pressed = mods.sudden_death
	_no_fail_check.button_pressed = mods.no_fail

	_update_autoplay_conflicts(mods.autoplay)


func _wire_signals() -> void:
	_half_button.toggled.connect(_on_half_toggled)
	_normal_button.toggled.connect(_on_normal_toggled)
	_double_button.toggled.connect(_on_double_toggled)

	_easy_check.toggled.connect(_on_easy_toggled)
	_autopilot_check.toggled.connect(_on_autopilot_toggled)
	_sudden_death_check.toggled.connect(_on_sudden_death_toggled)
	_no_fail_check.toggled.connect(_on_no_fail_toggled)

	_back_button.pressed.connect(_on_back_pressed)


## Each speed button's ButtonGroup membership means Godot also emits a
## toggled(false) for whichever button was previously pressed -- only act
## on the toggled(true) call for the newly-selected one.
func _on_half_toggled(pressed: bool) -> void:
	if pressed:
		PlaySession.mods.rate = GameplayMods.RATE_HALF


func _on_normal_toggled(pressed: bool) -> void:
	if pressed:
		PlaySession.mods.rate = GameplayMods.RATE_NORMAL


func _on_double_toggled(pressed: bool) -> void:
	if pressed:
		PlaySession.mods.rate = GameplayMods.RATE_DOUBLE


func _on_easy_toggled(pressed: bool) -> void:
	PlaySession.mods.window_scale = GameplayMods.EASY_WINDOW_SCALE if pressed else 1.0


func _on_autopilot_toggled(pressed: bool) -> void:
	PlaySession.mods.autoplay = pressed
	_update_autoplay_conflicts(pressed)


## No-Fail and Sudden Death are mutually exclusive -- forcing the other off
## via set_pressed_no_signal() (not button_pressed =) so this doesn't
## recursively re-enter the other handler; the mod field is set directly
## alongside instead.
func _on_sudden_death_toggled(pressed: bool) -> void:
	PlaySession.mods.sudden_death = pressed
	if pressed:
		PlaySession.mods.no_fail = false
		_no_fail_check.set_pressed_no_signal(false)


func _on_no_fail_toggled(pressed: bool) -> void:
	PlaySession.mods.no_fail = pressed
	if pressed:
		PlaySession.mods.sudden_death = false
		_sudden_death_check.set_pressed_no_signal(false)


## Autopilot makes fail-state mods moot (every note is auto-hit perfectly,
## so nothing can ever miss) -- grey the two out while it's on rather than
## changing their underlying values, so a player's prior choice is restored
## the moment Autopilot is switched back off.
func _update_autoplay_conflicts(autoplay_on: bool) -> void:
	_no_fail_check.disabled = autoplay_on
	_sudden_death_check.disabled = autoplay_on


## Same empty-stack guard as ui/settings.gd's _on_back_pressed(): reached
## via the pushed route from Song Select, so go_back() is the normal path,
## but fall back home if this screen is ever entered with an empty stack.
func _on_back_pressed() -> void:
	if SceneRouter.scene_stack.is_empty():
		SceneRouter.goto_scene("res://ui/main.tscn")
	else:
		SceneRouter.go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
