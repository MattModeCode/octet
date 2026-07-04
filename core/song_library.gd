## Stateless chart-pool scanning and audio-path resolution, shared by
## game/song_select.gd (the list it renders), game/gameplay.gd (real song
## audio, WP-F) and ui/main.gd (home screen ambient music, WP-F). Extracted
## so all three read from exactly one definition of "the available songs"
## instead of drifting apart.
class_name SongLibrary
extends RefCounted

const FIXTURE_DIR: String = "res://tests/fixtures"
const SONGS_DIR: String = "res://songs"
const USER_SONGS_DIR: String = "user://songs"


## Recursively scans FIXTURE_DIR/SONGS_DIR/USER_SONGS_DIR for `.oct` files --
## songs under SONGS_DIR live one level down in a per-song folder (e.g.
## `res://songs/thats-why-i-gave-up-on-music/hard.oct`) alongside their audio
## file, so a flat single-level scan would miss them. Returns each chart as
## {"path": String, "chart": Chart, "mtime": int}.
static func scan_charts() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for dir_path in [FIXTURE_DIR, SONGS_DIR, USER_SONGS_DIR]:
		_scan_recursive(dir_path, entries)
	return entries


static func _scan_recursive(dir_path: String, entries: Array[Dictionary]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name in [".", ".."]:
			file_name = dir.get_next()
			continue
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			_scan_recursive(full_path, entries)
		elif file_name.get_extension() == "oct":
			var chart := OctIO.load_oct(full_path)
			if chart != null:
				var mtime := FileAccess.get_modified_time(full_path)
				entries.append({"path": full_path, "chart": chart, "mtime": mtime})
		file_name = dir.get_next()
	dir.list_dir_end()


## Resolves [param chart]'s audio filename to a loadable path, relative to
## the directory [param chart_path]'s .oct file lives in (ChartAudio.filename's
## documented meaning, core/chart_audio.gd) -- the same rule direct-placement
## songs (WP-C) and the editor's own exports follow. Returns "" if the chart
## has no audio filename or [param chart_path] is empty (e.g. an in-memory
## editor playtest chart, which supplies its own stream instead).
static func resolve_audio_path(chart_path: String, chart: Chart) -> String:
	if chart_path.is_empty() or chart.audio.filename.is_empty():
		return ""
	return chart_path.get_base_dir().path_join(chart.audio.filename)


## Loads [param chart]'s real audio as a playable stream via AudioImport, or
## null if it has no audio filename, the file is missing, or it fails to
## load -- callers are expected to fall back to something else (gameplay's
## metronome, an ambient-music track being skipped) rather than treat this
## as fatal.
static func load_chart_audio(chart_path: String, chart: Chart) -> AudioStream:
	var audio_path := resolve_audio_path(chart_path, chart)
	if audio_path.is_empty() or not FileAccess.file_exists(audio_path):
		return null
	return AudioImport.load_audio_file(audio_path)
