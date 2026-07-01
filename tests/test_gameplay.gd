extends RefCounted
class_name TestGameplay
## Headless "auto-play" tests for the Stage 2 judgment/scoring engine
## (game/judge_engine.gd), driven with scripted input sequences per
## docs/BUILD_PLAN.md Stage 2 ("done when a headless auto-play over a
## fixture .oct yields the expected accuracy/combo/grade/health for known
## input sequences").
##
## Unlike TestConductor/TestLaneInput, this suite does NOT need
## TestRunner.get_autoload() -- JudgeEngine, GameplayConfig, ScoringConfig,
## GameplayMods, Chart, and ChartNote are all plain classes with no
## autoload dependency, so fresh instances (GameplayConfig.new(), etc.)
## reproduce the config/gameplay.tres / config/scoring.tres defaults
## directly without touching the Config autoload at all.

const FIXTURE_OCT_PATH: String = "res://tests/fixtures/m1a_fixture.oct"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "gameplay_all_perfect_run", "callable": test_all_perfect_run},
		{"name": "gameplay_one_missed_note", "callable": test_one_missed_note},
		{"name": "gameplay_chord_both_hit", "callable": test_chord_both_hit},
		{"name": "gameplay_chord_one_missed", "callable": test_chord_one_missed},
		{"name": "gameplay_hold_held_fully", "callable": test_hold_held_fully},
		{"name": "gameplay_hold_early_release", "callable": test_hold_early_release},
		{"name": "gameplay_no_fail_mod", "callable": test_no_fail_mod},
		{"name": "gameplay_grade_thresholds", "callable": test_grade_thresholds},
		{"name": "gameplay_fixture_oct_round_trip", "callable": test_fixture_oct_round_trip},
	]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _tap(lane: int, time_ms: int) -> ChartNote:
	var note := ChartNote.new()
	note.lane = lane
	note.time_ms = time_ms
	note.type = "tap"
	return note


func _hold(lane: int, time_ms: int, end_time_ms: int) -> ChartNote:
	var note := ChartNote.new()
	note.lane = lane
	note.time_ms = time_ms
	note.type = "hold"
	note.end_time_ms = end_time_ms
	return note


func _chart(notes: Array[ChartNote]) -> Chart:
	var chart := Chart.new()
	chart.notes = notes
	return chart


func _engine(notes: Array[ChartNote], mods: GameplayMods = null) -> JudgeEngine:
	return JudgeEngine.new(_chart(notes), GameplayConfig.new(), ScoringConfig.new(), mods)


# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

func test_all_perfect_run() -> bool:
	var engine := _engine([_tap(0, 1000), _tap(1, 2000), _tap(2, 3000)])
	engine.on_lane_press(0, 1000.0)
	engine.on_lane_press(1, 2000.0)
	engine.on_lane_press(2, 3000.0)

	var ok := true
	ok = TestRunner._assert(engine.score == 900, "gameplay_all_perfect_run: expected score 900, got %d" % engine.score) and ok
	ok = TestRunner._assert(engine.combo == 3, "gameplay_all_perfect_run: expected combo 3, got %d" % engine.combo) and ok
	ok = TestRunner._assert(engine.max_combo == 3, "gameplay_all_perfect_run: expected max_combo 3, got %d" % engine.max_combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 1.0), "gameplay_all_perfect_run: expected accuracy 1.0, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(engine.grade() == "SS", "gameplay_all_perfect_run: expected grade SS, got %s" % engine.grade()) and ok
	ok = TestRunner._assert(engine.is_full_combo(), "gameplay_all_perfect_run: expected full combo") and ok
	ok = TestRunner._assert(engine.is_all_perfect(), "gameplay_all_perfect_run: expected all perfect") and ok
	ok = TestRunner._assert(is_equal_approx(engine.health, 100.0), "gameplay_all_perfect_run: expected health 100.0, got %s" % str(engine.health)) and ok
	if ok:
		print("[PASS] gameplay_all_perfect_run")
	return ok


