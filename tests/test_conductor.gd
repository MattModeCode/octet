extends RefCounted
class_name TestConductor
## Confirms the Conductor autoload's pure timing math (audio/conductor.gd)
## is correct in isolation, without needing a live AudioStreamPlayer or
## audio device -- headless uses the dummy audio driver, where playback
## position doesn't advance, so these exercise the static functions
## directly via load() rather than the Conductor autoload instance.
##
## Loaded via load() (not a static `Conductor` identifier reference)
## because this is a class_name-declared script: under `godot --headless
## -s`, such scripts are compiled before [autoload] singletons are
## registered, so a static autoload reference would fail to compile. See
## TestRunner.get_autoload() doc comment for the full explanation.

const CONDUCTOR_SCRIPT_PATH: String = "res://audio/conductor.gd"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "conductor_compute_song_time_ms_basic", "callable": test_compute_song_time_ms_basic},
		{"name": "conductor_compute_song_time_ms_zero_offset_zero_latency", "callable": test_compute_song_time_ms_zero_offset_zero_latency},
		{"name": "conductor_judgment_error_ms_late", "callable": test_judgment_error_ms_late},
		{"name": "conductor_judgment_error_ms_early", "callable": test_judgment_error_ms_early},
		{"name": "conductor_judgment_error_ms_on_time_with_input_offset", "callable": test_judgment_error_ms_on_time_with_input_offset},
	]


func test_compute_song_time_ms_basic() -> bool:
	var conductor_script = load(CONDUCTOR_SCRIPT_PATH)
	# 2.0s raw stream position, 20ms output latency, +30ms audio offset:
	# (2.0 - 0.02) * 1000 + 30 = 2010.0ms.
	var result: float = conductor_script.compute_song_time_ms(2.0, 0.02, 30.0)
	var ok := TestRunner._assert(is_equal_approx(result, 2010.0),
		"conductor_compute_song_time_ms_basic: expected 2010.0, got %s" % str(result))
	if ok:
		print("[PASS] conductor_compute_song_time_ms_basic")
	return ok


func test_compute_song_time_ms_zero_offset_zero_latency() -> bool:
	var conductor_script = load(CONDUCTOR_SCRIPT_PATH)
	var result: float = conductor_script.compute_song_time_ms(1.5, 0.0, 0.0)
	var ok := TestRunner._assert(is_equal_approx(result, 1500.0),
		"conductor_compute_song_time_ms_zero_offset_zero_latency: expected 1500.0, got %s" % str(result))
	if ok:
		print("[PASS] conductor_compute_song_time_ms_zero_offset_zero_latency")
	return ok


func test_judgment_error_ms_late() -> bool:
	var conductor_script = load(CONDUCTOR_SCRIPT_PATH)
	# Tap registers 50ms after the note's target -> positive (late).
	var result: float = conductor_script.judgment_error_ms(1050.0, 1000.0, 0.0)
	var ok := TestRunner._assert(is_equal_approx(result, 50.0),
		"conductor_judgment_error_ms_late: expected 50.0, got %s" % str(result))
	if ok:
		print("[PASS] conductor_judgment_error_ms_late")
	return ok


func test_judgment_error_ms_early() -> bool:
	var conductor_script = load(CONDUCTOR_SCRIPT_PATH)
	# Tap registers 50ms before the note's target -> negative (early).
	var result: float = conductor_script.judgment_error_ms(950.0, 1000.0, 0.0)
	var ok := TestRunner._assert(is_equal_approx(result, -50.0),
		"conductor_judgment_error_ms_early: expected -50.0, got %s" % str(result))
	if ok:
		print("[PASS] conductor_judgment_error_ms_early")
	return ok


func test_judgment_error_ms_on_time_with_input_offset() -> bool:
	var conductor_script = load(CONDUCTOR_SCRIPT_PATH)
	# Tap lands exactly on target, but a +10ms input offset is applied
	# (additive, per the sign convention documented on Conductor) -> the
	# corrected error should come out as +10ms, not 0.
	var result: float = conductor_script.judgment_error_ms(1000.0, 1000.0, 10.0)
	var ok := TestRunner._assert(is_equal_approx(result, 10.0),
		"conductor_judgment_error_ms_on_time_with_input_offset: expected 10.0, got %s" % str(result))
	if ok:
		print("[PASS] conductor_judgment_error_ms_on_time_with_input_offset")
	return ok
