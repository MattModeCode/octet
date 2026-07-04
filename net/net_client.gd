extends Node
## Stage 0 Firebase placeholder, extended for WP-M (Map Hub) with a thin
## GitHub-hosted community map hub client. Stage 7 (M4) still owes the real
## Firebase REST client (Auth/Firestore/Storage/Functions per PROJECT_BRIEF
## §6.4) — all Firebase access must go through this autoload when that
## lands. The Map Hub API below is unrelated to Firebase: it just fetches
## `maps/index.json` and `.octet` bundles from the repo's raw.githubusercontent.com
## URLs (see docs/MAP_HUB_PUBLISHING.md).

## GitHub raw-content URL for the map hub's manifest (see maps/index.json and
## docs/MAP_HUB_PUBLISHING.md for the schema). Repo files, not a Release —
## see that doc for why, and for the future Release-asset migration path.
const MANIFEST_URL: String = "https://raw.githubusercontent.com/MattModeCode/octet/master/maps/index.json"

## Where an in-flight bundle download is buffered before being unpacked into
## user://songs/<id>/ — cleaned up after unpack_bundle_bytes() runs.
const CACHE_DIR: String = "user://cache"

## Emitted after fetch_map_manifest() successfully parses index.json. `maps`
## is the raw `"maps"` array from the manifest (each entry the Dictionary
## shape documented in docs/MAP_HUB_PUBLISHING.md) — map_hub.gd is expected
## to render straight from this, no extra transform needed.
signal manifest_fetched(maps: Array)
## Emitted instead of manifest_fetched on any failure (no network, timeout,
## non-200 response, malformed JSON, or a manifest missing its "maps" key).
## `error_message` is human-readable, safe to show directly in the UI.
signal manifest_fetch_failed(error_message: String)

## Emitted after download_map() successfully fetches a map's .octet bundle
## and unpacks it. `song_dir` is the absolute `user://songs/<id>` path
## SongLibrary.scan_charts() will pick up on its next scan.
signal map_downloaded(map_id: String, song_dir: String)
## Emitted instead of map_downloaded on any failure (network, malformed
## bundle, or a disk write error while unpacking).
signal map_download_failed(map_id: String, error_message: String)


## Stub. Always returns false until Stage 7 wires up the real Firebase client.
func is_online() -> bool:
	return false


## Fetches MANIFEST_URL and emits manifest_fetched/manifest_fetch_failed.
## Never crashes on no network, a timeout, or malformed JSON — every failure
## path emits manifest_fetch_failed with a readable message instead.
func fetch_map_manifest() -> void:
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			request.queue_free()
			_on_manifest_response(result, response_code, body)
	)
	var err := request.request(MANIFEST_URL)
	if err != OK:
		request.queue_free()
		manifest_fetch_failed.emit("Could not start manifest request (error %d)." % err)


