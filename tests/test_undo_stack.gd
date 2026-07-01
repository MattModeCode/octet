extends RefCounted
class_name TestUndoStack
## Tests for editor/undo_stack.gd's snapshot-based undo/redo.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "undo_stack_round_trip", "callable": test_round_trip},
		{"name": "undo_stack_noop_when_empty", "callable": test_noop_when_empty},
		{"name": "undo_stack_record_clears_redo", "callable": test_record_clears_redo},
	]


func test_round_trip() -> bool:
	var stack := EditorUndoStack.new()
	var notes: Array[ChartNote] = []

	stack.record(notes) # snapshot: []
	notes = NoteEditor.duplicate_notes(notes, 0) # placeholder mutation step
	NoteEditor.place_tap(notes, 0, 1000) # notes = [A]

	stack.record(notes) # snapshot: [A]
	NoteEditor.place_tap(notes, 1, 2000) # notes = [A, B]

	var ok := TestRunner._assert(notes.size() == 2, "undo_stack_round_trip: expected 2 notes before undo, got %d" % notes.size())

	notes = stack.undo(notes) # -> [A]
	ok = TestRunner._assert(notes.size() == 1, "undo_stack_round_trip: expected 1 note after first undo, got %d" % notes.size()) and ok

	notes = stack.undo(notes) # -> []
	ok = TestRunner._assert(notes.size() == 0, "undo_stack_round_trip: expected 0 notes after second undo, got %d" % notes.size()) and ok

	notes = stack.redo(notes) # -> [A]
	ok = TestRunner._assert(notes.size() == 1, "undo_stack_round_trip: expected 1 note after first redo, got %d" % notes.size()) and ok

	notes = stack.redo(notes) # -> [A, B]
	ok = TestRunner._assert(notes.size() == 2, "undo_stack_round_trip: expected 2 notes after second redo, got %d" % notes.size()) and ok

	if ok:
		print("[PASS] undo_stack_round_trip")
	return ok


func test_noop_when_empty() -> bool:
	var stack := EditorUndoStack.new()
	var notes: Array[ChartNote] = []
	NoteEditor.place_tap(notes, 0, 1000)

	var ok := TestRunner._assert(not stack.can_undo(), "undo_stack_noop_when_empty: expected can_undo() false initially")
	var result := stack.undo(notes)
	ok = TestRunner._assert(result.size() == 1, "undo_stack_noop_when_empty: undo() with empty stack should return notes unchanged") and ok
	ok = TestRunner._assert(not stack.can_redo(), "undo_stack_noop_when_empty: expected can_redo() false initially") and ok
	if ok:
		print("[PASS] undo_stack_noop_when_empty")
	return ok


func test_record_clears_redo() -> bool:
	var stack := EditorUndoStack.new()
	var notes: Array[ChartNote] = []
	stack.record(notes)
	NoteEditor.place_tap(notes, 0, 1000)
	notes = stack.undo(notes) # populates redo stack

	var ok := TestRunner._assert(stack.can_redo(), "undo_stack_record_clears_redo: expected can_redo() true after undo")
	stack.record(notes) # a fresh edit should invalidate the old redo branch
	ok = TestRunner._assert(not stack.can_redo(), "undo_stack_record_clears_redo: expected can_redo() false after a new record()") and ok
	if ok:
		print("[PASS] undo_stack_record_clears_redo")
	return ok
