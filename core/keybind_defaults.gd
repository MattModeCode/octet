## Default lane keybindings. PROJECT_BRIEF.md §2.1.
##
## Lane index 0-7 maps left-to-right to the home row (A S D F J K L ;),
## mirrored across both hands. Full rebinding UI is Stage 1 (M0) scope;
## this establishes the tunable default mapping and the InputMap action
## naming convention other systems (input handling, rebind UI) build on.
class_name KeybindDefaults
extends RefCounted

## "Semicolon" (not ";") -- OS.find_keycode_from_string only recognizes
## Godot's canonical keycode names, and ";" doesn't resolve (returns
## KEY_NONE), which silently left lane 7 unbound. "Semicolon" round-trips
## correctly and matches what OS.get_keycode_string(KEY_SEMICOLON) itself
## returns, so it's also what rebind() would store if a player pressed this
## key to rebind any lane.
const DEFAULT_LANE_KEYS: Array[String] = ["A", "S", "D", "F", "J", "K", "L", "Semicolon"]

## Returns the InputMap action name for a given lane index, e.g. "lane_0".
static func lane_action_name(lane_index: int) -> String:
	return "lane_%d" % lane_index
