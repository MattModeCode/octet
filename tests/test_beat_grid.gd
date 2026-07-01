extends RefCounted
class_name TestBeatGrid
## Tests for the timing-point-aware beat grid math (editor/beat_grid.gd),
## per PROJECT_BRIEF §3.4. Pure functions, no autoload dependency -- no
## TestRunner.get_autoload() needed, same as TestGameplay.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "beat_grid_single_timing_point", "callable": test_single_timing_point},
		{"name": "beat_grid_multiple_timing_points", "callable": test_multiple_timing_points},
		{"name": "beat_grid_active_timing_point", "callable": test_active_timing_point},
		{"name": "beat_grid_snap_time_ms", "callable": test_snap_time_ms},
	]


func _tp(time_ms: int, bpm: float, meter: int = 4) -> TimingPoint:
	var tp := TimingPoint.new()
	tp.time_ms = time_ms
	tp.bpm = bpm
	tp.meter = meter
	return tp


func test_single_timing_point() -> bool:
	var points: Array[TimingPoint] = [_tp(0, 120.0)]
	var beats := BeatGrid.beat_times_ms(points, 1000.0)

	var ok := TestRunner._assert(beats.size() == 2, "beat_grid_single_timing_point: expected 2 beats, got %d" % beats.size())
	if beats.size() == 2:
		ok = TestRunner._assert(is_equal_approx(beats[0], 0.0), "beat_grid_single_timing_point: beat 0 expected 0.0") and ok
		ok = TestRunner._assert(is_equal_approx(beats[1], 500.0), "beat_grid_single_timing_point: beat 1 expected 500.0") and ok
	if ok:
		print("[PASS] beat_grid_single_timing_point")
	return ok


func test_multiple_timing_points() -> bool:
	var points: Array[TimingPoint] = [_tp(0, 120.0), _tp(1000, 100.0)]
	var beats := BeatGrid.beat_times_ms(points, 1600.0)

	var ok := TestRunner._assert(beats.size() == 3, "beat_grid_multiple_timing_points: expected 3 beats, got %d" % beats.size())
	if beats.size() == 3:
		ok = TestRunner._assert(is_equal_approx(beats[0], 0.0), "beat_grid_multiple_timing_points: beat 0 expected 0.0") and ok
		ok = TestRunner._assert(is_equal_approx(beats[1], 500.0), "beat_grid_multiple_timing_points: beat 1 expected 500.0") and ok
		ok = TestRunner._assert(is_equal_approx(beats[2], 1000.0), "beat_grid_multiple_timing_points: beat 2 expected 1000.0 (new tempo segment start)") and ok
	if ok:
		print("[PASS] beat_grid_multiple_timing_points")
	return ok


func test_active_timing_point() -> bool:
	var tp0 := _tp(0, 120.0)
	var tp1 := _tp(1000, 100.0)
	var points: Array[TimingPoint] = [tp0, tp1]

	var ok := true
	ok = TestRunner._assert(BeatGrid.active_timing_point(points, -100.0) == tp0, "beat_grid_active_timing_point: before all points should return the first") and ok
	ok = TestRunner._assert(BeatGrid.active_timing_point(points, 500.0) == tp0, "beat_grid_active_timing_point: 500ms should still be tp0") and ok
	ok = TestRunner._assert(BeatGrid.active_timing_point(points, 1000.0) == tp1, "beat_grid_active_timing_point: exactly at tp1.time_ms should be tp1") and ok
	ok = TestRunner._assert(BeatGrid.active_timing_point(points, 5000.0) == tp1, "beat_grid_active_timing_point: past tp1 should still be tp1") and ok
	if ok:
		print("[PASS] beat_grid_active_timing_point")
	return ok


func test_snap_time_ms() -> bool:
	var points: Array[TimingPoint] = [_tp(0, 120.0)] # beat interval 500ms.

	var ok := true
	# 1/4 snap -> step 125ms. 130ms rounds to 1 step (125ms).
	ok = TestRunner._assert(is_equal_approx(BeatGrid.snap_time_ms(130.0, points, 4), 125.0),
		"beat_grid_snap_time_ms: 1/4 snap of 130ms expected 125.0, got %s" % str(BeatGrid.snap_time_ms(130.0, points, 4))) and ok
	# 1/16 snap -> step 31.25ms. 40ms rounds to 1 step (31.25ms).
	ok = TestRunner._assert(is_equal_approx(BeatGrid.snap_time_ms(40.0, points, 16), 31.25),
		"beat_grid_snap_time_ms: 1/16 snap of 40ms expected 31.25, got %s" % str(BeatGrid.snap_time_ms(40.0, points, 16))) and ok
	# 1/1 snap -> step 500ms. 200ms is closer to 0 than to 500.
	ok = TestRunner._assert(is_equal_approx(BeatGrid.snap_time_ms(200.0, points, 1), 0.0),
		"beat_grid_snap_time_ms: 1/1 snap of 200ms expected 0.0, got %s" % str(BeatGrid.snap_time_ms(200.0, points, 1))) and ok
	if ok:
		print("[PASS] beat_grid_snap_time_ms")
	return ok
