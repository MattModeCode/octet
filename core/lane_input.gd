extends Node
## LaneInput autoload. Owns the InputMap actions "lane_0".."lane_7"
## (PROJECT_BRIEF §2.1) and the rebinding logic behind them, so gameplay
## (the Stage 1 vertical slice and later the full 8-lane play scene) and any
## rebind UI share one source of truth instead of each reading keys
## ad hoc.
##
## Bindings come from SettingsStore.settings.lane_keys if populated, else
## fall back to KeybindDefaults.DEFAULT_LANE_KEYS -- see
## core/settings_config.gd. Must be registered in project.godot AFTER
## SettingsStore, since _ready() reads settings immediately.


func _ready() -> void:
	for lane in KeybindDefaults.DEFAULT_LANE_KEYS.size():
		_register_action(lane, current_key_string(lane))


## Returns the key string (e.g. "A", ";") currently bound to [param lane],
## honouring a saved override before falling back to the default mapping.
func current_key_string(lane: int) -> String:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		var saved: Array = SettingsStore.settings.lane_keys
		if lane >= 0 and lane < saved.size() and not String(saved[lane]).is_empty():
			return saved[lane]
	return KeybindDefaults.DEFAULT_LANE_KEYS[lane]


## Returns the InputMap action name bound to [param lane] -- convenience
## wrapper around KeybindDefaults.lane_action_name for callers that only
## know the lane index.
func binding_for(lane: int) -> String:
	return KeybindDefaults.lane_action_name(lane)


## Rebinds [param lane] to [param keycode] (a Key enum value): updates the
## InputMap action, persists the new binding to SettingsStore, and saves it.
func rebind(lane: int, keycode: Key) -> void:
	var key_string := OS.get_keycode_string(keycode)
	_register_action(lane, key_string)

	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		var keys: Array[String] = SettingsStore.settings.lane_keys.duplicate()
		while keys.size() < KeybindDefaults.DEFAULT_LANE_KEYS.size():
			keys.append("")
		keys[lane] = key_string
		SettingsStore.settings.lane_keys = keys
		SettingsStore.save()


## (Re)creates the InputMap action for [param lane] bound to [param key_string]
## (e.g. "A", ";"), clearing any prior event on that action first so rebinds
## don't stack duplicate bindings.
func _register_action(lane: int, key_string: String) -> void:
	var action_name := KeybindDefaults.lane_action_name(lane)
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)

	var event := InputEventKey.new()
	event.keycode = OS.find_keycode_from_string(key_string)
	InputMap.action_add_event(action_name, event)


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
