class_name BeatGrid
extends RefCounted
## Timing-point-aware beat grid math (PROJECT_BRIEF §3.4): multiple timing
## points for tempo changes, each with a time/BPM/meter; the first defines
## the song offset; grid and snapping recompute per active timing point.
## Pure functions over Array[TimingPoint] -- no scene/UI dependency, so
## this is fully headless-testable (tests/test_beat_grid.gd) and reusable
## by both the waveform's beat-line overlay and (Stage 5) note snapping.

## Standard snap divisions offered by the editor (§3.5): 1/1 down to 1/16.
const SNAP_DIVISIONS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16]


## Returns every beat boundary time (ms) from the first timing point up to
## [param end_time_ms], across however many timing points are active.
## Timing points are assumed sorted by time_ms ascending (as loaded by
## OctIO); each segment runs from its own time_ms up to the next timing
## point's time_ms (or end_time_ms for the last segment).
static func beat_times_ms(timing_points: Array[TimingPoint], end_time_ms: float) -> Array[float]:
	var beats: Array[float] = []
	if timing_points.is_empty():
		return beats

	for i in timing_points.size():
		var tp := timing_points[i]
		var segment_end := end_time_ms
		if i + 1 < timing_points.size():
			segment_end = timing_points[i + 1].time_ms

		var beat_interval := 60000.0 / tp.bpm
		var beat_time := float(tp.time_ms)
		while beat_time < segment_end:
			beats.append(beat_time)
			beat_time += beat_interval

	return beats


## Returns the timing point active at [param time_ms] -- the last timing
## point whose time_ms is <= time_ms, or the first timing point if
## [param time_ms] precedes all of them. Returns null for an empty array.
static func active_timing_point(timing_points: Array[TimingPoint], time_ms: float) -> TimingPoint:
	if timing_points.is_empty():
		return null

	var active := timing_points[0]
	for tp in timing_points:
		if tp.time_ms <= time_ms:
			active = tp
		else:
			break
	return active


## Snaps [param time_ms] to the nearest grid line at [param snap_division]
## (one of SNAP_DIVISIONS, e.g. 4 = quarter beats, 16 = 1/16 beats) under
## whichever timing point is active at that time. Returns [param time_ms]
## unchanged if there are no timing points to snap against.
static func snap_time_ms(time_ms: float, timing_points: Array[TimingPoint], snap_division: int) -> float:
	var active := active_timing_point(timing_points, time_ms)
	if active == null or snap_division <= 0:
		return time_ms

	var step_ms := (60000.0 / active.bpm) / snap_division
	var steps_from_origin := roundf((time_ms - active.time_ms) / step_ms)
	return active.time_ms + steps_from_origin * step_ms
