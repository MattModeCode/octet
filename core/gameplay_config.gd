## Static gameplay tunables: timing windows, scoring weights, health deltas,
## and grade thresholds. PROJECT_BRIEF.md §2.4 (timing windows), §2.5
## (scoring/grade), §2.6 (health). Defaults below are the brief's starting
## values — "tune with playtesting" per §9, hence everything is exported and
## editable via config/gameplay.tres rather than hard-coded in gameplay code.
class_name GameplayConfig
extends Resource

## -- Timing windows (§2.4), symmetric around the note's target time, ms.
@export var window_perfect_ms: float = 25.0
@export var window_great_ms: float = 60.0
@export var window_good_ms: float = 110.0

## -- Accuracy weights per judgment (§2.4).
@export var weight_perfect: float = 1.0
@export var weight_great: float = 0.66
@export var weight_good: float = 0.33
@export var weight_miss: float = 0.0

## -- Health deltas per judgment (§2.6).
@export var health_delta_perfect: float = 1.0
@export var health_delta_great: float = 0.5
@export var health_delta_good: float = -1.0
@export var health_delta_miss: float = -6.0
@export var health_start: float = 100.0
## Seconds to hold the "FAILED" state (frozen gameplay) before auto-routing
## to the results screen. Only reached when no_fail is off -- see
## game/gameplay.gd's _on_song_failed().
@export var fail_exit_delay_sec: float = 1.0

## Standardized "get ready" runway before any notes fall or audio plays,
## milliseconds, applied uniformly to every song via
## Conductor.play(stream, 0.0, lead_in_ms) in game/gameplay.gd's _ready().
@export var lead_in_ms: float = 2000.0

## -- Combo (§2.5). Multiplier = max(1, combo) -- linear and uncapped, so a
## 100-combo hit scores 100x its base value. Scales score only, never
## accuracy. Replaces the earlier stepped/capped ladder (was 1 + floor(combo
## / step), capped at 4x) per the points-revamp: points should scale
## directly with combo rather than plateauing.


## -- Hold ticks (§2.2/§2.4). Interval between per-tick credit awards while
## a hold is held between its head and tail.
@export var hold_tick_interval_ms: float = 100.0

## -- Grade thresholds (§2.5), evaluated against final accuracy.
## Below grade_c_threshold = D.
@export var grade_ss_threshold: float = 1.0
@export var grade_s_threshold: float = 0.95
@export var grade_a_threshold: float = 0.90
@export var grade_b_threshold: float = 0.80
@export var grade_c_threshold: float = 0.70
