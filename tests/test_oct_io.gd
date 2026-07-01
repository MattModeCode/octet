extends RefCounted
class_name TestOctIO
## Round-trip tests for OctIO / Chart (core/oct_io.gd, core/chart.gd).
## Registered into tests/run_tests.gd.
##
## Chart is a typed Resource tree: Chart.metadata (ChartMetadata),
## Chart.audio (ChartAudio), Chart.timing_points (Array[TimingPoint]),
## Chart.notes (Array[ChartNote]) — see core/chart.gd and its sibling
## classes for exact fields.

const TEST_CHART_PATH := "user://test_chart.oct"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "oct_io_round_trip_metadata", "callable": test_round_trip_metadata},
		{"name": "oct_io_round_trip_timing_point", "callable": test_round_trip_timing_point},
		{"name": "oct_io_round_trip_notes", "callable": test_round_trip_notes},
	]


## Builds the exact example chart from PROJECT_BRIEF.md §4.1: title "Song
## Title", artist "Artist", one timing point at 812ms/174.0bpm/meter 4, and
## three notes (two taps sharing a tick as a chord, plus one hold with an
## end_time_ms).
static func _build_example_chart() -> Chart:
	var chart := Chart.new()
	chart.metadata.title = "Song Title"
	chart.metadata.artist = "Artist"

	var tp := TimingPoint.new()
	tp.time_ms = 812
	tp.bpm = 174.0
	tp.meter = 4
	chart.timing_points = [tp]

	var note_a := ChartNote.new()
	note_a.lane = 0
	note_a.time_ms = 812
	note_a.type = "tap"

	var note_b := ChartNote.new()
	note_b.lane = 3
	note_b.time_ms = 812
	note_b.type = "tap"

	var hold := ChartNote.new()
	hold.lane = 5
	hold.time_ms = 1156
	hold.type = "hold"
	hold.end_time_ms = 1500

	chart.notes = [note_a, note_b, hold]
	return chart


static func _save_and_reload() -> Chart:
	var chart := _build_example_chart()
	var err := OctIO.save_oct(chart, TEST_CHART_PATH)
	if err != OK:
		push_error("TestOctIO: save_oct failed with error %d" % err)
		return null
	return OctIO.load_oct(TEST_CHART_PATH)


func test_round_trip_metadata() -> bool:
	var loaded := _save_and_reload()
	var ok := true
	ok = TestRunner._assert(loaded != null, "oct_io_round_trip_metadata: load_oct returned null") and ok
	if loaded == null:
		return false
	ok = TestRunner._assert(loaded.metadata.title == "Song Title",
		"oct_io_round_trip_metadata: title mismatch, got '%s'" % loaded.metadata.title) and ok
	ok = TestRunner._assert(loaded.metadata.artist == "Artist",
		"oct_io_round_trip_metadata: artist mismatch, got '%s'" % loaded.metadata.artist) and ok
	if ok:
		print("[PASS] oct_io_round_trip_metadata")
	return ok


func test_round_trip_timing_point() -> bool:
	var loaded := _save_and_reload()
	var ok := true
	ok = TestRunner._assert(loaded != null, "oct_io_round_trip_timing_point: load_oct returned null") and ok
	if loaded == null:
		return false
	ok = TestRunner._assert(loaded.timing_points.size() == 1,
		"oct_io_round_trip_timing_point: expected 1 timing point, got %d" % loaded.timing_points.size()) and ok
	if loaded.timing_points.size() >= 1:
		var tp: TimingPoint = loaded.timing_points[0]
		ok = TestRunner._assert(tp.time_ms == 812,
			"oct_io_round_trip_timing_point: time_ms mismatch, got %s" % str(tp.time_ms)) and ok
		ok = TestRunner._assert(is_equal_approx(tp.bpm, 174.0),
			"oct_io_round_trip_timing_point: bpm mismatch, got %s" % str(tp.bpm)) and ok
		ok = TestRunner._assert(tp.meter == 4,
			"oct_io_round_trip_timing_point: meter mismatch, got %s" % str(tp.meter)) and ok
	if ok:
		print("[PASS] oct_io_round_trip_timing_point")
	return ok


func test_round_trip_notes() -> bool:
	var loaded := _save_and_reload()
	var ok := true
	ok = TestRunner._assert(loaded != null, "oct_io_round_trip_notes: load_oct returned null") and ok
	if loaded == null:
		return false
	ok = TestRunner._assert(loaded.notes.size() == 3,
		"oct_io_round_trip_notes: expected 3 notes, got %d" % loaded.notes.size()) and ok
	if loaded.notes.size() < 3:
		if ok:
			print("[PASS] oct_io_round_trip_notes")
		return ok

	var tap_a: ChartNote = loaded.notes[0]
	ok = TestRunner._assert(tap_a.lane == 0, "oct_io_round_trip_notes: note 0 lane mismatch") and ok
	ok = TestRunner._assert(tap_a.time_ms == 812, "oct_io_round_trip_notes: note 0 time_ms mismatch") and ok
	ok = TestRunner._assert(tap_a.type == "tap", "oct_io_round_trip_notes: note 0 type mismatch") and ok

	var tap_b: ChartNote = loaded.notes[1]
	ok = TestRunner._assert(tap_b.lane == 3, "oct_io_round_trip_notes: note 1 lane mismatch") and ok
	ok = TestRunner._assert(tap_b.time_ms == 812, "oct_io_round_trip_notes: note 1 time_ms mismatch") and ok
	ok = TestRunner._assert(tap_b.type == "tap", "oct_io_round_trip_notes: note 1 type mismatch") and ok

	var hold: ChartNote = loaded.notes[2]
	ok = TestRunner._assert(hold.lane == 5, "oct_io_round_trip_notes: hold lane mismatch") and ok
	ok = TestRunner._assert(hold.time_ms == 1156, "oct_io_round_trip_notes: hold time_ms mismatch") and ok
	ok = TestRunner._assert(hold.type == "hold", "oct_io_round_trip_notes: hold type mismatch") and ok
	ok = TestRunner._assert(hold.end_time_ms == 1500, "oct_io_round_trip_notes: hold end_time_ms mismatch") and ok

	if ok:
		print("[PASS] oct_io_round_trip_notes")
	return ok
