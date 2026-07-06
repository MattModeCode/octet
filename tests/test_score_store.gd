extends RefCounted
class_name TestScoreStore
## Tests for core/score_store.gd (WP-E, docs/FEATURE_FIXES_BREAKDOWN.md):
## ranked-only recording, higher-score-wins overwrite, and read-back via
## best_for(). Uses TestRunner.get_autoload() (class_name-declared suites
## can't reference the ScoreStore autoload identifier directly at compile
## time -- see run_tests.gd's header comment) against a throwaway chart-path
## key so it can't collide with a real chart's persisted best.

const FAKE_CHART_PATH: String = "user://__test_score_store_chart__.oct"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "score_store_first_ranked_run_is_recorded", "callable": test_first_ranked_run_is_recorded},
		{"name": "score_store_higher_score_overwrites", "callable": test_higher_score_overwrites},
		{"name": "score_store_lower_score_does_not_overwrite", "callable": test_lower_score_does_not_overwrite},
		{"name": "score_store_unranked_run_is_not_recorded", "callable": test_unranked_run_is_not_recorded},
		{"name": "score_store_failed_run_is_not_recorded", "callable": test_failed_run_is_not_recorded},
	]


func _engine_with_score(score: int, mods: GameplayMods = null) -> JudgeEngine:
	var chart := Chart.new()
	var engine := JudgeEngine.new(chart, GameplayConfig.new(), ScoringConfig.new(), mods)
	engine.score = score
	return engine


## Fixed sample metadata for every record_result() call in this suite -- the
## tests only assert on the score comparison/ranked/failed behaviour, so a
## single fixed difficulty_name/star_rating is enough to exercise that the
## fields round-trip through best_for() without adding a new test parameter
## per case.
func _fake_metadata() -> ChartMetadata:
	var metadata := ChartMetadata.new()
	metadata.difficulty_name = "Hard"
	metadata.star_rating = 5.8
	return metadata


func _store() -> Object:
	return TestRunner.get_autoload("ScoreStore")


## Drives enough auto-Misses (via the public update()/on_lane_press() API,
## same as test_gameplay.gd) to zero health and trip JudgeEngine's real
## song_failed/is_failed() state -- not a hand-set flag, so this actually
## exercises the same fail path gameplay.gd hits.
func _failed_engine(score: int) -> JudgeEngine:
	var config := GameplayConfig.new()
	var miss_count := int(ceil(config.health_start / -config.health_delta_miss))
	var notes: Array[ChartNote] = []
	var t := 1000.0
	for i in miss_count:
		var note := ChartNote.new()
		note.lane = i % 8
		note.time_ms = t
		note.type = "tap"
		notes.append(note)
		t += 200.0
	var chart := Chart.new()
	chart.notes = notes
	var engine := JudgeEngine.new(chart, config, ScoringConfig.new())
	for note in notes:
		engine.update(note.time_ms + config.window_good_ms + 1.0)
	engine.score = score
	return engine


## Removes FAKE_CHART_PATH and re-saves so a run's throwaway key never lingers
## in the real user://scores.tres on disk -- record_result() only saves on a
## new-best write, so a plain in-memory erase() at the end of a test would
## otherwise leave the last-saved snapshot (with the fake entry) on disk.
func _erase(store: Object) -> void:
	store._data.entries.erase(FAKE_CHART_PATH)
	ResourceSaver.save(store._data, store.USER_SCORES_PATH)


func test_first_ranked_run_is_recorded() -> bool:
	var store := _store()
	store._data.entries.erase(FAKE_CHART_PATH)

	var is_new_best: bool = store.record_result(FAKE_CHART_PATH, _engine_with_score(1000), _fake_metadata())
	var ok := TestRunner._assert(is_new_best, "score_store_first_ranked_run_is_recorded: expected first record to be a new best")

	var best: Dictionary = store.best_for(FAKE_CHART_PATH)
	ok = TestRunner._assert(int(best.get("score", -1)) == 1000,
		"score_store_first_ranked_run_is_recorded: expected stored score 1000, got %s" % str(best.get("score"))) and ok
	ok = TestRunner._assert(String(best.get("difficulty_name", "")) == "Hard",
		"score_store_first_ranked_run_is_recorded: expected stored difficulty_name 'Hard', got %s" % str(best.get("difficulty_name"))) and ok
	ok = TestRunner._assert(is_equal_approx(float(best.get("star_rating", -1.0)), 5.8),
		"score_store_first_ranked_run_is_recorded: expected stored star_rating 5.8, got %s" % str(best.get("star_rating"))) and ok

	_erase(store)
	if ok:
		print("[PASS] score_store_first_ranked_run_is_recorded")
	return ok


