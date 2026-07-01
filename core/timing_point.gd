## A single tempo/meter change point in a chart.
## PROJECT_BRIEF.md §4.1 / §3.4 — the first timing point in a chart's
## timing_points array defines the song's initial offset; later points
## mark tempo changes.
class_name TimingPoint
extends Resource

@export var time_ms: int = 0
@export var bpm: float = 120.0
@export var meter: int = 4
