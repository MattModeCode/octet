extends Control
## Reusable first-visit onboarding overlay: a translucent scrim with an
## optional spotlight cutout around a target Control, a message card, and
## Next/Skip navigation through a multi-step sequence.
##
## Net-new component with no Claude Design MCP mockup -- CLAUDE.md's
## design-fidelity rule normally requires re-fetching a mockup before
## building UI, but onboarding coach-marks have no mockup to fetch (a
## user-directed exception, confirmed for this feature). Built from
## DesignTokens/existing fonts to match the rest of the app rather than
## guessing at new colours. Pure display + step-sequencing, no class_name
## (same convention as ui/components/pill_tab_bar.gd).
##
## Usage: instance this scene, add as the last child of the current screen
## (so it paints on top -- it also sets a high z_index as a second guard),
## then call show_sequence() with one dictionary per step:
## {"target": Control or null, "title": String, "body": String}. A null
## target centers the card with no spotlight (e.g. a closing "you're ready"
## step). Connect `finished` (sequence completed or skipped) to know when
## it's done; the overlay frees itself right after emitting either signal.

signal finished
signal skipped

const SCRIM_COLOR: Color = Color(0.047059, 0.039216, 0.058824, 0.78) # COLOR_INK @ 0.78 alpha
const SPOTLIGHT_PADDING: float = 12.0
const SPOTLIGHT_BORDER_WIDTH: float = 2.0
const CARD_WIDTH: float = 360.0
const CARD_MARGIN: float = 20.0
const SCREEN_EDGE_MARGIN: float = 16.0

var _steps: Array[Dictionary] = []
var _index: int = -1

var _card: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _progress_label: Label
var _next_button: Button
var _skip_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4096 # Control's max -- guarantees this paints above the host screen
	_build_card()
	resized.connect(queue_redraw)


## Starts (or restarts) the sequence from its first step. [param steps] is a
## non-empty Array of {"target": Control (or null), "title": String,
## "body": String} dictionaries, shown in order.
func show_sequence(steps: Array[Dictionary]) -> void:
	if steps.is_empty():
		push_error("CoachMark.show_sequence: steps is empty")
		queue_free()
		return
	_steps = steps
	_index = 0
	_render_step()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_skip_pressed()


func _current_target() -> Control:
	if _index < 0 or _index >= _steps.size():
		return null
	var target := _steps[_index].get("target") as Control
	if target == null or not is_instance_valid(target):
		return null
	# A target that hasn't been through a layout pass yet reports a
	# zero-area global rect -- spotlighting that pins the highlight (and the
	# card position derived from it) to the top-left corner instead of the
	# real control. Treat it the same as "no target" (full scrim, centred
	# card) rather than drawing a bogus spotlight.
	if target.get_global_rect().size == Vector2.ZERO:
		return null
	return target


func _render_step() -> void:
	var step: Dictionary = _steps[_index]
	_title_label.text = String(step.get("title", ""))
	_body_label.text = String(step.get("body", ""))
	_progress_label.text = "%d / %d" % [_index + 1, _steps.size()]
	_next_button.text = "Got it" if _index == _steps.size() - 1 else "Next"
	queue_redraw()
	# Card height depends on the body text just set, which Godot only
	# resolves after a layout pass -- defer positioning one frame so
	# _card.size.y is accurate instead of stale/zero.
	call_deferred("_position_card")


func _on_next_pressed() -> void:
	_index += 1
	if _index >= _steps.size():
		_finish(false)
		return
	_render_step()


func _on_skip_pressed() -> void:
	_finish(true)


func _finish(was_skipped: bool) -> void:
	if was_skipped:
		skipped.emit()
	finished.emit()
	queue_free()


func _draw() -> void:
	var target := _current_target()
	if target == null or not is_instance_valid(target):
		draw_rect(Rect2(Vector2.ZERO, size), SCRIM_COLOR)
		return

	var rect := _spotlight_rect(target)
	draw_rect(Rect2(0.0, 0.0, size.x, rect.position.y), SCRIM_COLOR) # top band
	draw_rect(Rect2(0.0, rect.end.y, size.x, size.y - rect.end.y), SCRIM_COLOR) # bottom band
	draw_rect(Rect2(0.0, rect.position.y, rect.position.x, rect.size.y), SCRIM_COLOR) # left band
	draw_rect(Rect2(rect.end.x, rect.position.y, size.x - rect.end.x, rect.size.y), SCRIM_COLOR) # right band
	draw_rect(rect, DesignTokens.COLOR_PINK, false, SPOTLIGHT_BORDER_WIDTH)


