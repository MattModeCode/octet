class_name Grading
extends RefCounted
## Final-song grading (PROJECT_BRIEF §2.5): grade letter from accuracy, plus
## the full-combo / all-Perfect badge checks. Pure and stateless -- fed
## final numbers by JudgeEngine (game/judge_engine.gd), not the other way
## around.

const GRADE_SS: String = "SS"
const GRADE_S: String = "S"
const GRADE_A: String = "A"
const GRADE_B: String = "B"
const GRADE_C: String = "C"
const GRADE_D: String = "D"


## Maps final [param accuracy] (0.0-1.0) to a grade letter using the
## thresholds in [param gameplay] (Config.gameplay). Below grade_c_threshold
## is D.
static func grade_for(accuracy: float, gameplay: GameplayConfig) -> String:
	if accuracy >= gameplay.grade_ss_threshold:
		return GRADE_SS
	if accuracy >= gameplay.grade_s_threshold:
		return GRADE_S
	if accuracy >= gameplay.grade_a_threshold:
		return GRADE_A
	if accuracy >= gameplay.grade_b_threshold:
		return GRADE_B
	if accuracy >= gameplay.grade_c_threshold:
		return GRADE_C
	return GRADE_D


## Full-combo badge: true if the run never dropped combo, i.e. it contains
## at least one judgment and zero Misses.
static func is_full_combo(judgment_counts: Dictionary) -> bool:
	var total := _total_judgments(judgment_counts)
	return total > 0 and int(judgment_counts.get(Judgment.Kind.MISS, 0)) == 0


## All-Perfect badge: true if every judgment in the run was a Perfect.
static func is_all_perfect(judgment_counts: Dictionary) -> bool:
	var total := _total_judgments(judgment_counts)
	if total == 0:
		return false
	return int(judgment_counts.get(Judgment.Kind.PERFECT, 0)) == total


static func _total_judgments(judgment_counts: Dictionary) -> int:
	var total := 0
	for count in judgment_counts.values():
		total += int(count)
	return total
