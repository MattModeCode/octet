class_name GameplayMods
extends RefCounted
## Value object for the run-modifying toggles in PROJECT_BRIEF §2.6:
## No-Fail (disables failing, flags the score unranked) and Practice
## (arbitrary start point at reduced/fixed rate -- plumbing only for now;
## the actual practice-mode playback behaviour is later stage scope).
## Passed into JudgeEngine's constructor.

@export var no_fail: bool = false
@export var practice: bool = false


func _init(p_no_fail: bool = false, p_practice: bool = false) -> void:
	no_fail = p_no_fail
	practice = p_practice


## A run is ranked only when no unranked-flagging mod is active.
func is_ranked() -> bool:
	return not no_fail and not practice
