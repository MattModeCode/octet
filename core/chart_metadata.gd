## Chart-level (per-difficulty) metadata. PROJECT_BRIEF.md §4.1.
class_name ChartMetadata
extends Resource

@export var title: String = ""
@export var artist: String = ""
@export var mapper: String = ""
@export var difficulty_name: String = ""
@export var star_rating: float = 0.0
@export var tags: PackedStringArray = []
@export var preview_time_ms: int = 0


## Single "Title — Difficulty" naming convention, shared by game/song_select.gd's
## difficulty sub-rows and ui/profile.gd's best-score list so a saved score and
## its picker entry always read the same way. Static (not just an instance
## method) so a caller working from a persisted score record -- which stores
## difficulty_name as a raw String, not a live ChartMetadata -- can format the
## same way without constructing one.
static func format_display_name(title: String, difficulty_name: String) -> String:
	if difficulty_name.is_empty():
		return title
	return "%s — %s" % [title, difficulty_name]
