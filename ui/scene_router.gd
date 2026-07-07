extends Node
## Small scene-navigation helper used across Octet's screens: main menu
## buttons, editor "back", results "retry/next/back to song select", etc.
##
## Deliberately lightweight — a real state machine isn't needed yet. This is
## a real Stage 0 implementation (not a stub); it will keep being used as-is
## through later stages.

## Simple back-navigation history for goto_scene_pushed()/go_back().
var scene_stack: Array[String] = []

## Change directly to the scene at [param path]. Guards against a bad/missing
## path so a typo or an unbuilt scene during early development pushes a
## warning instead of crashing the game.
##
## This is the "hard jump" variant: it clears scene_stack, since callers use
## it to land on a hub screen (main menu, song select, etc.) with no implied
## way back. Without this, stale entries pushed by an earlier
## goto_scene_pushed() (e.g. song select -> gameplay) would linger past the
## point where the player returned to a hub through some other route, and a
## later unrelated go_back() call (e.g. Settings' Back button) would pop one
## of those stale entries and jump straight back into a finished song instead
## of the previous menu.
func goto_scene(path: String) -> void:
	scene_stack.clear()
	_change_scene(path)

## Change to the scene at [param path], remembering the current scene so
## go_back() can return to it. Use for forward navigation that should be
## reversible (e.g. song select -> results, editor -> playtest).
func goto_scene_pushed(path: String) -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		scene_stack.push_back(current_scene.scene_file_path)
	_change_scene(path)

## Return to the previous scene pushed via goto_scene_pushed(). Does nothing
## (with a warning) if there is no history. Deliberately does not clear the
## rest of scene_stack, so a multi-level push chain (e.g. editor -> gameplay
## -> results) can be unwound one step at a time.
func go_back() -> void:
	if scene_stack.is_empty():
		push_warning("SceneRouter.go_back: no scene history to return to.")
		return
	var previous_path: String = scene_stack.pop_back()
	Sfx.play_back()
	_change_scene(previous_path)

func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter: scene does not exist: %s" % path)
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to change scene to %s (error %d)" % [path, err])
