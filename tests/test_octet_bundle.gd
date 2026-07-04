extends RefCounted
class_name TestOctetBundleWrite
## Round-trip test for OctetBundle.write_bundle() (core/octet_bundle.gd),
## completed in Stage 5 (M2b) per PROJECT_BRIEF §4.2. Writes a real bundle
## containing a real (synthetic) audio file and two difficulty charts,
## then reads it back via the existing read_manifest() to confirm the
## computed manifest fields (audio filename, difficulties list, checksum)
## are correct -- and that the zip actually contains what the manifest
## claims.

const AUDIO_PATH: String = "user://test_bundle_audio.wav"
const BUNDLE_PATH: String = "user://test_bundle.octet"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "octet_bundle_write_and_read_manifest", "callable": test_write_and_read_manifest},
		{"name": "octet_bundle_write_contains_chart_entries", "callable": test_write_contains_chart_entries},
		{"name": "octet_bundle_read_bundle_round_trip", "callable": test_read_bundle_round_trip},
	]


func _build_chart(difficulty_name: String, star_rating: float) -> Chart:
	var chart := Chart.new()
	chart.metadata.title = "Bundle test song"
	chart.metadata.artist = "Octet"
	chart.metadata.difficulty_name = difficulty_name
	chart.metadata.star_rating = star_rating
	var tp := TimingPoint.new()
	tp.time_ms = 0
	tp.bpm = 120.0
	chart.timing_points = [tp]
	var note := ChartNote.new()
	note.lane = 0
	note.time_ms = 500
	note.type = "tap"
	chart.notes = [note]
	return chart


func _write_test_bundle() -> Dictionary:
	var audio_stream := Metronome.build(120.0, 1, 4)
	audio_stream.save_to_wav(AUDIO_PATH)

	var charts: Array[Chart] = [_build_chart("Easy", 2.0), _build_chart("Hard", 4.5)]
	var manifest := {"title": "Bundle test song", "artist": "Octet"}

	var err := OctetBundle.write_bundle(BUNDLE_PATH, AUDIO_PATH, charts, manifest)
	return {"err": err}


func test_write_and_read_manifest() -> bool:
	var write_result := _write_test_bundle()
	var ok := TestRunner._assert(write_result.err == OK, "octet_bundle_write_and_read_manifest: write_bundle failed with %d" % write_result.err)
	if not ok:
		return false

	var manifest := OctetBundle.read_manifest(BUNDLE_PATH)
	ok = TestRunner._assert(not manifest.is_empty(), "octet_bundle_write_and_read_manifest: read_manifest returned empty") and ok
	if manifest.is_empty():
		return ok

	ok = TestRunner._assert(manifest.get("title", "") == "Bundle test song", "octet_bundle_write_and_read_manifest: title mismatch") and ok
	ok = TestRunner._assert(String(manifest.get("audio", "")) == "song.wav", "octet_bundle_write_and_read_manifest: expected audio 'song.wav', got '%s'" % str(manifest.get("audio"))) and ok
	ok = TestRunner._assert(String(manifest.get("audioChecksumSha256", "")).length() == 64, "octet_bundle_write_and_read_manifest: expected a 64-char sha256 hex checksum") and ok

	var difficulties: Array = manifest.get("difficulties", [])
	ok = TestRunner._assert(difficulties.size() == 2, "octet_bundle_write_and_read_manifest: expected 2 difficulties, got %d" % difficulties.size()) and ok
	if ok:
		print("[PASS] octet_bundle_write_and_read_manifest")
	return ok


func test_write_contains_chart_entries() -> bool:
	_write_test_bundle()

	var reader := ZIPReader.new()
	var open_err := reader.open(BUNDLE_PATH)
	var ok := TestRunner._assert(open_err == OK, "octet_bundle_write_contains_chart_entries: failed to open bundle as zip (%d)" % open_err)
	if not ok:
		return false

	ok = TestRunner._assert(reader.file_exists("chart_easy.oct"), "octet_bundle_write_contains_chart_entries: missing chart_easy.oct") and ok
	ok = TestRunner._assert(reader.file_exists("chart_hard.oct"), "octet_bundle_write_contains_chart_entries: missing chart_hard.oct") and ok
	ok = TestRunner._assert(reader.file_exists("song.wav"), "octet_bundle_write_contains_chart_entries: missing song.wav") and ok

	if reader.file_exists("chart_easy.oct"):
		var bytes: PackedByteArray = reader.read_file("chart_easy.oct")
		var json := JSON.new()
		var parse_err := json.parse(bytes.get_string_from_utf8())
		ok = TestRunner._assert(parse_err == OK, "octet_bundle_write_contains_chart_entries: chart_easy.oct is not valid JSON") and ok
		if parse_err == OK:
			var data: Dictionary = json.data
			ok = TestRunner._assert(data.get("metadata", {}).get("difficulty_name", "") == "Easy",
				"octet_bundle_write_contains_chart_entries: chart_easy.oct difficulty_name mismatch") and ok

	reader.close()
	if ok:
		print("[PASS] octet_bundle_write_contains_chart_entries")
	return ok


## read_bundle() is the editor's "Open existing beatmap" flow's read path
## (editor/editor_main.gd's _open_octet_bundle) -- confirms a bundle
## written by write_bundle() comes back with every difficulty and the
## exact original audio bytes, in manifest order.
func test_read_bundle_round_trip() -> bool:
	var write_result := _write_test_bundle()
	var ok := TestRunner._assert(write_result.err == OK, "octet_bundle_read_bundle_round_trip: write_bundle failed with %d" % write_result.err)
	if not ok:
		return false

	var bundle := OctetBundle.read_bundle(BUNDLE_PATH)
	ok = TestRunner._assert(not bundle.is_empty(), "octet_bundle_read_bundle_round_trip: read_bundle returned empty") and ok
	if bundle.is_empty():
		return ok

	var charts: Array = bundle["charts"]
	ok = TestRunner._assert(charts.size() == 2, "octet_bundle_read_bundle_round_trip: expected 2 charts, got %d" % charts.size()) and ok
	if charts.size() >= 2:
		ok = TestRunner._assert(charts[0].metadata.difficulty_name == "Easy",
			"octet_bundle_read_bundle_round_trip: charts[0] difficulty_name mismatch, got '%s'" % charts[0].metadata.difficulty_name) and ok
		ok = TestRunner._assert(charts[1].metadata.difficulty_name == "Hard",
			"octet_bundle_read_bundle_round_trip: charts[1] difficulty_name mismatch, got '%s'" % charts[1].metadata.difficulty_name) and ok
		ok = TestRunner._assert(charts[0].notes.size() == 1 and charts[0].notes[0].lane == 0,
			"octet_bundle_read_bundle_round_trip: charts[0] notes mismatch") and ok

	ok = TestRunner._assert(String(bundle.get("audio_filename", "")) == "song.wav",
		"octet_bundle_read_bundle_round_trip: expected audio_filename 'song.wav', got '%s'" % str(bundle.get("audio_filename"))) and ok

	var original_bytes := FileAccess.get_file_as_bytes(AUDIO_PATH)
	var read_bytes: PackedByteArray = bundle.get("audio_bytes", PackedByteArray())
	ok = TestRunner._assert(read_bytes.size() == original_bytes.size() and read_bytes == original_bytes,
		"octet_bundle_read_bundle_round_trip: audio_bytes don't match the original file") and ok

	if ok:
		print("[PASS] octet_bundle_read_bundle_round_trip")
	return ok
