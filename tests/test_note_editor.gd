extends RefCounted
class_name TestNoteEditor
## Tests for editor/note_editor.gd's pure note-editing operations
## (PROJECT_BRIEF §3.5-3.6). No autoload dependency needed.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "note_editor_place_tap_replaces_existing", "callable": test_place_tap_replaces_existing},
		{"name": "note_editor_place_hold_clamps_end", "callable": test_place_hold_clamps_end},
		{"name": "note_editor_delete_notes", "callable": test_delete_notes},
		{"name": "note_editor_mirror_notes", "callable": test_mirror_notes},
		{"name": "note_editor_nudge_notes", "callable": test_nudge_notes},
		{"name": "note_editor_duplicate_notes", "callable": test_duplicate_notes},
		{"name": "note_editor_notes_in_range", "callable": test_notes_in_range},
	]


func test_place_tap_replaces_existing() -> bool:
	var notes: Array[ChartNote] = []
	NoteEditor.place_tap(notes, 3, 1000)
	NoteEditor.place_tap(notes, 3, 1000) # same lane+time -- should replace, not stack.

	var ok := TestRunner._assert(notes.size() == 1, "note_editor_place_tap_replaces_existing: expected 1 note, got %d" % notes.size())
	if ok:
		print("[PASS] note_editor_place_tap_replaces_existing")
	return ok


func test_place_hold_clamps_end() -> bool:
	var notes: Array[ChartNote] = []
	var note := NoteEditor.place_hold(notes, 2, 1000, 900) # end before start -- should clamp.

	var ok := TestRunner._assert(note.type == "hold", "note_editor_place_hold_clamps_end: expected type hold")
	ok = TestRunner._assert(note.end_time_ms > note.time_ms, "note_editor_place_hold_clamps_end: expected end_time_ms > time_ms, got %d/%d" % [note.end_time_ms, note.time_ms]) and ok
	if ok:
		print("[PASS] note_editor_place_hold_clamps_end")
	return ok


func test_delete_notes() -> bool:
	var notes: Array[ChartNote] = []
	var a := NoteEditor.place_tap(notes, 0, 1000)
	NoteEditor.place_tap(notes, 1, 1000)
	var to_delete: Array[ChartNote] = [a]
	NoteEditor.delete_notes(notes, to_delete)

	var ok := TestRunner._assert(notes.size() == 1, "note_editor_delete_notes: expected 1 note remaining, got %d" % notes.size())
	ok = TestRunner._assert(notes.size() == 0 or notes[0].lane == 1, "note_editor_delete_notes: expected remaining note to be lane 1") and ok
	if ok:
		print("[PASS] note_editor_delete_notes")
	return ok


func test_mirror_notes() -> bool:
	var notes: Array[ChartNote] = []
	NoteEditor.place_tap(notes, 0, 1000)
	NoteEditor.place_tap(notes, 7, 2000)
	NoteEditor.mirror_notes(notes)

	var ok := TestRunner._assert(notes[0].lane == 7, "note_editor_mirror_notes: expected lane 0 -> 7, got %d" % notes[0].lane)
	ok = TestRunner._assert(notes[1].lane == 0, "note_editor_mirror_notes: expected lane 7 -> 0, got %d" % notes[1].lane) and ok
	if ok:
		print("[PASS] note_editor_mirror_notes")
	return ok


func test_nudge_notes() -> bool:
	var notes: Array[ChartNote] = []
	var tap := NoteEditor.place_tap(notes, 0, 1000)
	var hold := NoteEditor.place_hold(notes, 1, 2000, 2500)
	var target: Array[ChartNote] = [tap, hold]
	NoteEditor.nudge_notes(target, 50)

	var ok := TestRunner._assert(tap.time_ms == 1050, "note_editor_nudge_notes: expected tap time_ms 1050, got %d" % tap.time_ms)
	ok = TestRunner._assert(hold.time_ms == 2050, "note_editor_nudge_notes: expected hold time_ms 2050, got %d" % hold.time_ms) and ok
	ok = TestRunner._assert(hold.end_time_ms == 2550, "note_editor_nudge_notes: expected hold end_time_ms 2550, got %d" % hold.end_time_ms) and ok
	if ok:
		print("[PASS] note_editor_nudge_notes")
	return ok


func test_duplicate_notes() -> bool:
	var notes: Array[ChartNote] = []
	NoteEditor.place_tap(notes, 0, 1000)
	NoteEditor.place_hold(notes, 1, 2000, 2500)
	var copies := NoteEditor.duplicate_notes(notes, 500)

	var ok := TestRunner._assert(copies.size() == 2, "note_editor_duplicate_notes: expected 2 copies, got %d" % copies.size())
	ok = TestRunner._assert(copies[0].time_ms == 1500, "note_editor_duplicate_notes: expected copy 0 time_ms 1500, got %d" % copies[0].time_ms) and ok
	ok = TestRunner._assert(copies[1].time_ms == 2500 and copies[1].end_time_ms == 3000,
		"note_editor_duplicate_notes: expected copy 1 hold shifted to 2500-3000, got %d-%d" % [copies[1].time_ms, copies[1].end_time_ms]) and ok
	ok = TestRunner._assert(notes.size() == 2, "note_editor_duplicate_notes: original array should be untouched") and ok
	if ok:
		print("[PASS] note_editor_duplicate_notes")
	return ok


func test_notes_in_range() -> bool:
	var notes: Array[ChartNote] = []
	NoteEditor.place_tap(notes, 0, 1000)
	NoteEditor.place_tap(notes, 3, 1500)
	NoteEditor.place_tap(notes, 6, 5000) # out of range.

	var result := NoteEditor.notes_in_range(notes, 500.0, 2000.0, 0, 3)
	var ok := TestRunner._assert(result.size() == 2, "note_editor_notes_in_range: expected 2 notes in box, got %d" % result.size())
	if ok:
		print("[PASS] note_editor_notes_in_range")
	return ok
