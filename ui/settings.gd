extends Control
## Settings screen -- display/volume/accessibility toggles plus a route into
## the lane rebind panel. Replaces the Main Menu's old "Settings" route,
## which pointed straight at the rebind panel as a placeholder.
##
## No Claude Design MCP mockup exists for this screen (checked project
## cc6f9e35-9183-4b42-8d8a-be6dfc135fe1's file list -- only Main Menu,
## Calibration, Components, Editor, Gameplay HUD, Map Hub, Profile, Results,
## Sign In, Song Select are present), so per CLAUDE.md's design-fidelity rule
## this is built in Octet's established visual language instead, mirroring
## audio/calibration.gd's card layout and "everything applies live, no Save
## step" behaviour rather than inventing a new pattern.
##
## Every control here writes straight through to SettingsStore and persists
## immediately -- same as calibration.gd's _finish_routine() writing
## input_offset_ms as soon as it's measured, with no separate save button.

## Slider range is a 0-100 "percent" UI convention; SettingsConfig stores
## linear 0.0-1.0, so every slider value is divided by 100 before being
## handed to SettingsStore.
const VOLUME_SLIDER_TO_LINEAR: float = 100.0

@onready var _fullscreen_check: CheckButton = %FullscreenCheckButton

@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value_label: Label = %MasterValueLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value_label: Label = %SfxValueLabel

@onready var _reduced_motion_check: CheckButton = %ReducedMotionCheckButton
@onready var _reduced_flash_check: CheckButton = %ReducedFlashCheckButton
@onready var _colourblind_check: CheckButton = %ColourblindCheckButton

@onready var _rebind_button: Button = %RebindButton
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_style_toggle_row_controls()
	_style_sliders()
	_load_initial_state()
	_wire_signals()


## CheckButton's default theme draws a Button-style background box around
## the row; that reads wrong for a settings row (label + inline toggle), so
## the background/border styles are flattened to transparent here and only
## the native on/off switch glyph is left showing. Built at runtime off
## DesignTokens.COLOR_* per this screen's brief -- Theme/.tscn resources
## parse before DesignTokens exists, so baking these as literal Colors in
## the .tscn (like the card StyleBoxFlats) isn't an option here.
func _style_toggle_row_controls() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)

	var check_buttons: Array[CheckButton] = [
		_fullscreen_check, _reduced_motion_check, _reduced_flash_check, _colourblind_check,
	]
	for check_button in check_buttons:
		check_button.add_theme_stylebox_override("normal", transparent)
		check_button.add_theme_stylebox_override("hover", transparent)
		check_button.add_theme_stylebox_override("pressed", transparent)
		check_button.add_theme_stylebox_override("hover_pressed", transparent)
		check_button.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
		check_button.add_theme_color_override("font_hover_color", DesignTokens.COLOR_TEXT_PRIMARY)
		check_button.add_theme_color_override("font_pressed_color", DesignTokens.COLOR_TEXT_PRIMARY)


## Recolours the slider groove/fill to the brand palette (hairline groove,
## pink fill) -- the default Slider theme's grabber icon is left as-is since
## re-skinning it would need a texture asset this screen doesn't have.
func _style_sliders() -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = DesignTokens.COLOR_HAIRLINE
	groove.corner_radius_top_left = 4
	groove.corner_radius_top_right = 4
	groove.corner_radius_bottom_right = 4
	groove.corner_radius_bottom_left = 4
	groove.content_margin_top = 4
	groove.content_margin_bottom = 4

	var fill := StyleBoxFlat.new()
	fill.bg_color = DesignTokens.COLOR_PINK
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_right = 4
	fill.corner_radius_bottom_left = 4
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4

	var sliders: Array[HSlider] = [_master_slider, _music_slider, _sfx_slider]
	for slider in sliders:
		slider.add_theme_stylebox_override("slider", groove)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _load_initial_state() -> void:
	_fullscreen_check.button_pressed = SettingsStore.settings.fullscreen

	_master_slider.value = SettingsStore.settings.master_volume * VOLUME_SLIDER_TO_LINEAR
	_music_slider.value = SettingsStore.settings.music_volume * VOLUME_SLIDER_TO_LINEAR
	_sfx_slider.value = SettingsStore.settings.sfx_volume * VOLUME_SLIDER_TO_LINEAR
	_refresh_volume_label(_master_value_label, _master_slider.value)
	_refresh_volume_label(_music_value_label, _music_slider.value)
	_refresh_volume_label(_sfx_value_label, _sfx_slider.value)

	_reduced_motion_check.button_pressed = SettingsStore.settings.reduced_motion
	_reduced_flash_check.button_pressed = SettingsStore.settings.reduced_flash
	_colourblind_check.button_pressed = SettingsStore.settings.colourblind_mode


