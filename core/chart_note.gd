## A single playable note in a chart.
## PROJECT_BRIEF.md §4.1 / §2.2.
##
## There is deliberately no separate "chord" type: per the brief, "a chord
## is simply multiple notes sharing a time_ms" — a chord is just two or
## more ChartNote entries with the same time_ms on different lanes.
class_name ChartNote
extends Resource

## Lane index, 0-7 (left to right).
@export var lane: int = 0
@export var time_ms: int = 0
## "tap" or "hold".
@export var type: String = "tap"
## Only meaningful when type == "hold"; -1 (unset) for taps.
@export var end_time_ms: int = -1
