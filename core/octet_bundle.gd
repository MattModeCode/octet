## Read/write helpers for .octet bundles (zip archives). PROJECT_BRIEF.md §4.2.
##
## A .octet bundle contains: song.ogg (or .mp3/.wav), one or more
## chart_<difficulty>.oct files, optional cover.jpg/background.jpg, and
## manifest.json (bundle-level metadata, checksums, list of charts).
##
## Full bundle read/write is Stage 5 (M2b) scope. For now this exposes a
## working manifest reader (needed by anything that just wants to inspect a
## bundle) and a documented write stub.
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


## Writes a .octet bundle to `bundle_path`.
##
## TODO(Stage 5 / M2b): full implementation — write audio, per-difficulty
## .oct files, cover/background art, and manifest.json with checksums per
## PROJECT_BRIEF §4.2.
##
## For now this is a stub that only writes the manifest.json entry (so the
## manifest round-trip works end-to-end via read_manifest above); audio and
## chart args are accepted but not yet packed into the archive.
static func write_bundle(_bundle_path: String, _audio_path: String, _charts: Array[Chart], _manifest: Dictionary) -> Error:
	var packer := ZIPPacker.new()
	var open_err: Error = packer.open(_bundle_path)
	if open_err != OK:
		push_error("OctetBundle.write_bundle: failed to open %s for writing (error %d)" % [_bundle_path, open_err])
		return open_err

	packer.start_file("manifest.json")
	packer.write_file(JSON.stringify(_manifest, "  ").to_utf8_buffer())
	packer.close_file()

	# TODO(Stage 5 / M2b): pack _audio_path as song.<ext>, each entry of
	# _charts as chart_<difficulty>.oct (via OctIO.save_oct into a temp
	# buffer), and optional cover.jpg/background.jpg. Compute and store
	# checksums in the manifest before writing it above.

	return packer.close()
