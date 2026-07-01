class_name Judgment
extends RefCounted
## The four judgment outcomes (PROJECT_BRIEF §2.4) plus the single place
## that maps a timing error to a judgment, and a judgment to its accuracy
## weight / health delta. Nothing else should re-derive these mappings --
## JudgeEngine (game/judge_engine.gd) and any future HUD/results code
## should call through here.

enum Kind { PERFECT, GREAT, GOOD, MISS }


## Buckets an absolute timing error (ms) into a Kind using the windows in
## [param gameplay] (Config.gameplay). Symmetric around the note's target
## time per §2.4 -- callers pass abs(error_ms).
static func bucket(abs_error_ms: float, gameplay: GameplayConfig) -> Kind:
	if abs_error_ms <= gameplay.window_perfect_ms:
		return Kind.PERFECT
	if abs_error_ms <= gameplay.window_great_ms:
		return Kind.GREAT
	if abs_error_ms <= gameplay.window_good_ms:
		return Kind.GOOD
	return Kind.MISS


## Human-readable label, e.g. for HUD/results display.
static func display_name(kind: Kind) -> String:
	match kind:
		Kind.PERFECT:
			return "Perfect"
		Kind.GREAT:
			return "Great"
		Kind.GOOD:
			return "Good"
		_:
			return "Miss"


## Accuracy weight for [param kind] (§2.4/§2.5), from config.
static func weight(kind: Kind, gameplay: GameplayConfig) -> float:
	match kind:
		Kind.PERFECT:
			return gameplay.weight_perfect
		Kind.GREAT:
			return gameplay.weight_great
		Kind.GOOD:
			return gameplay.weight_good
		_:
			return gameplay.weight_miss


## Health delta for [param kind] (§2.6), from config.
static func health_delta(kind: Kind, gameplay: GameplayConfig) -> float:
	match kind:
		Kind.PERFECT:
			return gameplay.health_delta_perfect
		Kind.GREAT:
			return gameplay.health_delta_great
		Kind.GOOD:
			return gameplay.health_delta_good
		_:
			return gameplay.health_delta_miss
