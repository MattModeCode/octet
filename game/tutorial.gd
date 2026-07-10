extends Control
## Lockstep tutorial trainer -- teaches the eight-lane controls one note at
## a time. Deliberately separate from game/gameplay.gd's real JudgeEngine/
## Conductor/ScoreStore path: this scene drives its own synthetic clock, so
## there is no health, no miss, and no recorded score, ever. It freezes the
## instant a note (or, for a chord, every note sharing its time_ms) reaches
## the judgment line and only resumes once the player presses the correct
## lane key(s). Reuses game/playfield_view.gd for the falling-note visual so
## the trainer looks identical to real gameplay.
##
## Routed to from game/song_select.gd's Play button when the selected
## chart's metadata.tags contains "tutorial" (tutorial/tutorial.oct is the
## only chart tagged this way), instead of the normal gameplay.tscn.

const CHART_PATH: String = "res://tutorial/tutorial.oct"
const SONG_SELECT_SCENE: String = "res://game/song_select.tscn"
## Coach-mark id (core/settings_store.gd) recorded once the trainer is
## finished or skipped, so it's tracked the same way as the onboarding
## overlays even though this isn't a CoachMark instance itself.
const COACH_ID: String = "tutorial_done"

## Extra lead-in (ms) before the first note, so play doesn't open with the
## clock already frozen on a note sitting right at the judgment line.
const LEAD_IN_MS: float = 1200.0
const GOOD_WINDOW_MS: float = 400.0
const LANE_COUNT: int = 8

## One entry per step (a step = every ChartNote sharing a time_ms -- a chord
## is naturally one step). Order and count must match tutorial/tutorial.oct's
## distinct note times: 8 single taps, 1 two-lane chord, 1 hold == 10 steps.
const STEP_COPY: Array[Dictionary] = [
	{"title": "Lane 3 -- press F", "body": "F is your [b]left index finger[/b]. Press it once the note reaches the line."},
	{"title": "Lane 4 -- press J", "body": "J is your [b]right index finger[/b] -- the mirror of F."},
	{"title": "F again", "body": "Same note -- build the habit."},
	{"title": "Alternate: J", "body": "Left, right, keep alternating."},
	{"title": "Reach for A", "body": "A is your [b]left pinky[/b], the far-left lane."},
	{"title": "Reach for ;", "body": "; is your [b]right pinky[/b], the far-right lane."},
	{"title": "Lane 1 -- press S", "body": "S is your [b]left ring finger[/b]."},
	{"title": "Lane 6 -- press L", "body": "L is your [b]right ring finger[/b]."},
	{"title": "Chords", "body": "Some notes land together. Press [b]F and J at the same time[/b]."},
	{"title": "Hold notes", "body": "Press [b]K[/b] and [b]keep holding[/b] until the tail reaches the line, then let go."},
]

@onready var _playfield: Control = %PlayfieldView
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: RichTextLabel = %BodyLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _skip_button: Button = %SkipButton
@onready var _done_overlay: Control = %DoneOverlay
@onready var _done_button: Button = %DoneButton

var _chart: Chart
## Each entry: {"time_ms": int, "notes": Array} -- one or more ChartNotes
## sharing a time_ms, in ascending time order.
var _steps: Array[Dictionary] = []
var _step_index: int = -1
## Lanes in the current tap/chord step still waiting for a correct press.
var _pending_lanes: Dictionary = {}
var _holding: bool = false
var _hold_lane: int = -1
var _hold_end_ms: float = 0.0

var _clock_ms: float = -LEAD_IN_MS
var _frozen: bool = false
var _finished: bool = false


func _ready() -> void:
	_skip_button.pressed.connect(_on_skip_pressed)
	_done_button.pressed.connect(_on_done_pressed)
	_done_overlay.visible = false

	_chart = OctIO.load_oct(CHART_PATH)
	if _chart == null:
		push_error("tutorial: failed to load %s" % CHART_PATH)
		return

	_build_steps()
	_playfield.set_chart(_chart.notes, GOOD_WINDOW_MS)
	_playfield.set_accessibility(_reduced_flash(), _reduced_motion())
	_render_instruction(0)


