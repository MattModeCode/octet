extends SceneTree
## Throwaway content validator -- NOT part of the game or test suite.
## Loads every .oct under res://songs/ and checks structural invariants the
## schema itself can't enforce:
##   - lanes within 0..7
##   - note times within [0, audio.duration_ms]
##   - holds end strictly after they start
##   - no two notes share the same lane + time_ms
##   - notes sorted ascending by time_ms
##   - per song folder: note count and star rating strictly increase
##     across the tier order (harder file = denser chart)
## Prints a per-chart summary table and exits non-zero on any failure.
##
## Run by hand via:
##   <path-to-godot> --headless -s tools/validate_charts.gd --path .

const TIER_ORDER := ["very_easy", "easy", "normal", "hard", "very_hard"]


func _initialize() -> void:
	var failures: Array[String] = []
	var song_dirs: Array[String] = _list_song_dirs("res://songs")
	song_dirs.sort()

	print("%-22s %-10s %6s %6s %7s" % ["song", "tier", "notes", "holds", "stars"])
	for dir_path: String in song_dirs:
		var per_tier: Dictionary = {}
		for file: String in _list_oct_files(dir_path):
			var path: String = dir_path.path_join(file)
			var chart: Chart = OctIO.load_oct(path)
			if chart == null:
				failures.append("%s: failed to load" % path)
				continue
			failures.append_array(_check_chart(path, chart))
			var hold_count: int = 0
			for note: ChartNote in chart.notes:
				if note.type == "hold":
					hold_count += 1
			print("%-22s %-10s %6d %6d %7.1f" % [
				dir_path.get_file(), file.get_basename(), chart.notes.size(),
				hold_count, chart.metadata.star_rating])
			per_tier[file.get_basename()] = {
				"count": chart.notes.size(), "stars": chart.metadata.star_rating,
			}
		failures.append_array(_check_tier_monotonicity(dir_path.get_file(), per_tier))

	print("")
	if failures.is_empty():
		print("validate_charts: OK -- all charts valid")
		quit(0)
	else:
		for f: String in failures:
			printerr("validate_charts: FAIL " + f)
		printerr("validate_charts: %d failure(s)" % failures.size())
		quit(1)


func _list_song_dirs(root: String) -> Array[String]:
	var dirs: Array[String] = []
	var da := DirAccess.open(root)
	if da == null:
		return dirs
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if da.current_is_dir() and not entry.begins_with("."):
			dirs.append(root.path_join(entry))
		entry = da.get_next()
	da.list_dir_end()
	return dirs


func _list_oct_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return files
	da.list_dir_begin()
	var entry: String = da.get_next()
	while entry != "":
		if not da.current_is_dir() and entry.ends_with(".oct"):
			files.append(entry)
		entry = da.get_next()
	da.list_dir_end()
	files.sort()
	return files


func _check_chart(path: String, chart: Chart) -> Array[String]:
	var failures: Array[String] = []
	var duration_ms: int = chart.audio.duration_ms
	var seen: Dictionary = {}
	var prev_time: int = -1
	for note: ChartNote in chart.notes:
		if note.lane < 0 or note.lane > 7:
			failures.append("%s: lane %d out of range" % [path, note.lane])
		if note.time_ms < 0 or note.time_ms > duration_ms:
			failures.append("%s: time %d outside [0, %d]" % [path, note.time_ms, duration_ms])
		if note.type == "hold" and note.end_time_ms <= note.time_ms:
			failures.append("%s: hold at %d ends at %d (not after start)" % [path, note.time_ms, note.end_time_ms])
		var key: String = "%d:%d" % [note.lane, note.time_ms]
		if seen.has(key):
			failures.append("%s: duplicate note lane %d @ %dms" % [path, note.lane, note.time_ms])
		seen[key] = true
		if note.time_ms < prev_time:
			failures.append("%s: notes not sorted at %dms" % [path, note.time_ms])
		prev_time = note.time_ms
	if chart.notes.is_empty():
		failures.append("%s: chart has no notes" % path)
	return failures


## Within one song folder, each present tier (in canonical order) must have
## strictly more notes and a strictly higher star rating than the previous
## present tier. Non-tier filenames (none today) are ignored.
func _check_tier_monotonicity(slug: String, per_tier: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var prev_name: String = ""
	var prev: Dictionary = {}
	for tier: String in TIER_ORDER:
		if not per_tier.has(tier):
			continue
		var cur: Dictionary = per_tier[tier]
		if not prev.is_empty():
			if cur.count <= prev.count:
				failures.append("%s: %s has %d notes, not more than %s's %d" % [
					slug, tier, cur.count, prev_name, prev.count])
			if cur.stars <= prev.stars:
				failures.append("%s: %s stars %.1f not above %s's %.1f" % [
					slug, tier, cur.stars, prev_name, prev.stars])
		prev = cur
		prev_name = tier
	return failures
