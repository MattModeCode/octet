class_name NoteEditor
extends RefCounted
## Pure note-editing operations (PROJECT_BRIEF §3.5-3.6) over a Chart's
## notes array: place tap/hold, delete, mirror, nudge, duplicate, and
## range queries for box-select. Deliberately separated from
## editor/note_timeline_view.gd (mouse/UI) and editor/undo_stack.gd
## (history) so this logic is headless-testable
## (tests/test_note_editor.gd) independent of both.
##
## Every mutating function here operates IN PLACE on the array passed in
## -- callers (editor_main.gd) are responsible for calling
## EditorUndoStack.record() with the pre-mutation state first.


## Places (or replaces, if one already exists at this exact lane+time) a
## tap note. Returns the placed note.
static func place_tap(notes: Array[ChartNote], lane: int, time_ms: int) -> ChartNote:
	remove_note_at(notes, lane, time_ms)
	var note := ChartNote.new()
	note.lane = lane
	note.time_ms = time_ms
	note.type = "tap"
	notes.append(note)
	return note


## Places (or replaces) a hold note spanning [param start_ms, param end_ms).
## end_ms is clamped to be at least 1ms after start_ms.
static func place_hold(notes: Array[ChartNote], lane: int, start_ms: int, end_ms: int) -> ChartNote:
	remove_note_at(notes, lane, start_ms)
	var note := ChartNote.new()
	note.lane = lane
	note.time_ms = start_ms
	note.type = "hold"
	note.end_time_ms = maxi(end_ms, start_ms + 1)
	notes.append(note)
	return note


## Removes any note in [param lane] whose head sits exactly at
## [param time_ms] (used to avoid stacking duplicates when re-placing).
static func remove_note_at(notes: Array[ChartNote], lane: int, time_ms: int) -> void:
	for i in range(notes.size() - 1, -1, -1):
		if notes[i].lane == lane and notes[i].time_ms == time_ms:
			notes.remove_at(i)


## Removes every note in [param to_delete] from [param notes] (by
## reference identity, since ChartNote is an Object).
static func delete_notes(notes: Array[ChartNote], to_delete: Array[ChartNote]) -> void:
	for note in to_delete:
		notes.erase(note)


## Flips lane index (7 - lane) for every note in [param target_notes] --
## PROJECT_BRIEF §3.6 "mirror (flip lanes horizontally)".
static func mirror_notes(target_notes: Array[ChartNote]) -> void:
	for note in target_notes:
		note.lane = 7 - note.lane


## Shifts every note in [param target_notes] by [param delta_ms] -- both
## head and tail for holds. Used for per-note nudge (§3.6) and for
## repositioning a pasted/duplicated selection.
static func nudge_notes(target_notes: Array[ChartNote], delta_ms: int) -> void:
	for note in target_notes:
		note.time_ms += delta_ms
		if note.type == "hold":
			note.end_time_ms += delta_ms


## Returns deep copies of [param source_notes], each shifted by
## [param offset_ms] -- the building block for both duplicate and paste.
static func duplicate_notes(source_notes: Array[ChartNote], offset_ms: int) -> Array[ChartNote]:
	var copies: Array[ChartNote] = []
	for note in source_notes:
		var copy := ChartNote.new()
		copy.lane = note.lane
		copy.time_ms = note.time_ms + offset_ms
		copy.type = note.type
		copy.end_time_ms = (note.end_time_ms + offset_ms) if note.type == "hold" else -1
		copies.append(copy)
	return copies


## Returns every note within the closed time/lane box -- the box-select
## query. [param lane_min]/[param lane_max] are inclusive, 0-7.
static func notes_in_range(notes: Array[ChartNote], start_ms: float, end_ms: float, lane_min: int, lane_max: int) -> Array[ChartNote]:
	var result: Array[ChartNote] = []
	for note in notes:
		if note.lane >= lane_min and note.lane <= lane_max and note.time_ms >= start_ms and note.time_ms <= end_ms:
			result.append(note)
	return result