func _wire_signals() -> void:
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	_reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	_reduced_flash_check.toggled.connect(_on_reduced_flash_toggled)
	_colourblind_check.toggled.connect(_on_colourblind_toggled)

	_rebind_button.pressed.connect(_on_rebind_pressed)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func _refresh_volume_label(label: Label, slider_value: float) -> void:
	label.text = "%d%%" % roundi(slider_value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsStore.set_fullscreen(pressed)


func _on_master_volume_changed(value: float) -> void:
	_refresh_volume_label(_master_value_label, value)
	SettingsStore.set_bus_volume("Master", value / VOLUME_SLIDER_TO_LINEAR)


func _on_music_volume_changed(value: float) -> void:
	_refresh_volume_label(_music_value_label, value)
	SettingsStore.set_bus_volume("Music", value / VOLUME_SLIDER_TO_LINEAR)


func _on_sfx_volume_changed(value: float) -> void:
	_refresh_volume_label(_sfx_value_label, value)
	SettingsStore.set_bus_volume("SFX", value / VOLUME_SLIDER_TO_LINEAR)


## No dedicated SettingsStore setter exists yet for the three accessibility
## bools -- same pattern audio/calibration.gd uses for offsets: set the
## field directly on the shared SettingsConfig resource, then persist.
func _on_reduced_motion_toggled(pressed: bool) -> void:
	SettingsStore.settings.reduced_motion = pressed
	SettingsStore.save()


func _on_reduced_flash_toggled(pressed: bool) -> void:
	SettingsStore.settings.reduced_flash = pressed
	SettingsStore.save()


func _on_colourblind_toggled(pressed: bool) -> void:
	SettingsStore.settings.colourblind_mode = pressed
	SettingsStore.save()


## Pushed (not a plain goto_scene) so the rebind panel's Back button can
## return here specifically instead of hard-jumping to the main menu.
func _on_rebind_pressed() -> void:
	SceneRouter.goto_scene_pushed("res://ui/rebind_panel.tscn")


## Calibration used to be reached only from Song Select; that button was
## removed (all of Song Select's utility chrome moved to the new Modifiers
## screen or here) so Calibrate now lives in Settings instead. Pushed for
## the same reason as Rebind above -- Calibration's own Back should return
## to Settings, not hard-jump to the main menu.
func _on_calibrate_pressed() -> void:
	SceneRouter.goto_scene_pushed("res://audio/calibration.tscn")


## This screen must not be a navigation trap (same rule ui/rebind_panel.gd
## documents for itself). Settings is normally reached from the main menu
## via SceneRouter.goto_scene() -- the non-pushing variant -- which leaves
## the back-stack empty; go_back() would no-op (with just a warning) in
## that case. Fall back to the main menu directly when there's no history,
## and use go_back() when there is (e.g. after returning to this screen via
## some future pushed route).
func _on_back_pressed() -> void:
	if SceneRouter.scene_stack.is_empty():
		SceneRouter.goto_scene("res://ui/main.tscn")
	else:
		SceneRouter.go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
