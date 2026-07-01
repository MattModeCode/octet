## Per-machine / per-player settings: calibration offsets, scroll speed,
## and accessibility toggles. PROJECT_BRIEF.md §2.3 (scroll speed), §2.8
## (calibration offsets), DESIGN_BRIEF.md §8 (accessibility).
##
## Unlike GameplayConfig/ScoringConfig (static tuning data loaded once from
## res://), this resource is persisted per-machine to user://settings.tres
## by SettingsStore — see core/settings_store.gd.
class_name SettingsConfig
extends Resource

## Player preference for how far ahead notes are visible (approach rate).
## Independent of chart data; never affects note timing.
@export var scroll_speed: float = 1.0

## -- Calibration offsets (§2.8), measured via the calibration screen.
## Compensates for output latency between the audio clock and what the
## player hears.
@export var audio_offset_ms: float = 0.0
## Compensates for the player's device/keyboard/display latency.
@export var input_offset_ms: float = 0.0

## -- Accessibility toggles.
@export var reduced_motion: bool = false
@export var reduced_flash: bool = false
@export var colourblind_mode: bool = false

## -- Lane key bindings (§2.1), rebindable. Empty means "use
## KeybindDefaults.DEFAULT_LANE_KEYS" -- keeps existing saved settings
## resources (pre-Stage 1) backward compatible without a migration step.
## Populated/updated by LaneInput.rebind() (core/lane_input.gd).
@export var lane_keys: Array[String] = []
