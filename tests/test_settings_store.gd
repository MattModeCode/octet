extends RefCounted
class_name TestSettingsStore
## Confirms the SettingsStore autoload (core/settings_store.gd) correctly
## applies and persists the fullscreen preference and the Master/Music/SFX
## volume sliders added for the settings screen.
##
## Looked up dynamically via TestRunner.get_autoload("SettingsStore") for the
## same reason as TestLaneInput -- see that file's header comment.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "settings_store_fullscreen_round_trips", "callable": test_fullscreen_round_trips},
		{"name": "settings_store_bus_volume_round_trips_and_clamps", "callable": test_bus_volume_round_trips_and_clamps},
	]


func test_fullscreen_round_trips() -> bool:
	var settings_store = TestRunner.get_autoload("SettingsStore")
	var ok := TestRunner._assert(settings_store != null,
		"settings_store_fullscreen_round_trips: SettingsStore autoload not found")
	if settings_store == null:
		return false

	var original: bool = settings_store.settings.fullscreen

	settings_store.set_fullscreen(false)
	ok = TestRunner._assert(settings_store.settings.fullscreen == false,
		"settings_store_fullscreen_round_trips: expected fullscreen == false after set_fullscreen(false)") and ok

	settings_store.set_fullscreen(true)
	ok = TestRunner._assert(settings_store.settings.fullscreen == true,
		"settings_store_fullscreen_round_trips: expected fullscreen == true after set_fullscreen(true)") and ok

	# Restore whatever was there before this test ran.
	settings_store.set_fullscreen(original)

	if ok:
		print("[PASS] settings_store_fullscreen_round_trips")
	return ok


func test_bus_volume_round_trips_and_clamps() -> bool:
	var settings_store = TestRunner.get_autoload("SettingsStore")
	var ok := TestRunner._assert(settings_store != null,
		"settings_store_bus_volume_round_trips_and_clamps: SettingsStore autoload not found")
	if settings_store == null:
		return false

	var original: float = settings_store.settings.music_volume

	settings_store.set_bus_volume("Music", 0.5)
	ok = TestRunner._assert(is_equal_approx(settings_store.settings.music_volume, 0.5),
		"settings_store_bus_volume_round_trips_and_clamps: expected music_volume == 0.5, got %s" % settings_store.settings.music_volume) and ok

	settings_store.set_bus_volume("Music", 1.5)
	ok = TestRunner._assert(is_equal_approx(settings_store.settings.music_volume, 1.0),
		"settings_store_bus_volume_round_trips_and_clamps: expected 1.5 to clamp to 1.0, got %s" % settings_store.settings.music_volume) and ok

	settings_store.set_bus_volume("Music", -0.5)
	ok = TestRunner._assert(is_equal_approx(settings_store.settings.music_volume, 0.0),
		"settings_store_bus_volume_round_trips_and_clamps: expected -0.5 to clamp to 0.0, got %s" % settings_store.settings.music_volume) and ok

	var bus_index := AudioServer.get_bus_index("Music")
	ok = TestRunner._assert(bus_index != -1,
		"settings_store_bus_volume_round_trips_and_clamps: 'Music' bus not found -- check audio/default_bus_layout.tres") and ok
	if bus_index != -1:
		ok = TestRunner._assert(AudioServer.is_bus_mute(bus_index),
			"settings_store_bus_volume_round_trips_and_clamps: bus should be muted at volume 0.0") and ok

	settings_store.set_bus_volume("Music", original)
	if bus_index != -1:
		ok = TestRunner._assert(not AudioServer.is_bus_mute(bus_index) or original <= 0.0,
			"settings_store_bus_volume_round_trips_and_clamps: bus should be unmuted after restoring original volume") and ok

	if ok:
		print("[PASS] settings_store_bus_volume_round_trips_and_clamps")
	return ok
