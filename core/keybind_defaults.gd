## Default lane keybindings. PROJECT_BRIEF.md §2.1.
##
## Lane index 0-7 maps left-to-right to the home row (A S D F J K L ;),
## mirrored across both hands. Full rebinding UI is Stage 1 (M0) scope;
## this establishes the tunable default mapping and the InputMap action
## naming convention other systems (input handling, rebind UI) build on.
class_name KeybindDefaults
extends RefCounted

const DEFAULT_LANE_KEYS: Array[String] = ["A", "S", "D", "F", "J", "K", "L", ";"]

## Returns the InputMap action name for a given lane index, e.g. "lane_0".
static func lane_action_name(lane_index: int) -> String:
	return "lane_%d" % lane_index
