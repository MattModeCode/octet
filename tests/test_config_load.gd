extends RefCounted
class_name TestConfigLoad
## Confirms the Config autoload (core/config.gd) actually loaded its .tres
## defaults per PROJECT_BRIEF §2.4 (timing windows) and §2.6 (health
## deltas). Registered into tests/run_tests.gd.
##
## Looks up the Config autoload dynamically via TestRunner.get_autoload()
## rather than referencing the `Config` identifier statically — under
## `godot --headless -s`, class_name-declared scripts (this one included)
## get compiled into the global class cache before [autoload] singletons
## are registered, so a static `Config` reference fails to compile. See
## TestRunner.get_autoload() for the full explanation.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "config_timing_windows_loaded", "callable": test_timing_windows_loaded},
		{"name": "config_health_delta_miss_loaded", "callable": test_health_delta_miss_loaded},
	]


func test_timing_windows_loaded() -> bool:
	var config_autoload = TestRunner.get_autoload("Config")
	var ok := true
	ok = TestRunner._assert(config_autoload != null,
		"config_timing_windows_loaded: Config autoload not found") and ok
	if config_autoload == null:
		return false

	var gameplay = config_autoload.gameplay
	ok = TestRunner._assert(gameplay != null,
		"config_timing_windows_loaded: Config.gameplay is null") and ok
	if gameplay == null:
		return false

	ok = TestRunner._assert(is_equal_approx(gameplay.window_perfect_ms, 25.0),
		"config_timing_windows_loaded: window_perfect_ms expected 25.0, got %s" % str(gameplay.window_perfect_ms)) and ok
	ok = TestRunner._assert(is_equal_approx(gameplay.window_great_ms, 60.0),
		"config_timing_windows_loaded: window_great_ms expected 60.0, got %s" % str(gameplay.window_great_ms)) and ok
	ok = TestRunner._assert(is_equal_approx(gameplay.window_good_ms, 110.0),
		"config_timing_windows_loaded: window_good_ms expected 110.0, got %s" % str(gameplay.window_good_ms)) and ok
	if ok:
		print("[PASS] config_timing_windows_loaded")
	return ok


func test_health_delta_miss_loaded() -> bool:
	var config_autoload = TestRunner.get_autoload("Config")
	var ok := true
	ok = TestRunner._assert(config_autoload != null,
		"config_health_delta_miss_loaded: Config autoload not found") and ok
	if config_autoload == null:
		return false

	var gameplay = config_autoload.gameplay
	ok = TestRunner._assert(gameplay != null,
		"config_health_delta_miss_loaded: Config.gameplay is null") and ok
	if gameplay == null:
		return false

	ok = TestRunner._assert(is_equal_approx(gameplay.health_delta_miss, -6.0),
		"config_health_delta_miss_loaded: expected -6.0, got %s" % str(gameplay.health_delta_miss)) and ok
	if ok:
		print("[PASS] config_health_delta_miss_loaded")
	return ok