func _process(delta: float) -> void:
	if _finished or _chart == null:
		return

	if _holding:
		if Input.is_action_pressed(LaneInput.binding_for(_hold_lane)):
			_clock_ms += delta * 1000.0
			if _clock_ms >= _hold_end_ms:
				_clock_ms = _hold_end_ms
				_complete_step()
		# else: paused mid-hold, waiting for the key to come back down --
		# no penalty, this is the trainer's whole point.
	elif not _frozen and _step_index >= 0 and _step_index < _steps.size():
		_clock_ms += delta * 1000.0
		var target_ms: float = _steps[_step_index].time_ms
		if _clock_ms >= target_ms:
			_clock_ms = target_ms
			_freeze_on_current_step()

	_playfield.update_state(_clock_ms, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_skip_pressed()
		return

	if _finished or _holding or not _frozen:
		return
	for lane in LANE_COUNT:
		if event.is_action_pressed(LaneInput.binding_for(lane)):
			_on_lane_pressed(lane)


func _on_lane_pressed(lane: int) -> void:
	if not _pending_lanes.has(lane):
		return
	_pending_lanes.erase(lane)
	_playfield.trigger_hit_burst(lane)
	_playfield.trigger_judgment_popup(Judgment.Kind.PERFECT)
	Sfx.play_confirm()
	if _pending_lanes.is_empty():
		_on_step_lanes_cleared()


## Called once every lane in the current tap/chord step has been struck. A
## hold step switches into the held-wait state instead of completing
## immediately.
func _on_step_lanes_cleared() -> void:
	var notes: Array = _steps[_step_index].notes
	if notes.size() == 1 and String(notes[0].type) == "hold":
		var note: ChartNote = notes[0]
		_holding = true
		_frozen = false
		_hold_lane = note.lane
		_hold_end_ms = float(note.end_time_ms)
	else:
		_complete_step()


func _complete_step() -> void:
	_holding = false
	_frozen = false
	_step_index += 1
	if _step_index >= _steps.size():
		_show_done()
		return
	_render_instruction(_step_index)


## Groups _chart.notes by time_ms (ascending) into _steps -- a chord is
## naturally one step since its notes share a time_ms (the documented
## convention in core/chart_note.gd).
func _build_steps() -> void:
	var by_time: Dictionary = {}
	for note in _chart.notes:
		var t: int = note.time_ms
		if not by_time.has(t):
			by_time[t] = []
		(by_time[t] as Array).append(note)

	var times: Array = by_time.keys()
	times.sort()
	_steps.clear()
	for t in times:
		_steps.append({"time_ms": t, "notes": by_time[t]})

	if _steps.size() != STEP_COPY.size():
		push_error("tutorial: STEP_COPY has %d entries but %s has %d distinct note times -- keep them in sync" % [STEP_COPY.size(), CHART_PATH, _steps.size()])


func _render_instruction(index: int) -> void:
	_step_index = index
	var copy: Dictionary = STEP_COPY[index] if index < STEP_COPY.size() else {}
	_title_label.text = String(copy.get("title", ""))
	_body_label.text = String(copy.get("body", ""))
	_progress_label.text = "%d / %d" % [index + 1, _steps.size()]


## Freezes the clock the instant the current step's note(s) reach the
## judgment line, and records which lanes still need a correct press.
func _freeze_on_current_step() -> void:
	_frozen = true
	_pending_lanes.clear()
	for note in _steps[_step_index].notes:
		_pending_lanes[int(note.lane)] = true


func _show_done() -> void:
	_finished = true
	SettingsStore.mark_coach_seen(COACH_ID)
	_done_overlay.visible = true


func _on_done_pressed() -> void:
	SceneRouter.goto_scene(SONG_SELECT_SCENE)


func _on_skip_pressed() -> void:
	SettingsStore.mark_coach_seen(COACH_ID)
	SceneRouter.goto_scene(SONG_SELECT_SCENE)


func _reduced_flash() -> bool:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.reduced_flash
	return false


func _reduced_motion() -> bool:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.reduced_motion
	return false


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
