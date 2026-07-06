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
		{"name": "lane_input_rebind_rejects_duplicate_key", "callable": test_rebind_rejects_duplicate_key},
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


## Two lanes must never share a key (PROJECT_BRIEF §2.1). Uses lanes 6/7
## (unrelated to test_rebind_swaps_key's lane 0) so ordering between tests
## doesn't matter, and restores both to their defaults afterward.
func test_rebind_rejects_duplicate_key() -> bool:
	var lane_input = TestRunner.get_autoload("LaneInput")
	var ok := TestRunner._assert(lane_input != null,
		"lane_input_rebind_rejects_duplicate_key: LaneInput autoload not found")
	if lane_input == null:
		return false

	# Give lane 6 a known, distinctive key, then try to steal it for lane 7.
	ok = TestRunner._assert(lane_input.rebind(6, KEY_9),
		"lane_input_rebind_rejects_duplicate_key: fixture rebind(6, KEY_9) unexpectedly rejected") and ok

	var accepted: bool = lane_input.rebind(7, KEY_9)
	ok = TestRunner._assert(not accepted,
		"lane_input_rebind_rejects_duplicate_key: rebind(7, KEY_9) should have been rejected (lane 6 already uses it)") and ok

	ok = TestRunner._assert(lane_input.current_key_string(7) == "Semicolon",
		"lane_input_rebind_rejects_duplicate_key: lane_7 should be unchanged (still 'Semicolon') after a rejected rebind, got '%s'" % lane_input.current_key_string(7)) and ok

	ok = TestRunner._assert(lane_input.lane_using_key("9") == 6,
		"lane_input_rebind_rejects_duplicate_key: lane_using_key('9') should return lane 6") and ok
	ok = TestRunner._assert(lane_input.lane_using_key("9", 6) == -1,
		"lane_input_rebind_rejects_duplicate_key: lane_using_key('9', except_lane=6) should return -1") and ok
	ok = TestRunner._assert(lane_input.lane_using_key("ZZZ_NOT_A_KEY") == -1,
		"lane_input_rebind_rejects_duplicate_key: lane_using_key on an unused key string should return -1") and ok

	# Restore lane 6 so this test doesn't leave global state mutated.
	lane_input.rebind(6, KEY_L)

	if ok:
		print("[PASS] lane_input_rebind_rejects_duplicate_key")
	return ok
