extends Node
## Conductor autoload. The single source of timing truth for Octet (M0,
## PROJECT_BRIEF §6.2): song time is derived from an AudioStreamPlayer's
## playback position, corrected for AudioServer output latency and the
## player's stored calibration offsets. Nothing in gameplay should ever
## derive judgment timing from frame delta — read Conductor.song_time_ms()
## instead.
##
## Sign convention for the two calibration offsets (SettingsStore.settings,
## §2.8), kept consistent everywhere they're applied: both are pure additive
## corrections, "positive = shift the corresponding clock later":
##   - audio_offset_ms is added to the computed song time. Increase it if
##     notes need to arrive later relative to what the player hears (e.g.
##     residual output latency beyond what AudioServer.get_output_latency()
##     already compensates for).
##   - input_offset_ms is added to the tap's timestamp before comparing it
##     to the note's target time. Increase it if the player's taps are
##     consistently judged early (raise it to shift them later and reduce
##     the measured lateness/earliness accordingly), decrease it if judged
##     consistently late.
## The Stage 3 calibration screen derives both from a tap-to-the-beat
## routine; Stage 1 only needs the hook to exist and be applied uniformly.
## Both offsets are read from SettingsStore.settings only -- no other copy.

var _player: AudioStreamPlayer
var _is_playing: bool = false
var _paused_ms: float = 0.0
var _last_song_time_ms: float = 0.0

## Lead-in / grace-period state (standardized "get ready" runway, gameplay.gd
## _ready() passing Config.gameplay.lead_in_ms into play()): while
## _lead_in_total_ms > 0.0, real playback of _pending_stream is deferred
## until _lead_in_start_usec + _lead_in_total_ms of wall-clock time
## (Time.get_ticks_usec(), not frame delta, so it can't drift under a frame
## hitch) has elapsed, and song_time_ms() reports a rising negative value
## (-lead_in -> 0) so notes fall in before any can be judged. 0.0 whenever no
## lead-in is in progress.
var _lead_in_total_ms: float = 0.0
var _lead_in_start_usec: int = 0
var _pending_stream: AudioStream
var _pending_from_ms: float = 0.0

## Emitted when the underlying AudioStreamPlayer reaches the natural end of
## its stream. Godot only fires AudioStreamPlayer.finished on real
## completion -- never on stop() or pause() -- so gameplay.gd can wait on
## this to let a song's audio play out fully instead of cutting it the
## instant the chart's last note passes.
signal playback_finished


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ConductorPlayer"
	_player.bus = "Music"
	_player.finished.connect(func() -> void: playback_finished.emit())
	add_child(_player)


func _process(_delta: float) -> void:
	if not _is_playing or _lead_in_total_ms <= 0.0:
		return
	var elapsed_ms := (Time.get_ticks_usec() - _lead_in_start_usec) / 1000.0
	if elapsed_ms < _lead_in_total_ms:
		return
	_lead_in_total_ms = 0.0
	_player.stream = _pending_stream
	_player.play(_pending_from_ms / 1000.0)
	_last_song_time_ms = _pending_from_ms + audio_offset_ms()


# ---------------------------------------------------------------------------
# Pure math -- no engine/instance state. Headless-testable without an audio
# device (tests/test_conductor.gd calls these directly via `load()`).
# ---------------------------------------------------------------------------

## Converts a raw audio-stream position (seconds, as reported by
## AudioStreamPlayer.get_playback_position(), already advanced by
## AudioServer.get_time_since_last_mix()) into conductor song time in
## milliseconds, compensating for output latency and the audio calibration
## offset.
static func compute_song_time_ms(raw_stream_sec: float, output_latency_sec: float, audio_offset_ms_value: float) -> float:
	return (raw_stream_sec - output_latency_sec) * 1000.0 + audio_offset_ms_value


## Computes the signed judgment error (ms) between a tap and a note's target
## time, applying the input calibration offset to the tap time first.
## Negative = early, positive = late, zero = exactly on time.
static func judgment_error_ms(tap_song_time_ms: float, note_target_ms: float, input_offset_ms_value: float) -> float:
	return (tap_song_time_ms + input_offset_ms_value) - note_target_ms


# ---------------------------------------------------------------------------
# Instance behaviour
# ---------------------------------------------------------------------------

