extends Node
## PlaySession autoload. Small state handoff between song select, gameplay,
## and results -- Godot's change_scene_to_file() (used by SceneRouter) has
## no payload mechanism, so this is where the chosen chart/mods go in, and
## where the finished JudgeEngine comes out. Deliberately a plain data
## holder, not a state machine.

## Chart list assembled by game/song_select.gd (paths to .oct files, in
## display order), and which entry is currently selected. game/results.gd
## uses these two to implement "Next" (advance chart_index, replay).
var chart_list: Array[String] = []
var chart_index: int = -1

## Mods chosen at song select (e.g. No-Fail), applied to the next JudgeEngine.
var mods: GameplayMods = GameplayMods.new()

## Set by game/gameplay.gd when a song finishes; read by game/results.gd.
## A RefCounted autoload reference survives the scene change fine (autoloads
## persist across change_scene_to_file).
var last_engine: JudgeEngine = null


## Path of the chart selected for the *next* play, or "" if none/out of range.
func current_chart_path() -> String:
	if chart_index < 0 or chart_index >= chart_list.size():
		return ""
	return chart_list[chart_index]


## Advances chart_index to the next entry (wrapping), for the results
## screen's "Next" action. Returns the new path, or "" if the list is empty.
func advance_to_next_chart() -> String:
	if chart_list.is_empty():
		return ""
	chart_index = (chart_index + 1) % chart_list.size()
	return current_chart_path()
