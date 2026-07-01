## Stateless JSON (de)serialization for the .oct chart format.
## PROJECT_BRIEF.md §4.1 — the JSON key names/shape here are locked to the
## brief's example; do not rename or restructure without updating the brief.
class_name OctIO
extends RefCounted


## Reads and parses the .oct file at `path`, returning a populated Chart.
## Returns null (and pushes an error) on a missing file or malformed JSON —
## never crashes on bad input.
static func load_oct(path: String) -> Chart:
	if not FileAccess.file_exists(path):
		push_error("OctIO.load_oct: file not found: %s" % path)
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("OctIO.load_oct: failed to open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		push_error("OctIO.load_oct: malformed JSON in %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("OctIO.load_oct: root of %s is not a JSON object" % path)
		return null

	return _dict_to_chart(data)


## Serializes `chart` to the .oct JSON text -- the same shape save_oct()
## writes to disk, exposed as a string for callers that need the bytes
## without a file round-trip (e.g. OctetBundle.write_bundle packing a
## chart directly into a zip entry).
static func chart_to_json(chart: Chart) -> String:
	return JSON.stringify(_chart_to_dict(chart), "  ")


## Serializes `chart` to the .oct JSON shape and writes it to `path`.
## Returns OK on success, or a Godot Error code on failure.
static func save_oct(chart: Chart, path: String) -> Error:
	if chart == null:
		push_error("OctIO.save_oct: chart is null")
		return ERR_INVALID_PARAMETER

	var text: String = chart_to_json(chart)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err: Error = FileAccess.get_open_error()
		push_error("OctIO.save_oct: failed to open %s for writing (error %d)" % [path, err])
		return err

	file.store_string(text)
	file.close()
	return OK


## -- internal: Dictionary (parsed JSON) -> Chart -----------------------------

static func _dict_to_chart(data: Dictionary) -> Chart:
	var chart := Chart.new()
	chart.format_version = int(data.get("format_version", 1))

	var meta_dict: Dictionary = data.get("metadata", {})
	chart.metadata = _dict_to_metadata(meta_dict)

	var audio_dict: Dictionary = data.get("audio", {})
	chart.audio = _dict_to_audio(audio_dict)

	var timing_points: Array[TimingPoint] = []
	for tp_raw in data.get("timing_points", []):
		var tp_dict: Dictionary = tp_raw
		var tp := TimingPoint.new()
		tp.time_ms = int(tp_dict.get("time_ms", 0))
		tp.bpm = float(tp_dict.get("bpm", 120.0))
		tp.meter = int(tp_dict.get("meter", 4))
		timing_points.append(tp)
	chart.timing_points = timing_points

	var notes: Array[ChartNote] = []
	for note_raw in data.get("notes", []):
		var note_dict: Dictionary = note_raw
		var note := ChartNote.new()
		note.lane = int(note_dict.get("lane", 0))
		note.time_ms = int(note_dict.get("time_ms", 0))
		note.type = String(note_dict.get("type", "tap"))
		# end_time_ms is only present in the JSON for hold notes; default to
		# -1 (unset) when absent, e.g. for taps.
		note.end_time_ms = int(note_dict.get("end_time_ms", -1))
		notes.append(note)
	chart.notes = notes

	return chart


static func _dict_to_metadata(meta_dict: Dictionary) -> ChartMetadata:
	var metadata := ChartMetadata.new()
	metadata.title = String(meta_dict.get("title", ""))
	metadata.artist = String(meta_dict.get("artist", ""))
	metadata.mapper = String(meta_dict.get("mapper", ""))
	metadata.difficulty_name = String(meta_dict.get("difficulty_name", ""))
	metadata.star_rating = float(meta_dict.get("star_rating", 0.0))

	var tags: PackedStringArray = []
	for tag in meta_dict.get("tags", []):
		tags.append(String(tag))
	metadata.tags = tags

	metadata.preview_time_ms = int(meta_dict.get("preview_time_ms", 0))
	return metadata


static func _dict_to_audio(audio_dict: Dictionary) -> ChartAudio:
	var audio := ChartAudio.new()
	audio.filename = String(audio_dict.get("filename", ""))
	audio.duration_ms = int(audio_dict.get("duration_ms", 0))
	return audio


## -- internal: Chart -> Dictionary (for JSON.stringify) ----------------------

static func _chart_to_dict(chart: Chart) -> Dictionary:
	var timing_points: Array = []
	for tp in chart.timing_points:
		timing_points.append({
			"time_ms": tp.time_ms,
			"bpm": tp.bpm,
			"meter": tp.meter,
		})

	var notes: Array = []
	for note in chart.notes:
		var note_dict: Dictionary = {
			"lane": note.lane,
			"time_ms": note.time_ms,
			"type": note.type,
		}
		# Only emit end_time_ms for holds, matching the brief's example where
		# tap notes omit the key entirely.
		if note.type == "hold":
			note_dict["end_time_ms"] = note.end_time_ms
		notes.append(note_dict)

	return {
		"format_version": chart.format_version,
		"metadata": {
			"title": chart.metadata.title,
			"artist": chart.metadata.artist,
			"mapper": chart.metadata.mapper,
			"difficulty_name": chart.metadata.difficulty_name,
			"star_rating": chart.metadata.star_rating,
			"tags": Array(chart.metadata.tags),
			"preview_time_ms": chart.metadata.preview_time_ms,
		},
		"audio": {
			"filename": chart.audio.filename,
			"duration_ms": chart.audio.duration_ms,
		},
		"timing_points": timing_points,
		"notes": notes,
	}