## Starts (or restarts) playback of [param stream], seeked to [param from_ms],
## optionally preceded by [param lead_in_ms] of standardized "get ready" time
## during which song time is negative (rising to 0) and no audio plays.
## Defaults to 0.0 (no lead-in), so every other caller (editor preview,
## calibration, vertical-slice) is unaffected.
func play(stream: AudioStream, from_ms: float = 0.0, lead_in_ms: float = 0.0) -> void:
	_is_playing = true
	if lead_in_ms > 0.0:
		_pending_stream = stream
		_pending_from_ms = from_ms
		_lead_in_total_ms = lead_in_ms
		_lead_in_start_usec = Time.get_ticks_usec()
		_last_song_time_ms = -lead_in_ms
		_player.stream = null
		return
	_lead_in_total_ms = 0.0
	_player.stream = stream
	_player.play(from_ms / 1000.0)
	_last_song_time_ms = from_ms + audio_offset_ms()


func stop() -> void:
	_player.stop()
	_is_playing = false
	_paused_ms = 0.0
	_last_song_time_ms = 0.0
	_lead_in_total_ms = 0.0


func pause() -> void:
	if not _is_playing:
		return
	_paused_ms = song_time_ms()
	_is_playing = false
	if _lead_in_total_ms <= 0.0:
		_player.stream_paused = true


## Resuming mid-lead-in rebases the wall-clock anchor to the remaining grace
## period (not wall-clock time spent paused), so pausing during the grace
## period actually pauses its countdown instead of the audio silently
## starting at the originally-scheduled moment regardless.
func resume() -> void:
	if _is_playing:
		return
	_is_playing = true
	if _lead_in_total_ms > 0.0:
		var elapsed_ms := _lead_in_total_ms + _paused_ms
		_lead_in_start_usec = Time.get_ticks_usec() - int(elapsed_ms * 1000.0)
		return
	_player.stream_paused = false
	_last_song_time_ms = _paused_ms


## Seeks playback to [param ms] of song time (calibration offsets aside --
## this seeks the underlying stream position that song_time_ms() is derived
## from). Resets the monotonic clamp so the clock doesn't get stuck at the
## old position.
func seek_ms(ms: float) -> void:
	_player.seek(ms / 1000.0)
	_last_song_time_ms = ms
	_paused_ms = ms


func is_playing() -> bool:
	return _is_playing


## Sets variable-rate playback (editor scrub/preview, §3.6: 0.25x-1x; also
## the gameplay Double/Half speed modifiers, GameplayMods.rate) via
## AudioStreamPlayer.pitch_scale -- changes both speed and pitch together,
## which is an honest, simple implementation choice (no time-stretch DSP);
## song_time_ms() still reports the correct song position regardless of
## rate, since get_playback_position() tracks actual stream consumption,
## not real-world elapsed time.
func set_playback_rate(rate: float) -> void:
	_player.pitch_scale = rate


func playback_rate() -> float:
	return _player.pitch_scale


## Live conductor song time in milliseconds. While playing, reads the
## AudioStreamPlayer's playback position plus the time elapsed since the
## last audio mix (finer-grained than playback_position alone), compensates
## for AudioServer output latency and the audio calibration offset, then
## clamps the result to be monotonic non-decreasing -- get_time_since_last_mix
## can jitter slightly frame to frame, and judgment math must never see the
## clock step backward mid-song.
func song_time_ms() -> float:
	if not _is_playing:
		return _paused_ms

	if _lead_in_total_ms > 0.0:
		var elapsed_ms := (Time.get_ticks_usec() - _lead_in_start_usec) / 1000.0
		var lead_in_ms := -_lead_in_total_ms + minf(elapsed_ms, _lead_in_total_ms)
		if lead_in_ms < _last_song_time_ms:
			lead_in_ms = _last_song_time_ms
		_last_song_time_ms = lead_in_ms
		return lead_in_ms

	var raw_stream_sec := _player.get_playback_position() + AudioServer.get_time_since_last_mix()
	var latency_sec := AudioServer.get_output_latency()
	var computed_ms := compute_song_time_ms(raw_stream_sec, latency_sec, audio_offset_ms())

	if computed_ms < _last_song_time_ms:
		computed_ms = _last_song_time_ms
	_last_song_time_ms = computed_ms
	return computed_ms


## Reads the audio calibration offset from SettingsStore, defensively --
## SettingsStore is registered before Conductor in project.godot, but this
## guard keeps Conductor safe to use standalone (e.g. in tests/tools) too.
func audio_offset_ms() -> float:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.audio_offset_ms
	return 0.0


## Reads the input calibration offset from SettingsStore, same guard as
## audio_offset_ms().
func input_offset_ms() -> float:
	if _has_autoload("SettingsStore") and SettingsStore.settings != null:
		return SettingsStore.settings.input_offset_ms
	return 0.0


func _has_autoload(autoload_name: String) -> bool:
	return get_tree() != null and get_tree().root.has_node(autoload_name)
