extends Node
## EditorSession autoload. Single source of truth for the editor's
## in-memory project state (Stage 5 / M2b): imported audio, shared timing
## points, and one Chart per difficulty tab. editor_main.gd reads/writes
## this directly rather than keeping its own duplicate copies.
##
## Exists as an autoload (not a local editor_main.gd field) for two
## reasons: SceneRouter always destroys and recreates scene instances via
## change_scene_to_file, so anything the "playtest in editor" round trip
## needs to survive has to live outside the scene; and it doubles as the
## autosave/crash-recovery store (§3.6).

const AUTOSAVE_DIR: String = "user://autosave"
const AUTOSAVE_META_PATH: String = "user://autosave/meta.json"

var audio_stream: AudioStream = null
## Where the imported audio came from -- kept for crash recovery (offer to
## re-import the same file) since the AudioStream itself isn't cheap to
## persist to an autosave file, only its decoded-peaks summary is.
var audio_source_path: String = ""
var audio_data: ChartAudio = ChartAudio.new()
var timing_points: Array[TimingPoint] = []
var difficulties: Array[Chart] = []
var active_difficulty_index: int = 0
var waveform_peaks: PackedFloat32Array = PackedFloat32Array()

## Decoded once at import time (editor/audio_import.gd's decode_full_pcm)
## and shared by both the waveform envelope and Stage 6's
## editor/audio_analysis.gd -- decoding a multi-minute song is real work,
## not worth doing twice.
var pcm_samples: PackedFloat32Array = PackedFloat32Array()
var pcm_sample_rate: float = 0.0

## True once the user has hand-typed into the BPM or offset SpinBox since
## the last import. Lets an automatic (post-import) analysis pass tell
## apart "nobody's touched this yet, safe to populate" from "user already
## tuned this by hand, don't clobber it" -- reset to false on each fresh
## import and on any analysis-applied value, since neither of those is a
## user-typed edit.
var bpm_offset_user_edited: bool = false

## Set by editor_main.gd's _on_playtest_pressed() right before routing to
## gameplay, and consumed (cleared) by editor_main.gd's _ready() on the way
## back. Lets _ready() tell apart "the editor scene is being recreated
## because the user just came back from a playtest round trip" (keep the
## in-progress project) from "the editor was freshly opened from the main
## menu" (reset() and show the start overlay) -- SceneRouter always
## destroys/recreates the scene via change_scene_to_file, so this can't
## just be a local editor_main.gd field.
var returning_from_playtest: bool = false


func has_project() -> bool:
	return not difficulties.is_empty()


func active_chart() -> Chart:
	if active_difficulty_index < 0 or active_difficulty_index >= difficulties.size():
		return null
	return difficulties[active_difficulty_index]


func reset() -> void:
	audio_stream = null
	audio_source_path = ""
	audio_data = ChartAudio.new()
	timing_points = []
	difficulties = []
	active_difficulty_index = 0
	waveform_peaks = PackedFloat32Array()
	bpm_offset_user_edited = false


## Copies the shared audio/timing fields onto [param chart] -- call before
## saving/exporting/playtesting so each Chart stays self-contained per the
## locked .oct format, even though the editor treats audio/timing as
## shared across difficulty tabs while editing (§3.6: "multiple
## difficulties per song... sharing the same audio/timing").
func sync_chart_shared_fields(chart: Chart) -> void:
	chart.audio = audio_data
	chart.timing_points = timing_points


## Writes the current session to user://autosave/ -- one .oct per
## difficulty plus a small meta.json (audio_source_path,
## active_difficulty_index). Cheap enough to call after every meaningful
## edit given chart-sized note counts.
func autosave() -> void:
	if difficulties.is_empty():
		return
	if not DirAccess.dir_exists_absolute(AUTOSAVE_DIR):
		DirAccess.make_dir_recursive_absolute(AUTOSAVE_DIR)

	for i in difficulties.size():
		var chart := difficulties[i]
		sync_chart_shared_fields(chart)
		OctIO.save_oct(chart, "%s/chart_%d.oct" % [AUTOSAVE_DIR, i])

	var meta := {
		"audio_source_path": audio_source_path,
		"active_difficulty_index": active_difficulty_index,
		"difficulty_count": difficulties.size(),
	}
	var file := FileAccess.open(AUTOSAVE_META_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(meta, "  "))
		file.close()


static func has_autosave() -> bool:
	return FileAccess.file_exists(AUTOSAVE_META_PATH)


## Restores session state from a previous autosave. Deliberately does NOT
## re-decode audio_source_path automatically -- that's a potentially slow
## operation best left visible/explicit to the user (editor_main.gd offers
## a "re-import" action) rather than silent on scene load. Returns true on
## success.
func load_autosave() -> bool:
	if not has_autosave():
		return false

	var file := FileAccess.open(AUTOSAVE_META_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var parse_err: Error = json.parse(file.get_as_text())
	file.close()
	if parse_err != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var meta: Dictionary = json.data

	var count := int(meta.get("difficulty_count", 0))
	var loaded: Array[Chart] = []
	for i in count:
		var chart := OctIO.load_oct("%s/chart_%d.oct" % [AUTOSAVE_DIR, i])
		if chart != null:
			loaded.append(chart)
	if loaded.is_empty():
		return false

	difficulties = loaded
	timing_points = loaded[0].timing_points
	audio_data = loaded[0].audio
	audio_source_path = String(meta.get("audio_source_path", ""))
	active_difficulty_index = clampi(int(meta.get("active_difficulty_index", 0)), 0, loaded.size() - 1)
	return true
