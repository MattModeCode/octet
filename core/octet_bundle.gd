## Read/write helpers for .octet bundles (zip archives). PROJECT_BRIEF.md §4.2.
##
## A .octet bundle contains: song.ogg (or .mp3/.wav), one or more
## chart_<difficulty>.oct files, optional cover.jpg/background.jpg, and
## manifest.json (bundle-level metadata, checksums, list of charts).
##
## Full read/write (Stage 5 / M2b) -- cover/background art packing is the
## one piece not yet wired into the editor's export flow (no cover-art
## picker exists), though write_bundle() accepts it via the manifest dict
## if a caller supplies it.
class_name OctetBundle
extends RefCounted


## Opens the zip at `bundle_path`, reads manifest.json from inside it, and
## returns it parsed as a Dictionary. Returns an empty Dictionary (and pushes
## an error) if the bundle or manifest.json is missing or malformed.
static func read_manifest(bundle_path: String) -> Dictionary:
	if not FileAccess.file_exists(bundle_path):
		push_error("OctetBundle.read_manifest: bundle not found: %s" % bundle_path)
		return {}

	var reader := ZIPReader.new()
	var open_err: Error = reader.open(bundle_path)
	if open_err != OK:
		push_error("OctetBundle.read_manifest: failed to open %s as a zip (error %d)" % [bundle_path, open_err])
		return {}

	if not reader.file_exists("manifest.json"):
		push_error("OctetBundle.read_manifest: %s has no manifest.json" % bundle_path)
		reader.close()
		return {}

	var bytes: PackedByteArray = reader.read_file("manifest.json")
	reader.close()

	var text: String = bytes.get_string_from_utf8()
	var json := JSON.new()
	var parse_err: Error = json.parse(text)
	if parse_err != OK:
		push_error("OctetBundle.read_manifest: malformed manifest.json in %s at line %d: %s" % [bundle_path, json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("OctetBundle.read_manifest: manifest.json in %s is not a JSON object" % bundle_path)
		return {}

	return data


## Reads a full .octet bundle back for editing (editor/editor_main.gd's
## "Open existing beatmap" flow) -- the read-side counterpart to
## write_bundle(). Returns a Dictionary
## {"manifest": Dictionary, "charts": Array[Chart], "audio_bytes":
## PackedByteArray, "audio_filename": String}, or an empty Dictionary (with
## a pushed error) on any failure: missing bundle, malformed manifest, a
## chart entry that fails to parse, or a missing audio entry. Chart order
## follows manifest["difficulties"] so the editor's difficulty tabs come
## back in the same order they were saved.
static func read_bundle(bundle_path: String) -> Dictionary:
	var manifest := read_manifest(bundle_path)
	if manifest.is_empty():
		return {}

	var reader := ZIPReader.new()
	var open_err: Error = reader.open(bundle_path)
	if open_err != OK:
		push_error("OctetBundle.read_bundle: failed to open %s as a zip (error %d)" % [bundle_path, open_err])
		return {}

	var audio_filename := String(manifest.get("audio", ""))
	if audio_filename.is_empty() or not reader.file_exists(audio_filename):
		push_error("OctetBundle.read_bundle: %s's manifest references missing audio entry '%s'" % [bundle_path, audio_filename])
		reader.close()
		return {}
	var audio_bytes: PackedByteArray = reader.read_file(audio_filename)

	var charts: Array[Chart] = []
	var difficulty_entries: Array = manifest.get("difficulties", [])
	for entry in difficulty_entries:
		var chart_path := String(entry.get("chartPath", ""))
		if chart_path.is_empty() or not reader.file_exists(chart_path):
			push_error("OctetBundle.read_bundle: %s's manifest references missing chart entry '%s'" % [bundle_path, chart_path])
			continue
		var chart_bytes: PackedByteArray = reader.read_file(chart_path)
		var chart := OctIO.chart_from_json(chart_bytes.get_string_from_utf8())
		if chart != null:
			charts.append(chart)

	reader.close()

	if charts.is_empty():
		push_error("OctetBundle.read_bundle: %s had no readable chart entries" % bundle_path)
		return {}

	return {
		"manifest": manifest,
		"charts": charts,
		"audio_bytes": audio_bytes,
		"audio_filename": audio_filename,
	}


## Writes a full .octet bundle to `bundle_path` (§4.2): the audio file at
## `audio_path` (packed as `song.<original extension>`), one `.oct` entry
## per difficulty in `charts` (packed via OctIO.chart_to_json -- no temp
## files on disk), and `manifest.json` merging the caller-supplied
## `manifest` dict with the computed audio filename, per-difficulty list
## (name/chartPath/starRating/noteCount), and a SHA-256 checksum of the
## packed audio. Cover/background art is not yet part of the editor's
## export flow (no cover-art picker built) -- packed only if the caller
## adds `cover_path`/`background_path` keys to `manifest` (not currently
## done by editor/editor_main.gd).
##
## Returns OK on success, or a Godot Error code on failure (bad bundle
## path, unreadable audio file, etc.) -- never partially writes without
## reporting the failure.
static func write_bundle(bundle_path: String, audio_path: String, charts: Array[Chart], manifest: Dictionary) -> Error:
	var audio_file: FileAccess = FileAccess.open(audio_path, FileAccess.READ)
	if audio_file == null:
		var open_err: Error = FileAccess.get_open_error()
		push_error("OctetBundle.write_bundle: failed to open audio %s (error %d)" % [audio_path, open_err])
		return open_err
	var audio_bytes: PackedByteArray = audio_file.get_buffer(audio_file.get_length())
	audio_file.close()

	var packer := ZIPPacker.new()
	var open_err: Error = packer.open(bundle_path)
	if open_err != OK:
		push_error("OctetBundle.write_bundle: failed to open %s for writing (error %d)" % [bundle_path, open_err])
		return open_err

	var audio_entry_name := "song.%s" % audio_path.get_extension()
	packer.start_file(audio_entry_name)
	packer.write_file(audio_bytes)
	packer.close_file()

	var difficulty_entries: Array = []
	for chart in charts:
		var safe_name := chart.metadata.difficulty_name.to_lower().replace(" ", "_")
		if safe_name.is_empty():
			safe_name = "difficulty"
		var entry_name := "chart_%s.oct" % safe_name
		packer.start_file(entry_name)
		packer.write_file(OctIO.chart_to_json(chart).to_utf8_buffer())
		packer.close_file()
		difficulty_entries.append({
			"name": chart.metadata.difficulty_name,
			"chartPath": entry_name,
			"starRating": chart.metadata.star_rating,
			"noteCount": chart.notes.size(),
		})

	var full_manifest: Dictionary = manifest.duplicate(true)
	full_manifest["audio"] = audio_entry_name
	full_manifest["difficulties"] = difficulty_entries
	full_manifest["audioChecksumSha256"] = _sha256_hex(audio_bytes)

	packer.start_file("manifest.json")
	packer.write_file(JSON.stringify(full_manifest, "  ").to_utf8_buffer())
	packer.close_file()

	return packer.close()


static func _sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
