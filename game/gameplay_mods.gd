class_name GameplayMods
extends RefCounted
## Value object for the run-modifying toggles in PROJECT_BRIEF §2.6:
## No-Fail (disables failing, flags the score unranked) and Practice
## (arbitrary start point at reduced/fixed rate -- plumbing only for now;
## the actual practice-mode playback behaviour is later stage scope).
## Passed into JudgeEngine's constructor.
##
## Extended for the Modifiers screen (ui/modifiers.gd) with: rate (Double/
## Half speed, mutually exclusive by construction since it's a single float
## rather than two bools), window_scale (Easy mode -- widens all judgment
## windows), sudden_death (fail immediately on the first discrete miss), and
## autoplay (perfect auto-play, badge shown in gameplay.gd).

## Easy mode's window multiplier -- kept here as the single tunable rather
## than scattered through gameplay.gd/judge_engine.gd.
const EASY_WINDOW_SCALE: float = 1.6

const RATE_HALF: float = 0.5
const RATE_NORMAL: float = 1.0
const RATE_DOUBLE: float = 2.0

@export var no_fail: bool = false
@export var practice: bool = false
@export var rate: float = RATE_NORMAL
@export var window_scale: float = 1.0
@export var sudden_death: bool = false
@export var autoplay: bool = false


func _init(p_no_fail: bool = false, p_practice: bool = false, p_rate: float = RATE_NORMAL,
		p_window_scale: float = 1.0, p_sudden_death: bool = false, p_autoplay: bool = false) -> void:
	no_fail = p_no_fail
	practice = p_practice
	rate = p_rate
	window_scale = p_window_scale
	sudden_death = p_sudden_death
	autoplay = p_autoplay


## A run is ranked only when no unranked-flagging mod is active. Any
## deviation from vanilla -- including Sudden Death, which is strictly
## harder than default play -- is treated as unranked for simplicity.
func is_ranked() -> bool:
	return (not no_fail and not practice and not sudden_death and not autoplay
		and is_equal_approx(rate, RATE_NORMAL) and is_equal_approx(window_scale, 1.0))
