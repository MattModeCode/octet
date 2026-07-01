extends RefCounted
class_name TestLaneInput
## Confirms the LaneInput autoload (core/lane_input.gd) registers the eight
## lane_N InputMap actions at startup and that rebind() actually swaps the
## bound key. InputMap works headless, so this runs against the live
## LaneInput autoload rather than a static load().
##
## Looked up dynamically via TestRunner.get_autoload("LaneInput") rather
## than a static `LaneInput` identifier -- this is a class_name-declared
## script, and under `godot --headless -s` such scripts compile before
## [autoload] singletons are registered, so a static reference would fail
## to compile. See TestRunner.get_autoload() for the full explanation.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "lane_input_actions_registered", "callable": test_lane_actions_registered},
		{"name": "lane_input_rebind_swaps_key", "callable": test_rebind_swaps_key},
	]


func test_lane_actions_registered() -> bool:
	var lane_input = TestRunner.get_autoload("LaneInput")
	var ok := TestRunner._assert(lane_input != null,
		"lane_input_actions_registered: LaneInput autoload not found")
	if lane_input == null:
		return false

	for lane in 8:
		var action_name := "lane_%d" % lane
		ok = TestRunner._assert(InputMap.has_action(action_name),
			"lane_input_actions_registered: missing action %s" % action_name) and ok
	if ok:
		print("[PASS] lane_input_actions_registered")
	return ok


func test_rebind_swaps_key() -> bool:
	var lane_input = TestRunner.get_autoload("LaneInput")
	var ok := TestRunner._assert(lane_input != null,
		"lane_input_rebind_swaps_key: LaneInput autoload not found")
	if lane_input == null:
		return false

	lane_input.rebind(0, KEY_Z)
	var events := InputMap.action_get_events("lane_0")
	ok = TestRunner._assert(events.size() == 1,
		"lane_input_rebind_swaps_key: expected exactly 1 event on lane_0, got %d" % events.size()) and ok
	if events.size() > 0:
		var event: InputEventKey = events[0]
		ok = TestRunner._assert(event.keycode == KEY_Z,
			"lane_input_rebind_swaps_key: expected KEY_Z, got %s" % str(event.keycode)) and ok

	# Restore the default binding so this test doesn't leave global
	# InputMap/SettingsStore state mutated for whatever runs after it.
	lane_input.rebind(0, KEY_A)

	if ok:
		print("[PASS] lane_input_rebind_swaps_key")
	return ok
