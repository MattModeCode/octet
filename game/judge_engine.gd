class_name JudgeEngine
extends RefCounted
## Pure, time-driven judgment/scoring engine (PROJECT_BRIEF §2.2-2.6).
## Deliberately decoupled from rendering, real input, and the live
## Conductor -- driven by explicit update(song_time_ms) and
## on_lane_press/release(lane, song_time_ms) calls, mirroring the Stage 1
## split of pure timing math behind a Node (see audio/conductor.gd). This
## is what tests/test_gameplay.gd auto-plays with a scripted input
## sequence, and what game/play_field.gd feeds live Conductor/LaneInput
## events into.
##
## Hold model (§2.2/§2.4): the head is judged like a tap on press. While
## held, a tick fires every Config.gameplay.hold_tick_interval_ms and
## awards Perfect-weight credit toward accuracy + score only -- ticks
## deliberately do NOT touch combo or health, keeping "combo" meaning
## "notes hit in a row" rather than a per-tick counter, and keeping the
## health model tied to discrete note events. This is a documented M1a
## simplification, flagged for revisit at playtest (docs/BUILD_PLAN.md
## Stage 2 handoff). The tail is judged exactly like a tap, evaluated
## against end_time_ms at release time -- releasing too early naturally
## buckets to Miss (breaking combo) via the same window logic as any other
## note; any ticks that hadn't fired yet are then truncated to Miss entries
## (score 0, no combo/health effect, but they do count toward accuracy's
## denominator).

signal judged(lane: int, kind: Judgment.Kind, error_ms: float)
signal combo_changed(combo: int)
signal health_changed(health: float)
signal song_failed()


class NoteRuntime:
	var note: ChartNote
	var is_hold: bool
	var head_judged: bool = false
	var held: bool = false
	var tail_judged: bool = false
	var tick_times: Array[float] = []
	var ticks_fired: int = 0

	func _init(p_note: ChartNote, gameplay: GameplayConfig) -> void:
		note = p_note
		is_hold = note.type == "hold"
		if is_hold:
			var duration := float(note.end_time_ms - note.time_ms)
			var tick_count := int(floor(duration / gameplay.hold_tick_interval_ms))
			for i in range(1, tick_count + 1):
				tick_times.append(note.time_ms + i * gameplay.hold_tick_interval_ms)


var _gameplay: GameplayConfig
var _scoring: ScoringConfig
var _mods: GameplayMods
var _notes: Array[NoteRuntime] = []

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var health: float
var hit_errors: Array[float] = []
var judgment_counts: Dictionary = {}

var _failed: bool = false


func _init(chart: Chart, gameplay: GameplayConfig, scoring: ScoringConfig, mods: GameplayMods = null) -> void:
	_gameplay = gameplay
	_scoring = scoring
	_mods = mods if mods != null else GameplayMods.new()
	health = gameplay.health_start

	var sorted_notes: Array[ChartNote] = chart.notes.duplicate()
	sorted_notes.sort_custom(func(a: ChartNote, b: ChartNote) -> bool: return a.time_ms < b.time_ms)
	for note in sorted_notes:
		_notes.append(NoteRuntime.new(note, gameplay))


## Advances judgment for the given song time: auto-Misses any tap/hold-head
## whose Good window has fully elapsed unhit, fires due hold ticks for
## currently-held holds, and auto-resolves hold tails that were never
## released past their window.
func update(song_time_ms: float) -> void:
	for runtime in _notes:
		if not runtime.head_judged:
			if song_time_ms > runtime.note.time_ms + _gameplay.window_good_ms:
				_miss_unhit_head(runtime)
			continue

		if runtime.is_hold and runtime.held and not runtime.tail_judged:
			_fire_due_ticks(runtime, song_time_ms)
			if song_time_ms > runtime.note.end_time_ms + _gameplay.window_good_ms:
				_resolve_overheld_tail(runtime)


## Judges the nearest unjudged tap/hold-head in [param lane] within the
## Good window of [param song_time_ms]. Presses that don't land near any
## unjudged note are ignored (no penalty, no combo break) rather than
## treated as a stray miss.
func on_lane_press(lane: int, song_time_ms: float) -> void:
	var best: NoteRuntime = null
	var best_error := INF
	for runtime in _notes:
		if runtime.head_judged or runtime.note.lane != lane:
			continue
		var error := absf(song_time_ms - runtime.note.time_ms)
		if error <= _gameplay.window_good_ms and error < best_error:
			best = runtime
			best_error = error

	if best == null:
		return

	best.head_judged = true
	var signed_error := song_time_ms - best.note.time_ms
	var kind := Judgment.bucket(best_error, _gameplay)
	_apply_judgment(lane, kind, signed_error)

	if best.is_hold and kind != Judgment.Kind.MISS:
		best.held = true
	elif best.is_hold:
		# Missed the head entirely -- never held, so the whole hold (ticks +
		# tail) is forfeit immediately rather than left dangling.
		_forfeit_hold(best)


