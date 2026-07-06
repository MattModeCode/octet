## ScoreStore autoload (WP-E, docs/FEATURE_FIXES_BREAKDOWN.md). Local
## best-score-per-chart persistence -- online leaderboard is explicitly out
## of scope (Net is still a hard stub). Follows core/settings_store.gd's
## load/save pattern exactly: a typed Resource loaded from (and saved back
## to) a single user:// file.
##
## Keyed by chart path -- the same String song_select.gd/PlaySession already
## use as a chart's identity (PlaySession.chart_list entries, current_chart_
## path()) -- rather than title+artist+difficulty, per WP-E's scope note
## that chart path is the simplest option.
##
## Only ranked runs (JudgeEngine.is_ranked(), i.e. no No-Fail/Practice mod)
## are eligible to set or beat a best, matching the UNRANKED badge
## game/results.gd already shows for such runs -- an unranked run shouldn't
## silently overwrite a legitimate best.
extends Node

const USER_SCORES_PATH: String = "user://scores.tres"

var _data: BestScores


func _ready() -> void:
	if ResourceLoader.exists(USER_SCORES_PATH):
		var loaded: Resource = ResourceLoader.load(USER_SCORES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		_data = loaded as BestScores

	if _data == null:
		_data = BestScores.new()


## Returns the persisted best for chart_path, or {} if none recorded yet.
## Shape: {"score": int, "accuracy": float, "grade": String, "max_combo": int,
## "difficulty_name": String, "star_rating": float}. The last two are absent
## on entries recorded before the fan-out difficulty picker existed -- callers
## should read them with Dictionary.get() and a sensible default.
func best_for(chart_path: String) -> Dictionary:
	return _data.entries.get(chart_path, {})


## Returns every persisted best, keyed by chart_path -- same value shape as
## best_for(). Used by ui/profile.gd's "Best scores" list so the profile
## screen shows real local history instead of the mockup's sample data
## (CLAUDE.md's rule against silently faking data). Returns the live
## Dictionary reference's data by value semantics of Dictionary.duplicate()
## so callers can't accidentally mutate persisted state.
func all_entries() -> Dictionary:
	return _data.entries.duplicate()


## Records a finished run's result against chart_path if it's ranked, was not
## failed, and beats (or is the first entry for) the stored best. A failed
## run never counts as a completed entry -- it's excluded regardless of
## score, same as an unranked (No-Fail/Practice) run. Returns true when it
## set a new best, so callers (game/gameplay.gd) can flag Results' NEW BEST
## badge without Results having to re-derive the comparison itself.
##
## metadata is the chart's ChartMetadata -- its difficulty_name/star_rating
## are persisted into the entry (fan-out difficulty picker) so a saved score
## can display its difficulty level without re-reading the .oct (which may
## since have moved or been deleted).
func record_result(chart_path: String, engine: JudgeEngine, metadata: ChartMetadata) -> bool:
	if chart_path.is_empty() or not engine.is_ranked() or engine.is_failed():
		return false

	var previous: Dictionary = _data.entries.get(chart_path, {})
	if not previous.is_empty() and int(previous.score) >= engine.score:
		return false

	_data.entries[chart_path] = {
		"score": engine.score,
		"accuracy": engine.accuracy(),
		"grade": engine.grade(),
		"max_combo": engine.max_combo,
		"difficulty_name": metadata.difficulty_name,
		"star_rating": metadata.star_rating,
	}
	ResourceSaver.save(_data, USER_SCORES_PATH)
	return true
