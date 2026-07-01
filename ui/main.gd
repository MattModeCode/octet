extends Control
## Stage 0 placeholder main menu. Proves the Octet theme renders per
## DESIGN_BRIEF §6 item 1: logo, primary entry points (Play, Editor,
## Browse maps, Profile), and a quiet ambient beat pulse.
##
## Not final main-menu design — a later stage may revisit this against full
## DESIGN_BRIEF fidelity. The bar here is: loads without error, shows a dark
## Octet-palette background, a wordmark, four working (or gracefully
## erroring) nav buttons, and a subtle pulse.

## Placeholder nav targets. None of these scenes exist yet — they are built
## in later stages. goto_scene() on SceneRouter already guards missing paths
## with a pushed error rather than a crash.
const PLAY_SCENE := "res://game/song_select.tscn"
const EDITOR_SCENE := "res://editor/editor_main.tscn"
const BROWSE_MAPS_SCENE := "res://ui/map_hub.tscn"
const PROFILE_SCENE := "res://ui/profile.tscn"

## Gentle pulse tuning. Kept here (not scattered) per CLAUDE.md — tunables
## belong in config; this is a small enough, purely cosmetic value that it
## lives with the placeholder it drives rather than in a shared config file.
const PULSE_MIN_ALPHA := 0.75
const PULSE_MAX_ALPHA := 1.0
const PULSE_DURATION_SEC := 1.2

@onready var _background: ColorRect = %Background
@onready var _wordmark: Label = %Wordmark
@onready var _play_button: Button = %PlayButton
@onready var _editor_button: Button = %EditorButton
@onready var _browse_maps_button: Button = %BrowseMapsButton
@onready var _profile_button: Button = %ProfileButton

var _pulse_tween: Tween


func _ready() -> void:
	_apply_background_colour()
	_apply_wordmark_colour()
	_wire_buttons()
	_start_ambient_pulse()


func _apply_background_colour() -> void:
	if _has_design_tokens():
		_background.color = DesignTokens.COLOR_INK
	else:
		# Sibling design-tokens autoload not present yet — fall back to the
		# documented Ink hex from DESIGN_BRIEF §2 so this still looks right.
		_background.color = Color.html("#0C0A0F")


func _apply_wordmark_colour() -> void:
	if _has_design_tokens():
		_wordmark.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	else:
		_wordmark.add_theme_color_override("font_color", Color.html("#F5F1F5"))


func _wire_buttons() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_editor_button.pressed.connect(_on_editor_pressed)
	_browse_maps_button.pressed.connect(_on_browse_maps_pressed)
	_profile_button.pressed.connect(_on_profile_pressed)


func _on_play_pressed() -> void:
	_goto(PLAY_SCENE)


func _on_editor_pressed() -> void:
	_goto(EDITOR_SCENE)


func _on_browse_maps_pressed() -> void:
	_goto(BROWSE_MAPS_SCENE)


func _on_profile_pressed() -> void:
	_goto(PROFILE_SCENE)


func _goto(path: String) -> void:
	if _has_autoload("SceneRouter"):
		SceneRouter.goto_scene(path)
	else:
		push_warning("ui/main.gd: SceneRouter autoload not available; cannot navigate to %s" % path)


## Quiet ambient beat pulse on the wordmark: a restrained modulate-alpha
## breathe, nothing flashy. Honours SettingsStore.settings.reduced_motion if
## that autoload exists by integration time; falls back to always-on pulse
## if it doesn't, since it is not a hard dependency of Stage 0.
func _start_ambient_pulse() -> void:
	if _has_autoload("SettingsStore"):
		if "settings" in SettingsStore and SettingsStore.settings != null \
				and "reduced_motion" in SettingsStore.settings \
				and SettingsStore.settings.reduced_motion:
			_wordmark.modulate.a = PULSE_MAX_ALPHA
			return

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_wordmark, "modulate:a", PULSE_MIN_ALPHA, PULSE_DURATION_SEC)
	_pulse_tween.tween_property(_wordmark, "modulate:a", PULSE_MAX_ALPHA, PULSE_DURATION_SEC)


func _has_design_tokens() -> bool:
	return _has_autoload("DesignTokens")


## Defensive autoload lookup so this scene still works standalone (e.g. run
## directly in the editor) even before every autoload exists.
func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
