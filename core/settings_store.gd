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

	apply_fullscreen()
	apply_volumes()


## Persists the current `settings` to user://settings.tres.
## Returns OK on success, or a Godot Error code on failure.
func save() -> Error:
	return ResourceSaver.save(settings, USER_SETTINGS_PATH)


## Applies settings.fullscreen to the live window. Called on boot (so the
## saved preference takes effect immediately) and by set_fullscreen().
func apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


## Updates the fullscreen preference, applies it to the live window, and
## persists it. Used by the settings screen's Fullscreen toggle.
func set_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	apply_fullscreen()
	save()


## Applies settings.{master,music,sfx}_volume to the corresponding audio
## buses (audio/default_bus_layout.tres). Called on boot.
func apply_volumes() -> void:
	_apply_bus_volume("Master", settings.master_volume)
	_apply_bus_volume("Music", settings.music_volume)
	_apply_bus_volume("SFX", settings.sfx_volume)


## Updates one bus's linear volume (0.0-1.0), applies it live, and persists
## it. Used by the settings screen's volume sliders.
func set_bus_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	match bus_name:
		"Master": settings.master_volume = linear
		"Music": settings.music_volume = linear
		"SFX": settings.sfx_volume = linear
		_:
			push_error("SettingsStore.set_bus_volume: unknown bus '%s'" % bus_name)
			return
	_apply_bus_volume(bus_name, linear)
	save()


## Converts a linear 0.0-1.0 volume to dB and applies it to [param bus_name],
## muting the bus outright at 0 rather than sending -inf dB through
## linear_to_db (which AudioServer already clamps, but muting is the
## explicit, readable way to represent "silent").
func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("SettingsStore._apply_bus_volume: bus '%s' not found -- check audio/default_bus_layout.tres" % bus_name)
		return
	AudioServer.set_bus_mute(bus_index, linear <= 0.0)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))


## True if the player has already dismissed/completed the coach-mark
## sequence identified by [param coach_id] (e.g. "main_intro") -- the
## onboarding gate every first-visit screen checks before showing its
## overlay.
func has_seen_coach(coach_id: String) -> bool:
	return coach_id in settings.seen_coach_marks


## Records that [param coach_id] has been seen (shown to completion or
## explicitly skipped) and persists it immediately, so it never reappears on
## a later launch. No-op if already recorded.
func mark_coach_seen(coach_id: String) -> void:
	if has_seen_coach(coach_id):
		return
	settings.seen_coach_marks.append(coach_id)
	save()