func test_higher_score_overwrites() -> bool:
	var store := _store()
	store._data.entries.erase(FAKE_CHART_PATH)
	store.record_result(FAKE_CHART_PATH, _engine_with_score(1000), _fake_metadata())

	var is_new_best: bool = store.record_result(FAKE_CHART_PATH, _engine_with_score(1500), _fake_metadata())
	var ok := TestRunner._assert(is_new_best, "score_store_higher_score_overwrites: expected a higher score to be a new best")

	var best: Dictionary = store.best_for(FAKE_CHART_PATH)
	ok = TestRunner._assert(int(best.get("score", -1)) == 1500,
		"score_store_higher_score_overwrites: expected stored score 1500, got %s" % str(best.get("score"))) and ok

	_erase(store)
	if ok:
		print("[PASS] score_store_higher_score_overwrites")
	return ok


func test_lower_score_does_not_overwrite() -> bool:
	var store := _store()
	store._data.entries.erase(FAKE_CHART_PATH)
	store.record_result(FAKE_CHART_PATH, _engine_with_score(1000), _fake_metadata())

	var is_new_best: bool = store.record_result(FAKE_CHART_PATH, _engine_with_score(500), _fake_metadata())
	var ok := TestRunner._assert(not is_new_best, "score_store_lower_score_does_not_overwrite: expected a lower score not to be a new best")

	var best: Dictionary = store.best_for(FAKE_CHART_PATH)
	ok = TestRunner._assert(int(best.get("score", -1)) == 1000,
		"score_store_lower_score_does_not_overwrite: expected stored score to remain 1000, got %s" % str(best.get("score"))) and ok

	_erase(store)
	if ok:
		print("[PASS] score_store_lower_score_does_not_overwrite")
	return ok


func test_unranked_run_is_not_recorded() -> bool:
	var store := _store()
	store._data.entries.erase(FAKE_CHART_PATH)

	var no_fail_mods := GameplayMods.new(true, false)
	var is_new_best: bool = store.record_result(FAKE_CHART_PATH, _engine_with_score(1000, no_fail_mods), _fake_metadata())
	var ok := TestRunner._assert(not is_new_best, "score_store_unranked_run_is_not_recorded: expected an unranked (No-Fail) run not to be recorded")
	ok = TestRunner._assert(store.best_for(FAKE_CHART_PATH).is_empty(),
		"score_store_unranked_run_is_not_recorded: expected no stored best after an unranked run") and ok

	_erase(store)
	if ok:
		print("[PASS] score_store_unranked_run_is_not_recorded")
	return ok


func test_failed_run_is_not_recorded() -> bool:
	var store := _store()
	store._data.entries.erase(FAKE_CHART_PATH)

	var engine := _failed_engine(999999)
	var ok := TestRunner._assert(engine.is_failed(), "score_store_failed_run_is_not_recorded: setup expected engine.is_failed() to be true")

	var is_new_best: bool = store.record_result(FAKE_CHART_PATH, engine, _fake_metadata())
	ok = TestRunner._assert(not is_new_best, "score_store_failed_run_is_not_recorded: expected a failed run not to be recorded") and ok
	ok = TestRunner._assert(store.best_for(FAKE_CHART_PATH).is_empty(),
		"score_store_failed_run_is_not_recorded: expected no stored best after a failed run") and ok

	_erase(store)
	if ok:
		print("[PASS] score_store_failed_run_is_not_recorded")
	return ok
