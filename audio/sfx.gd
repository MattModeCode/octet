extends Node
## Sfx autoload -- procedurally-synthesized UI sound effects (click, back,
## confirm). No sound assets exist anywhere in the repo yet, so these are
## generated once at boot the same way audio/metronome.gd generates its
## click track: short decaying sine tones, no binary files to ship or
## license. Played through the "SFX" bus (audio/default_bus_layout.tres) so
## they're automatically governed by the existing settings SFX slider
## (core/settings_store.gd's set_bus_volume("SFX", ...)) with no extra
## wiring needed here.
##
## There is no shared base UI script across screens to hook centrally
## (every screen extends Control directly and wires its own buttons), so
## instead this autoload watches get_tree().node_added and connects every
## BaseButton's pressed signal itself -- covers current and dynamically
## built buttons (song rows, map-hub cards, tab chips, ...) tree-wide with
## no per-screen edits. A button opts out of the generic click (because it
## already triggers a more specific cue, e.g. song_select.gd's Play button
## uses play_confirm() instead) by setting the NO_CLICK_SFX_META flag.

const SFX_BUS: String = "SFX"
const SAMPLE_RATE: int = 44100
const PLAYER_POOL_SIZE: int = 4

## A button with this metadata key set true is skipped by the generic
## auto-click hook (see _on_button_pressed). Checked at press time rather
## than at connect time, since screens set this in their own _ready() which
## may run after this autoload has already seen and connected the button.
const NO_CLICK_SFX_META: String = "no_click_sfx"

const CLICK_FREQ_HZ: float = 880.0
const CLICK_DURATION_SEC: float = 0.045
const CLICK_AMPLITUDE: float = 0.5

const BACK_FREQ_HZ: float = 520.0
const BACK_DURATION_SEC: float = 0.06
const BACK_AMPLITUDE: float = 0.5

const CONFIRM_FIRST_FREQ_HZ: float = 660.0
const CONFIRM_SECOND_FREQ_HZ: float = 990.0
const CONFIRM_NOTE_DURATION_SEC: float = 0.05
const CONFIRM_AMPLITUDE: float = 0.55

var _click_stream: AudioStreamWAV
var _back_stream: AudioStreamWAV
var _confirm_stream: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0


func _ready() -> void:
	_click_stream = _build_tone(CLICK_FREQ_HZ, CLICK_DURATION_SEC, CLICK_AMPLITUDE)
	_back_stream = _build_tone(BACK_FREQ_HZ, BACK_DURATION_SEC, BACK_AMPLITUDE)
	_confirm_stream = _build_confirm_tone()

	# Small round-robin pool so two clicks in quick succession (e.g. a fast
	# double-tap) don't cut each other off the way a single shared player
	# restarting mid-playback would.
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)

	get_tree().node_added.connect(_on_node_added)


func play_click() -> void:
	_play(_click_stream)


func play_back() -> void:
	_play(_back_stream)


func play_confirm() -> void:
	_play(_confirm_stream)


func _play(stream: AudioStreamWAV) -> void:
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stream = stream
	player.play()


## Connects every button that ever enters the tree to the generic click
## sound. is_connected() guards against double-connecting a button that's
## removed and re-added to the tree (node_added fires again on re-entry).
func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	var button := node as BaseButton
	var callable := _on_button_pressed.bind(button)
	if button.pressed.is_connected(callable):
		return
	button.pressed.connect(callable)


func _on_button_pressed(button: BaseButton) -> void:
	if button.has_meta(NO_CLICK_SFX_META) and bool(button.get_meta(NO_CLICK_SFX_META)):
		return
	play_click()


## Builds a mono 16-bit decaying sine tone -- same technique as
## audio/metronome.gd's _render_click, generalized with frequency/duration/
## amplitude so click/back can share this instead of duplicating the DSP.
static func _build_tone(freq_hz: float, duration_sec: float, amplitude: float) -> AudioStreamWAV:
	var frames := int(round(duration_sec * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(frames * 2)
	_render_note(data, 0, frames, freq_hz, amplitude)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Two-note ascending blip for confirm/primary actions -- concatenates two
## short decaying tones back to back so it reads as more "final" than a
## bare single-tone click.
static func _build_confirm_tone() -> AudioStreamWAV:
	var note_frames := int(round(CONFIRM_NOTE_DURATION_SEC * SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(note_frames * 2 * 2)
	_render_note(data, 0, note_frames, CONFIRM_FIRST_FREQ_HZ, CONFIRM_AMPLITUDE)
	_render_note(data, note_frames, note_frames, CONFIRM_SECOND_FREQ_HZ, CONFIRM_AMPLITUDE)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Writes one decaying sine note into [param data] (raw 16-bit mono PCM)
## starting at [param start_frame], [param note_frames] long.
static func _render_note(data: PackedByteArray, start_frame: int, note_frames: int, freq_hz: float, amplitude: float) -> void:
	for i in note_frames:
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / note_frames)
		var sample := sin(TAU * freq_hz * t) * envelope * amplitude
		var sample_i16 := int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data.encode_s16((start_frame + i) * 2, sample_i16)
