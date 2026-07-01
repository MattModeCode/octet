## Config autoload. Loads static, non-per-user tuning data once at startup:
## gameplay tunables (timing windows, health, scoring/grade thresholds) and
## scoring/star-rating weights. See core/gameplay_config.gd and
## core/scoring_config.gd for field docs, and config/gameplay.tres /
## config/scoring.tres for the actual tuned values.
##
## For per-machine / per-player settings that persist across launches
## (calibration offsets, scroll speed, accessibility toggles), see the
## SettingsStore autoload (core/settings_store.gd) instead.
extends Node

const GAMEPLAY_CONFIG_PATH: String = "res://config/gameplay.tres"
const SCORING_CONFIG_PATH: String = "res://config/scoring.tres"

var gameplay: GameplayConfig
var scoring: ScoringConfig

## Default lane->key mapping (PROJECT_BRIEF §2.1), exposed for convenience.
var default_lane_keys: Array[String] = KeybindDefaults.DEFAULT_LANE_KEYS


func _ready() -> void:
	gameplay = load(GAMEPLAY_CONFIG_PATH) as GameplayConfig
	if gameplay == null:
		push_error("Config: failed to load %s, falling back to defaults" % GAMEPLAY_CONFIG_PATH)
		gameplay = GameplayConfig.new()

	scoring = load(SCORING_CONFIG_PATH) as ScoringConfig
	if scoring == null:
		push_error("Config: failed to load %s, falling back to defaults" % SCORING_CONFIG_PATH)
		scoring = ScoringConfig.new()