func _on_manifest_response(result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		manifest_fetch_failed.emit("Map hub is unreachable (no connection or request failed).")
		return
	if response_code != 200:
		manifest_fetch_failed.emit("Map hub returned an unexpected response (HTTP %d)." % response_code)
		return

	var json := JSON.new()
	var parse_err: Error = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		manifest_fetch_failed.emit("Map hub manifest was malformed at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("maps") or typeof(data["maps"]) != TYPE_ARRAY:
		manifest_fetch_failed.emit("Map hub manifest is missing its \"maps\" list.")
		return

	manifest_fetched.emit(data["maps"])


## Downloads `map_entry.bundle_url`'s bytes and unpacks them into
## user://songs/<map_entry.id>/, emitting map_downloaded/map_download_failed.
## Never fabricates success — any network, bundle, or disk failure emits
## map_download_failed with a readable message.
func download_map(map_entry: Dictionary) -> void:
	var map_id := String(map_entry.get("id", ""))
	var bundle_url := String(map_entry.get("bundle_url", ""))
	if map_id.is_empty() or bundle_url.is_empty():
		map_download_failed.emit(map_id, "Map entry is missing an id or bundle_url.")
		return

	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
			request.queue_free()
			_on_bundle_response(map_id, result, response_code, body)
	)
	var err := request.request(bundle_url)
	if err != OK:
		request.queue_free()
		map_download_failed.emit(map_id, "Could not start bundle download (error %d)." % err)


func _on_bundle_response(map_id: String, result: int, response_code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		map_download_failed.emit(map_id, "Download failed (no connection or request failed).")
		return
	if response_code != 200:
		map_download_failed.emit(map_id, "Download returned an unexpected response (HTTP %d)." % response_code)
		return

	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var temp_path := CACHE_DIR.path_join("%s.octet" % map_id)
	var temp_file := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp_file == null:
		map_download_failed.emit(map_id, "Could not write temp file for download (error %d)." % FileAccess.get_open_error())
		return
	temp_file.store_buffer(body)
	temp_file.close()

	var unpack_result := unpack_bundle_bytes(temp_path, map_id)

	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	if unpack_result.get("ok", false):
		map_downloaded.emit(map_id, String(unpack_result.get("song_dir", "")))
	else:
		map_download_failed.emit(map_id, String(unpack_result.get("error", "Unknown error unpacking bundle.")))


## Reads the .octet bundle at `bundle_path` via OctetBundle.read_bundle() and
## writes its contents into `user://songs/<map_id>/`: the audio as
## `song.<ext>` and each chart as `<difficulty_name.to_lower()>.oct` via
## OctIO.save_oct() — the exact shape SongLibrary.scan_charts() expects.
## Factored out from the HTTPRequest callback so it's unit-testable against a
## bundle already on disk, with no live network involved. Returns
## {"ok": true, "song_dir": String} on success, or
## {"ok": false, "error": String} on any failure (unreadable bundle, no
## audio, no charts, or a disk write error) — never partially writes without
## reporting the failure.
func unpack_bundle_bytes(bundle_path: String, map_id: String) -> Dictionary:
	var bundle := OctetBundle.read_bundle(bundle_path)
	if bundle.is_empty():
		return {"ok": false, "error": "Bundle at %s is unreadable or malformed." % bundle_path}

	var audio_filename := String(bundle.get("audio_filename", ""))
	var audio_bytes: PackedByteArray = bundle.get("audio_bytes", PackedByteArray())
	if audio_filename.is_empty() or audio_bytes.is_empty():
		return {"ok": false, "error": "Bundle at %s has no audio to unpack." % bundle_path}

	var charts: Array = bundle.get("charts", [])
	if charts.is_empty():
		return {"ok": false, "error": "Bundle at %s has no charts to unpack." % bundle_path}

	var song_dir: String = SongLibrary.USER_SONGS_DIR.path_join(map_id)
	DirAccess.make_dir_recursive_absolute(song_dir)

	var audio_ext := audio_filename.get_extension()
	var audio_path := song_dir.path_join("song.%s" % audio_ext)
	var audio_file := FileAccess.open(audio_path, FileAccess.WRITE)
	if audio_file == null:
		return {"ok": false, "error": "Could not write audio to %s (error %d)." % [audio_path, FileAccess.get_open_error()]}
	audio_file.store_buffer(audio_bytes)
	audio_file.close()

	var saved_audio_filename := "song.%s" % audio_ext
	for chart in charts:
		var safe_name: String = chart.metadata.difficulty_name.to_lower().replace(" ", "_")
		if safe_name.is_empty():
			safe_name = "difficulty"
		var chart_path := song_dir.path_join("%s.oct" % safe_name)
		# Repoint the chart at the audio file's saved name (it may differ from
		# the bundle's original filename) -- SongLibrary.resolve_audio_path()
		# resolves ChartAudio.filename relative to the .oct's own directory,
		# so the two must agree or playback silently breaks.
		chart.audio.filename = saved_audio_filename
		var save_err := OctIO.save_oct(chart, chart_path)
		if save_err != OK:
			return {"ok": false, "error": "Could not write chart to %s (error %d)." % [chart_path, save_err]}

	return {"ok": true, "song_dir": song_dir}
