## Top-level .oct chart resource. PROJECT_BRIEF.md §4.1.
##
## Mirrors the .oct JSON structure exactly:
##   format_version, metadata, audio, timing_points[], notes[]
## See core/oct_io.gd for JSON (de)serialization to/from this resource.
class_name Chart
extends Resource

@export var format_version: int = 1
@export var metadata: ChartMetadata = ChartMetadata.new()
@export var audio: ChartAudio = ChartAudio.new()
@export var timing_points: Array[TimingPoint] = []
@export var notes: Array[ChartNote] = []
