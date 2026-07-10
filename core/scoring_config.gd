## Score-value and star-rating tunables. PROJECT_BRIEF.md §2.5 (scoring),
## §2.9 (star rating).
class_name ScoringConfig
extends Resource

## Base points awarded per note at a Perfect judgment before the combo
## multiplier is applied (§2.5 — "sum of per-note base points x current
## multiplier"). Lowered from the original 300 alongside the move to an
## uncapped linear combo multiplier (JudgeEngine.current_multiplier —
## multiplier == combo, e.g. a 100-combo Perfect scores base * 100), which
## would otherwise blow totals up far beyond earlier runs.
@export var base_note_score: int = 100

## -- Modifier score multipliers. Revamp: GameplayMods.score_multiplier()
## reads these to scale a run's entire score up or down based on which
## mods are active, stacked multiplicatively. Harder mods score more,
## easier ones score less; Autopilot scores nothing since it isn't really
## "played." Tunable here rather than hard-coded in gameplay_mods.gd.
@export var mod_double_speed_mult: float = 2.0
@export var mod_half_speed_mult: float = 0.5
@export var mod_easy_mult: float = 0.7
@export var mod_no_fail_mult: float = 0.8
@export var mod_sudden_death_mult: float = 1.2
@export var mod_autoplay_mult: float = 0.0

## -- Star-rating formula weights (§2.9).
## TODO: the actual star-rating formula (combining these into a single
## number per PROJECT_BRIEF §2.9/§9 "star-rating formula — tune with
## playtesting") is deferred to the star-rating implementation, which lands
## alongside song-select/hub display in a later stage. These weights are
## exposed now so they're tunable from the start rather than hard-coded
## later.
@export var star_density_weight: float = 1.0
@export var star_chord_hold_complexity_weight: float = 1.0
@export var star_pattern_speed_weight: float = 1.0