## [param target]'s screen rect, padded and clamped to this overlay's own
## bounds so a target flush against an edge doesn't push the spotlight rect
## (and therefore a scrim band) off-screen into negative/oversized values.
func _spotlight_rect(target: Control) -> Rect2:
	var rect := target.get_global_rect().grow(SPOTLIGHT_PADDING)
	return rect.intersection(Rect2(Vector2.ZERO, size))


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	# Hidden until _position_card() has sized and placed it at least once --
	# otherwise the card can flash at its default zero/tiny size in the
	# top-left corner for a frame before its first real position lands.
	_card.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.COLOR_SURFACE_RAISED
	style.border_width_left = 3
	style.border_color = DesignTokens.COLOR_PINK
	style.set_corner_radius_all(DesignTokens.CORNER_RADIUS_CARD)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_card.add_child(vbox)

	_title_label = Label.new()
	# Same explicit-width fix as _body_label below: AUTOWRAP_WORD_SMART with
	# no known width wraps against a ~1px minimum (one character per line),
	# which is what actually produced the near-full-screen blank-looking
	# card -- not the body text, the title. get_minimum_size() on an
	# unconstrained autowrapping Label was the dominant term (699px seen for
	# a 29-character title), dwarfing the 44px-floored body.
	_title_label.custom_minimum_size = Vector2(CARD_WIDTH - 40.0, 0.0)
	_title_label.add_theme_font_override("font", load("res://assets/fonts/font_display.tres"))
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_PRIMARY)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	# Explicit width, not just a height floor: fit_content wraps text against
	# whatever width the label currently has, and until a real Container
	# layout pass has propagated the card's width down to this child, that
	# width is 0. get_combined_minimum_size() then estimates height against a
	# near-zero wrap width -- every word forced onto its own line -- which is
	# what made the card balloon to a near-full-screen-height blank box on
	# screens that show the coach before a layout pass has landed (Map Hub's
	# async-loaded grid). CARD_WIDTH minus the card's 20px+20px content
	# margins gives the real final width up front so the very first fit
	# calculation is already correct.
	_body_label.custom_minimum_size = Vector2(CARD_WIDTH - 40.0, 44.0)
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.add_theme_font_override("normal_font", load("res://assets/fonts/font_ui.tres"))
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	_body_label.add_theme_color_override("default_color", DesignTokens.COLOR_TEXT_SECONDARY)
	vbox.add_child(_body_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	_progress_label = Label.new()
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_override("font", load("res://assets/fonts/font_mono.tres"))
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", DesignTokens.COLOR_TEXT_MUTED)
	footer.add_child(_progress_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.flat = true
	_skip_button.set_meta(Sfx.NO_CLICK_SFX_META, true)
	_skip_button.pressed.connect(_on_skip_pressed)
	footer.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.set_meta(Sfx.NO_CLICK_SFX_META, true)
	_next_button.pressed.connect(_on_next_pressed)
	footer.add_child(_next_button)

	# _position_card() reads _card.size.y, which RichTextLabel.fit_content only
	# resolves after a real layout pass -- a single deferred call (as
	# _render_step() does for the *first* positioning) can still run before
	# that pass lands on screens whose steps are built from dynamic content
	# (Song Select's song list, Map Hub's async-loaded grid). Re-positioning
	# on every `resized` makes it self-correcting instead of a one-shot guess.
	_card.resized.connect(_position_card)


## Places _card near the current step's spotlight (below it if there's
## room, above it otherwise), or centers it when the step has no target.
## Deferred one frame past _render_step() so the title/body text is already
## assigned when this runs -- but a deferred call plus a `resized` signal
## are still just heuristics for "has fit_content resolved yet", and on
## screens that build their coach steps from async content (Map Hub's
## grid) the heuristic can lose the race, leaving _card.size stale/zero
## and collapsing the card to an invisible sliver. Force the size instead
## of trusting it: get_combined_minimum_size() computes the PanelContainer's
## content-driven minimum synchronously, with no layout-pass wait.
func _position_card() -> void:
	_card.size = _card.get_combined_minimum_size()
	# Defence in depth: whatever the cause, a card taller than the overlay
	# itself is never correct -- clamp so a bad fit_content estimate degrades
	# to a scrollless-but-visible oversized card rather than an unusable
	# near-full-screen blank one.
	_card.size.y = minf(_card.size.y, size.y - SCREEN_EDGE_MARGIN * 2.0)
	_card.visible = true
	var target := _current_target()
	if target == null or not is_instance_valid(target):
		_card.position = (size - _card.size) * 0.5
		return

	var rect := _spotlight_rect(target)
	var card_x := clampf(rect.get_center().x - CARD_WIDTH * 0.5, SCREEN_EDGE_MARGIN, size.x - CARD_WIDTH - SCREEN_EDGE_MARGIN)
	var top_space := rect.position.y
	var bottom_space := size.y - rect.end.y
	var card_y: float
	if bottom_space >= _card.size.y + CARD_MARGIN or bottom_space >= top_space:
		card_y = rect.end.y + CARD_MARGIN
	else:
		card_y = rect.position.y - _card.size.y - CARD_MARGIN
	_card.position = Vector2(card_x, clampf(card_y, SCREEN_EDGE_MARGIN, size.y - _card.size.y - SCREEN_EDGE_MARGIN))
