## SettingsStore autoload. Holds PER-MACHINE / per-player settings
## (SettingsConfig — scroll speed, calibration offsets, accessibility
## toggles) that persist across launches, unlike the static tuning data in
## the Config autoload.
##
## On startup, loads a saved settings resource from user://settings.tres.
## If none exists yet, instantiates a fresh SettingsConfig using
## config/settings.tres as the default template and saves it immediately.
##
## The calibration screen (later stage) writes audio_offset_ms /
## input_offset_ms here; accessibility toggles read/write here too.
extends Node

const DEFAULT_SETTINGS_TEMPLATE_PATH: String = "res://config/settings.tres"
const USER_SETTINGS_PATH: String = "user://settings.tres"

var settings: SettingsConfig


func _ready() -> void:
	if ResourceLoader.exists(USER_SETTINGS_PATH):
		var loaded: Resource = ResourceLoader.load(USER_SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		settings = loaded as SettingsConfig

	if settings == null:
		var template: SettingsConfig = load(DEFAULT_SETTINGS_TEMPLATE_PATH) as SettingsConfig
		settings = template.duplicate() if template != null else SettingsConfig.new()
		save()


## Persists the current `settings` to user://settings.tres.
## Returns OK on success, or a Godot Error code on failure.
func save() -> Error:
	return ResourceSaver.save(settings, USER_SETTINGS_PATH)
