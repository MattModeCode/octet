extends SceneTree
class_name TestRunner
## Headless test runner. Invoke with:
##   godot --headless -s tests/run_tests.gd
##
## Godot 4's -s/--script flag runs a script extending SceneTree (or
## MainLoop) directly with no scene loaded. Autoloads ARE instantiated and
## live under the SceneTree root by the time _initialize() runs — confirmed
## against Godot 4.7. The real gotcha found in practice: any script with
## class_name gets eagerly compiled into the global class cache before
## [autoload] singletons are registered, so a *static* identifier reference
## to an autoload (e.g. `Config.gameplay`) inside a class_name-declared
## script fails to compile with "Identifier not found". Use get_autoload()
## below for dynamic lookup in any class_name test suite instead.

## One registered test: a human-readable name plus a zero-arg Callable that
## returns bool (true = pass).
class TestCase:
	var name: String
	var callable: Callable

	func _init(p_name: String, p_callable: Callable) -> void:
		name = p_name
		callable = p_callable


var _tests: Array[TestCase] = []

## Strong references to every suite instance, kept alive for the lifetime of
## the run. A Callable bound to a RefCounted object does NOT keep that
## object alive by itself (it resolves the target by ObjectID at call time,
## not a strong ref) — without this array, each suite instance is freed the
## moment _register_all_tests() returns, and every bound test Callable then
## fails with "Attempt to call function ... on a null instance".
var _suites: Array[RefCounted] = []


func _initialize() -> void:
	# Autoload nodes exist under the tree root by _initialize() time, but
	# their _ready() (which is where Config loads its .tres resources) has
	# not run yet — confirmed empirically under Godot 4.7 --headless -s.
	# One process_frame is enough for NOTIFICATION_READY to have fired.
	await process_frame
	_register_all_tests()
	var failures := _run_all_tests()
	quit(1 if failures > 0 else 0)


func _register_all_tests() -> void:
	var oct_io_suite := TestOctIO.new()
	_suites.append(oct_io_suite)
	for entry in oct_io_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var config_suite := TestConfigLoad.new()
	_suites.append(config_suite)
	for entry in config_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var conductor_suite := TestConductor.new()
	_suites.append(conductor_suite)
	for entry in conductor_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var lane_input_suite := TestLaneInput.new()
	_suites.append(lane_input_suite)
	for entry in lane_input_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var settings_store_suite := TestSettingsStore.new()
	_suites.append(settings_store_suite)
	for entry in settings_store_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var gameplay_suite := TestGameplay.new()
	_suites.append(gameplay_suite)
	for entry in gameplay_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var beat_grid_suite := TestBeatGrid.new()
	_suites.append(beat_grid_suite)
	for entry in beat_grid_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var audio_import_suite := TestAudioImport.new()
	_suites.append(audio_import_suite)
	for entry in audio_import_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var note_editor_suite := TestNoteEditor.new()
	_suites.append(note_editor_suite)
	for entry in note_editor_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var undo_stack_suite := TestUndoStack.new()
	_suites.append(undo_stack_suite)
	for entry in undo_stack_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var octet_bundle_suite := TestOctetBundleWrite.new()
	_suites.append(octet_bundle_suite)
	for entry in octet_bundle_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var dsp_fft_suite := TestDspFft.new()
	_suites.append(dsp_fft_suite)
	for entry in dsp_fft_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var audio_analysis_suite := TestAudioAnalysis.new()
	_suites.append(audio_analysis_suite)
	for entry in audio_analysis_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var score_store_suite := TestScoreStore.new()
	_suites.append(score_store_suite)
	for entry in score_store_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))

	var net_client_suite := TestNetClient.new()
	_suites.append(net_client_suite)
	for entry in net_client_suite.get_tests():
		_tests.append(TestCase.new(entry.name, entry.callable))


func _run_all_tests() -> int:
	var pass_count := 0
	var fail_count := 0

	for test in _tests:
		var result = test.callable.call()
		# Tests report their own [PASS]/[FAIL] lines via _assert(); the
		# callable itself returns true only if every assertion in it passed.
		if result:
			pass_count += 1
		else:
			fail_count += 1
			print("[FAIL] %s" % test.name)

	print("")
	print("Ran %d test(s): %d passed, %d failed." % [_tests.size(), pass_count, fail_count])

	return fail_count


## Shared assertion helper for test suites. GDScript has no try/catch, so
## suites call this instead of throwing — it prints and returns false on
## failure rather than halting the run.
static func _assert(cond: bool, msg: String) -> bool:
	if not cond:
		print("[FAIL] %s" % msg)
		return false
	return true


## Dynamic lookup for an autoload singleton by name, e.g. get_autoload("Config").
##
## Confirmed necessary (not the deferral the original doc comment guessed):
## under `godot --headless -s`, any script with `class_name` gets eagerly
## compiled into the global class cache before the [autoload] singletons are
## registered, so a *static* identifier reference like `Config.gameplay` in a
## class_name-declared script fails to compile with "Identifier not found".
## Untyped dynamic lookup via the SceneTree root sidesteps that entirely —
## use this (not a bare `Config` reference) in any class_name test suite.
static func get_autoload(singleton_name: String) -> Object:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(singleton_name)
	return null
