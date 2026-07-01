## Score-value and star-rating tunables. PROJECT_BRIEF.md §2.5 (scoring),
## §2.9 (star rating).
class_name ScoringConfig
extends Resource

## Base points awarded per note at a Perfect judgment before the combo
## multiplier is applied (§2.5 — "sum of per-note base points x current
## multiplier").
@export var base_note_score: int = 300

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
