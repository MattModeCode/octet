class_name EditorUndoStack
extends RefCounted
## Snapshot-based undo/redo (PROJECT_BRIEF §3.6 "undo/redo with full
## history") over a Chart's notes array. Snapshotting the whole (small,
## rhythm-chart-sized) notes array before each mutation is simpler and
## less bug-prone than a command-object pattern with per-operation
## do()/undo() closures, at a memory cost that's negligible for chart-sized
## note counts.
##
## Usage: call record(notes) with the PRE-mutation state immediately
## before mutating notes in place (via editor/note_editor.gd), then on
## undo/redo, replace the chart's notes array with what this returns.

const MAX_HISTORY: int = 200

var _undo_stack: Array = []
var _redo_stack: Array = []


## Records [param notes] (deep-copied) as an undo point and clears the
## redo stack -- call this BEFORE mutating notes, not after.
func record(notes: Array[ChartNote]) -> void:
	_undo_stack.append(_snapshot(notes))
	if _undo_stack.size() > MAX_HISTORY:
		_undo_stack.pop_front()
	_redo_stack.clear()


## Pops the last recorded state, pushing [param current_notes] onto the
## redo stack first. Returns [param current_notes] unchanged if there's
## nothing to undo.
func undo(current_notes: Array[ChartNote]) -> Array[ChartNote]:
	if _undo_stack.is_empty():
		return current_notes
	_redo_stack.append(_snapshot(current_notes))
	return _undo_stack.pop_back()


## Pops the last undone state, pushing [param current_notes] onto the undo
## stack first. Returns [param current_notes] unchanged if there's nothing
## to redo.
func redo(current_notes: Array[ChartNote]) -> Array[ChartNote]:
	if _redo_stack.is_empty():
		return current_notes
	_undo_stack.append(_snapshot(current_notes))
	return _redo_stack.pop_back()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


static func _snapshot(notes: Array[ChartNote]) -> Array[ChartNote]:
	var copy: Array[ChartNote] = []
	for note in notes:
		copy.append(note.duplicate())
	return copy
