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
func goto_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter.goto_scene: scene does not exist: %s" % path)
		return
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter.goto_scene: failed to change scene to %s (error %d)" % [path, err])

## Change to the scene at [param path], remembering the current scene so
## go_back() can return to it. Use for forward navigation that should be
## reversible (e.g. song select -> results, editor -> playtest).
func goto_scene_pushed(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneRouter.goto_scene_pushed: scene does not exist: %s" % path)
		return
	var current_scene := get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		scene_stack.push_back(current_scene.scene_file_path)
	goto_scene(path)

## Return to the previous scene pushed via goto_scene_pushed(). Does nothing
## (with a warning) if there is no history.
func go_back() -> void:
	if scene_stack.is_empty():
		push_warning("SceneRouter.go_back: no scene history to return to.")
		return
	var previous_path: String = scene_stack.pop_back()
	goto_scene(previous_path)