## Judges the tail of the currently-held hold in [param lane] (if any)
## against its end_time_ms, then truncates any ticks that hadn't fired yet
## into Miss entries.
func on_lane_release(lane: int, song_time_ms: float) -> void:
	var runtime := _find_held(lane)
	if runtime == null:
		return

	_fire_due_ticks(runtime, song_time_ms)

	var signed_error := song_time_ms - runtime.note.end_time_ms
	var kind := Judgment.bucket(absf(signed_error), _gameplay)
	runtime.tail_judged = true
	runtime.held = false
	_apply_judgment(lane, kind, signed_error)
	_truncate_remaining_ticks(runtime)


func accuracy() -> float:
	var total := 0
	var weight_sum := 0.0
	for kind in judgment_counts:
		var count: int = judgment_counts[kind]
		total += count
		weight_sum += Judgment.weight(kind, _gameplay) * count
	if total == 0:
		return 1.0
	return weight_sum / total


func grade() -> String:
	return Grading.grade_for(accuracy(), _gameplay)


func is_full_combo() -> bool:
	return Grading.is_full_combo(judgment_counts)


func is_all_perfect() -> bool:
	return Grading.is_all_perfect(judgment_counts)


func is_failed() -> bool:
	return _failed


func is_ranked() -> bool:
	return _mods.is_ranked()


func current_multiplier() -> float:
	var steps := floorf(float(combo) / float(_gameplay.combo_multiplier_step))
	return clampf(1.0 + steps, 1.0, _gameplay.combo_multiplier_cap)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _miss_unhit_head(runtime: NoteRuntime) -> void:
	runtime.head_judged = true
	_apply_judgment(runtime.note.lane, Judgment.Kind.MISS, null)
	if runtime.is_hold:
		_forfeit_hold(runtime)


## A hold whose head was missed (or auto-missed) never gets held -- the
## tail is unreachable and every tick is forfeit. Both are recorded as Miss
## entries (score 0) without touching combo/health a second time.
func _forfeit_hold(runtime: NoteRuntime) -> void:
	runtime.tail_judged = true
	runtime.held = false
	_apply_judgment(runtime.note.lane, Judgment.Kind.MISS, null, false, false)
	_truncate_remaining_ticks(runtime)


func _fire_due_ticks(runtime: NoteRuntime, song_time_ms: float) -> void:
	while runtime.ticks_fired < runtime.tick_times.size() and song_time_ms >= runtime.tick_times[runtime.ticks_fired]:
		_apply_judgment(runtime.note.lane, Judgment.Kind.PERFECT, null, false, false)
		runtime.ticks_fired += 1


func _resolve_overheld_tail(runtime: NoteRuntime) -> void:
	# Held past the tail's window with no release event -- treat as a
	# missed tail (no reliable release timestamp to judge against).
	runtime.tail_judged = true
	runtime.held = false
	_apply_judgment(runtime.note.lane, Judgment.Kind.MISS, null)
	_truncate_remaining_ticks(runtime)


func _truncate_remaining_ticks(runtime: NoteRuntime) -> void:
	var remaining := runtime.tick_times.size() - runtime.ticks_fired
	for i in remaining:
		_apply_judgment(runtime.note.lane, Judgment.Kind.MISS, null, false, false)
	runtime.ticks_fired = runtime.tick_times.size()


func _find_held(lane: int) -> NoteRuntime:
	for runtime in _notes:
		if runtime.is_hold and runtime.held and not runtime.tail_judged and runtime.note.lane == lane:
			return runtime
	return null


## Records one judgment. [param signed_error_ms] is null for
## engine-generated Misses (auto-miss, forfeited holds, truncated ticks)
## that have no real tap to measure an error from. [param affects_combo]
## and [param affects_health] are false for hold-tick credit/truncation,
## which contribute to accuracy/score only (see class doc comment).
func _apply_judgment(lane: int, kind: Judgment.Kind, signed_error_ms, affects_combo: bool = true, affects_health: bool = true) -> void:
	judgment_counts[kind] = int(judgment_counts.get(kind, 0)) + 1
	if signed_error_ms != null:
		hit_errors.append(signed_error_ms)

	var multiplier := current_multiplier()
	score += int(round(_scoring.base_note_score * Judgment.weight(kind, _gameplay) * multiplier))

	if affects_combo:
		if kind == Judgment.Kind.MISS:
			combo = 0
		else:
			combo += 1
			max_combo = maxi(max_combo, combo)
		combo_changed.emit(combo)

	if affects_health:
		health = clampf(health + Judgment.health_delta(kind, _gameplay), 0.0, _gameplay.health_start)
		health_changed.emit(health)
		if health <= 0.0 and not _mods.no_fail and not _failed:
			_failed = true
			song_failed.emit()

	judged.emit(lane, kind, signed_error_ms if signed_error_ms != null else 0.0)