func test_one_missed_note() -> bool:
	var engine := _engine([_tap(0, 1000), _tap(1, 2000), _tap(2, 3000)])
	engine.on_lane_press(0, 1000.0)
	engine.update(2200.0) # past note 2's Good window (2000 + 110) -- auto-Miss.
	engine.on_lane_press(2, 3000.0)

	var ok := true
	ok = TestRunner._assert(engine.score == 600, "gameplay_one_missed_note: expected score 600, got %d" % engine.score) and ok
	ok = TestRunner._assert(engine.combo == 1, "gameplay_one_missed_note: expected combo 1, got %d" % engine.combo) and ok
	ok = TestRunner._assert(engine.max_combo == 1, "gameplay_one_missed_note: expected max_combo 1, got %d" % engine.max_combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 2.0 / 3.0), "gameplay_one_missed_note: expected accuracy 0.667, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(engine.grade() == "D", "gameplay_one_missed_note: expected grade D, got %s" % engine.grade()) and ok
	ok = TestRunner._assert(not engine.is_full_combo(), "gameplay_one_missed_note: expected combo broken") and ok
	ok = TestRunner._assert(is_equal_approx(engine.health, 95.0), "gameplay_one_missed_note: expected health 95.0, got %s" % str(engine.health)) and ok
	if ok:
		print("[PASS] gameplay_one_missed_note")
	return ok


func test_chord_both_hit() -> bool:
	var engine := _engine([_tap(0, 1000), _tap(4, 1000)])
	engine.on_lane_press(0, 1000.0)
	engine.on_lane_press(4, 1000.0)

	var ok := true
	ok = TestRunner._assert(engine.combo == 2, "gameplay_chord_both_hit: expected combo 2, got %d" % engine.combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 1.0), "gameplay_chord_both_hit: expected accuracy 1.0, got %s" % str(engine.accuracy())) and ok
	if ok:
		print("[PASS] gameplay_chord_both_hit")
	return ok


func test_chord_one_missed() -> bool:
	var engine := _engine([_tap(0, 1000), _tap(4, 1000)])
	engine.on_lane_press(0, 1000.0)
	engine.update(1200.0) # past the chord's Good window -- auto-Miss lane 4.

	var ok := true
	ok = TestRunner._assert(engine.combo == 0, "gameplay_chord_one_missed: expected combo 0 (broken), got %d" % engine.combo) and ok
	ok = TestRunner._assert(engine.max_combo == 1, "gameplay_chord_one_missed: expected max_combo 1, got %d" % engine.max_combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 0.5), "gameplay_chord_one_missed: expected accuracy 0.5, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(not engine.is_full_combo(), "gameplay_chord_one_missed: expected combo broken") and ok
	if ok:
		print("[PASS] gameplay_chord_one_missed")
	return ok


## Hold at lane 3, time_ms 1000, end_time_ms 1250 (250ms duration, 100ms
## tick interval -> 2 ticks at 1100/1200). Head hit on time, held through
## the two ticks, released exactly on time.
func test_hold_held_fully() -> bool:
	var engine := _engine([_hold(3, 1000, 1250)])
	engine.on_lane_press(3, 1000.0)
	engine.update(1100.0)
	engine.update(1200.0)
	engine.on_lane_release(3, 1250.0)

	var ok := true
	ok = TestRunner._assert(engine.score == 1200, "gameplay_hold_held_fully: expected score 1200, got %d" % engine.score) and ok
	ok = TestRunner._assert(engine.combo == 2, "gameplay_hold_held_fully: expected combo 2 (head + tail only), got %d" % engine.combo) and ok
	ok = TestRunner._assert(engine.max_combo == 2, "gameplay_hold_held_fully: expected max_combo 2, got %d" % engine.max_combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 1.0), "gameplay_hold_held_fully: expected accuracy 1.0, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(is_equal_approx(engine.health, 100.0), "gameplay_hold_held_fully: expected health 100.0, got %s" % str(engine.health)) and ok
	if ok:
		print("[PASS] gameplay_hold_held_fully")
	return ok


## Same hold, but released early at 1120 -- before the tail's Good window
## (1250 +/- 110 = [1140, 1360]) opens, and before the second tick (due at
## 1200) fires. Expect the tail to bucket as a Miss (breaking combo), and
## the un-fired second tick to be truncated into a Miss entry.
func test_hold_early_release() -> bool:
	var engine := _engine([_hold(3, 1000, 1250)])
	engine.on_lane_press(3, 1000.0)
	engine.update(1100.0) # fires the first tick only.
	engine.on_lane_release(3, 1120.0)

	var ok := true
	ok = TestRunner._assert(engine.score == 600, "gameplay_hold_early_release: expected score 600, got %d" % engine.score) and ok
	ok = TestRunner._assert(engine.combo == 0, "gameplay_hold_early_release: expected combo 0 (broken by tail Miss), got %d" % engine.combo) and ok
	ok = TestRunner._assert(engine.max_combo == 1, "gameplay_hold_early_release: expected max_combo 1 (head only), got %d" % engine.max_combo) and ok
	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 0.5), "gameplay_hold_early_release: expected accuracy 0.5, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(is_equal_approx(engine.health, 94.0), "gameplay_hold_early_release: expected health 94.0, got %s" % str(engine.health)) and ok
	if ok:
		print("[PASS] gameplay_hold_early_release")
	return ok


