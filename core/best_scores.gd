class_name BestScores
extends Resource
## Serialized payload for core/score_store.gd's user://scores.tres, same
## "typed Resource, ResourceSaver.save()" pattern as
## core/settings_config.gd/settings_store.gd.
##
## entries: String chart_path -> Dictionary{"score": int, "accuracy": float,
## "grade": String, "max_combo": int, "difficulty_name": String,
## "star_rating": float}. difficulty_name/star_rating (added alongside the
## fan-out difficulty picker) let a saved score display its difficulty level
## without re-reading the .oct -- entries written before this change simply
## lack the two keys, so readers use Dictionary.get() with an empty-string/
## zero default rather than assuming they're present. A plain Dictionary of
## Dictionaries (rather than a per-entry Resource subclass) keeps every
## stored value a primitive Variant, which ResourceSaver's .tres text format
## round-trips with no sub-resource bookkeeping.
@export var entries: Dictionary = {}
