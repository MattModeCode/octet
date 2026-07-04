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

## Set by game/gameplay.gd's _finish() alongside last_engine -- true when
## that run set a new persisted best (core/score_store.gd, WP-E). Read by
## game/results.gd's NEW BEST badge; gameplay.gd overwrites it on every
## finish, so there's nothing to clear here.
var last_run_is_new_best: bool = false

## Playtest-in-editor bridge (§3.6): editor_main.gd sets these to hand
## gameplay.gd an in-memory Chart/AudioStream directly, bypassing the
## normal load-from-.oct-path and Metronome-backing-track flow (song
## select never sets these). Each is consumed (cleared) the moment
## gameplay.gd reads it, so a later normal play-from-song-select doesn't
## accidentally reuse a stale playtest chart.
var pending_chart: Chart = null
var pending_audio_stream: AudioStream = null

## Set alongside pending_chart/pending_audio_stream when editor_main.gd
## launches a playtest, so game/results.gd's Back button can return to the
## editor instead of the hardcoded Song Select destination once the song
## finishes (the scene stack alone isn't enough -- by the time Results is
## reached the stack's top is gameplay.tscn, not the editor). Cleared by
## song_select.gd before a normal play (so a stale flag from an earlier
## playtest never leaks into an unrelated run) and by results.gd once Back
## consumes it.
var playtest_origin_scene: String = ""


## Returns and clears pending_chart.
func take_pending_chart() -> Chart:
	var chart := pending_chart
	pending_chart = null
	return chart


## Returns and clears pending_audio_stream.
func take_pending_audio_stream() -> AudioStream:
	var stream := pending_audio_stream
	pending_audio_stream = null
	return stream


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