func test_no_fail_mod() -> bool:
	var notes: Array[ChartNote] = []
	for i in 20:
		notes.append(_tap(0, 1000 + i * 500))
	var mods := GameplayMods.new(true, false) # no_fail = true
	var engine := _engine(notes, mods)
	engine.update(30000.0) # past every note's Good window -- all 20 auto-Miss.

	var ok := true
	ok = TestRunner._assert(not engine.is_failed(), "gameplay_no_fail_mod: expected is_failed() false under No-Fail") and ok
	ok = TestRunner._assert(not engine.is_ranked(), "gameplay_no_fail_mod: expected is_ranked() false under No-Fail") and ok
	ok = TestRunner._assert(engine.health <= 0.0, "gameplay_no_fail_mod: expected health drained to 0, got %s" % str(engine.health)) and ok
	if ok:
		print("[PASS] gameplay_no_fail_mod")
	return ok


func test_grade_thresholds() -> bool:
	var gameplay := GameplayConfig.new()
	var ok := true
	ok = TestRunner._assert(Grading.grade_for(1.0, gameplay) == "SS", "gameplay_grade_thresholds: 1.0 expected SS") and ok
	ok = TestRunner._assert(Grading.grade_for(0.99, gameplay) == "S", "gameplay_grade_thresholds: 0.99 expected S") and ok
	ok = TestRunner._assert(Grading.grade_for(0.95, gameplay) == "S", "gameplay_grade_thresholds: 0.95 expected S") and ok
	ok = TestRunner._assert(Grading.grade_for(0.90, gameplay) == "A", "gameplay_grade_thresholds: 0.90 expected A") and ok
	ok = TestRunner._assert(Grading.grade_for(0.80, gameplay) == "B", "gameplay_grade_thresholds: 0.80 expected B") and ok
	ok = TestRunner._assert(Grading.grade_for(0.70, gameplay) == "C", "gameplay_grade_thresholds: 0.70 expected C") and ok
	ok = TestRunner._assert(Grading.grade_for(0.69, gameplay) == "D", "gameplay_grade_thresholds: 0.69 expected D") and ok
	if ok:
		print("[PASS] gameplay_grade_thresholds")
	return ok


## Loads the committed Stage 2 fixture chart through the real OctIO path
## (res:// -> Chart), then auto-plays it perfectly: the chord at 1000ms
## (lanes 0 and 4), the tap at 1500ms (lane 2), and the hold at
## 2000-2250ms (lane 3) held fully through release.
func test_fixture_oct_round_trip() -> bool:
	var chart := OctIO.load_oct(FIXTURE_OCT_PATH)
	var ok := TestRunner._assert(chart != null, "gameplay_fixture_oct_round_trip: OctIO.load_oct returned null")
	if chart == null:
		return false
	ok = TestRunner._assert(chart.notes.size() == 4, "gameplay_fixture_oct_round_trip: expected 4 notes, got %d" % chart.notes.size()) and ok

	var engine := JudgeEngine.new(chart, GameplayConfig.new(), ScoringConfig.new())
	engine.on_lane_press(0, 1000.0)
	engine.on_lane_press(4, 1000.0)
	engine.on_lane_press(2, 1500.0)
	engine.on_lane_press(3, 2000.0)
	engine.update(2100.0)
	engine.update(2200.0)
	engine.on_lane_release(3, 2250.0)

	ok = TestRunner._assert(is_equal_approx(engine.accuracy(), 1.0),
		"gameplay_fixture_oct_round_trip: expected accuracy 1.0, got %s" % str(engine.accuracy())) and ok
	ok = TestRunner._assert(engine.is_full_combo(), "gameplay_fixture_oct_round_trip: expected full combo") and ok
	ok = TestRunner._assert(engine.is_all_perfect(), "gameplay_fixture_oct_round_trip: expected all perfect") and ok
	if ok:
		print("[PASS] gameplay_fixture_oct_round_trip")
	return ok
