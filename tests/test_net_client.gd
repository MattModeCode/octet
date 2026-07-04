extends RefCounted
class_name TestNetClient
## Tests for net/net_client.gd's (WP-M, Map Hub) unpack_bundle_bytes() -- the
## bytes-already-in-hand half of download_map(), factored out specifically so
## it's testable without live network. Runs against the real seed bundle
## built by tools/build_seed_bundle.gd (maps/thats-why-i-gave-up-on-music.octet)
## rather than a synthetic one, so it doubles as a smoke test that the seed
## bundle itself is well-formed. Uses TestRunner.get_autoload("Net") --
## class_name-declared suites can't reference the Net autoload identifier
## directly at compile time (see run_tests.gd's header comment) -- and
## cleans up user://songs/<TEST_MAP_ID>/ afterward so a test run never
## leaves a duplicate entry in the real song library.

const BUNDLE_PATH: String = "res://maps/thats-why-i-gave-up-on-music.octet"
const TEST_MAP_ID: String = "thats-why-i-gave-up-on-music"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "net_client_unpack_writes_audio_and_charts", "callable": test_unpack_writes_audio_and_charts},
		{"name": "net_client_unpack_missing_bundle_fails_cleanly", "callable": test_unpack_missing_bundle_fails_cleanly},
	]


func _net() -> Object:
	return TestRunner.get_autoload("Net")


func _song_dir() -> String:
	return SongLibrary.USER_SONGS_DIR.path_join(TEST_MAP_ID)


func _cleanup() -> void:
	var dir := DirAccess.open(_song_dir())
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name not in [".", ".."]:
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_song_dir()))


func test_unpack_writes_audio_and_charts() -> bool:
	_cleanup()

	var net := _net()
	var result: Dictionary = net.unpack_bundle_bytes(BUNDLE_PATH, TEST_MAP_ID)
	var ok := TestRunner._assert(result.get("ok", false), "net_client_unpack_writes_audio_and_charts: unpack_bundle_bytes reported failure: %s" % str(result.get("error", "")))
	if not ok:
		_cleanup()
		return false

	var song_dir := String(result.get("song_dir", ""))
	ok = TestRunner._assert(song_dir == _song_dir(), "net_client_unpack_writes_audio_and_charts: expected song_dir '%s', got '%s'" % [_song_dir(), song_dir]) and ok

	var audio_path := song_dir.path_join("song.mp3")
	ok = TestRunner._assert(FileAccess.file_exists(audio_path), "net_client_unpack_writes_audio_and_charts: missing %s" % audio_path) and ok
	if FileAccess.file_exists(audio_path):
		ok = TestRunner._assert(FileAccess.get_file_as_bytes(audio_path).size() > 0, "net_client_unpack_writes_audio_and_charts: %s is empty" % audio_path) and ok

	for difficulty in ["easy", "normal", "hard"]:
		var chart_path := song_dir.path_join("%s.oct" % difficulty)
		ok = TestRunner._assert(FileAccess.file_exists(chart_path), "net_client_unpack_writes_audio_and_charts: missing %s" % chart_path) and ok
		if FileAccess.file_exists(chart_path):
			var chart := OctIO.load_oct(chart_path)
			ok = TestRunner._assert(chart != null, "net_client_unpack_writes_audio_and_charts: %s failed to parse back as a chart" % chart_path) and ok
			if chart != null:
				ok = TestRunner._assert(chart.metadata.difficulty_name.to_lower() == difficulty,
					"net_client_unpack_writes_audio_and_charts: %s has difficulty_name '%s', expected '%s'" % [chart_path, chart.metadata.difficulty_name, difficulty]) and ok
				ok = TestRunner._assert(chart.audio.filename == "song.mp3",
					"net_client_unpack_writes_audio_and_charts: %s's audio.filename is '%s', expected 'song.mp3'" % [chart_path, chart.audio.filename]) and ok

	_cleanup()
	if ok:
		print("[PASS] net_client_unpack_writes_audio_and_charts")
	return ok


func test_unpack_missing_bundle_fails_cleanly() -> bool:
	var net := _net()
	var result: Dictionary = net.unpack_bundle_bytes("res://maps/__does_not_exist__.octet", "__does_not_exist__")
	var ok := TestRunner._assert(not result.get("ok", true), "net_client_unpack_missing_bundle_fails_cleanly: expected ok == false for a missing bundle")
	ok = TestRunner._assert(not String(result.get("error", "")).is_empty(), "net_client_unpack_missing_bundle_fails_cleanly: expected a non-empty error message") and ok
	ok = TestRunner._assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SongLibrary.USER_SONGS_DIR.path_join("__does_not_exist__"))),
		"net_client_unpack_missing_bundle_fails_cleanly: should not have created a song directory for a failed unpack") and ok

	if ok:
		print("[PASS] net_client_unpack_missing_bundle_fails_cleanly")
	return ok
