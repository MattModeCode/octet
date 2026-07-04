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


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "ConductorPlayer"
	add_child(_player)


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

## Starts (or restarts) playback of [param stream], seeked to [param from_ms].
func play(stream: AudioStream, from_ms: float = 0.0) -> void:
	_player.stream = stream
	_player.play(from_ms / 1000.0)
	_is_playing = true
	_last_song_time_ms = from_ms + audio_offset_ms()


func stop() -> void:
	_player.stop()
	_is_playing = false
	_paused_ms = 0.0
	_last_song_time_ms = 0.0


func pause() -> void:
	if not _is_playing:
		return
	_paused_ms = song_time_ms()
	_player.stream_paused = true
	_is_playing = false


func resume() -> void:
	if _is_playing:
		return
	_player.stream_paused = false
	_is_playing = true
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


## Sets variable-rate playback (editor scrub/preview, §3.6: 0.25x-1x) via
## AudioStreamPlayer.pitch_scale -- changes both speed and pitch together,
## which is an honest, simple implementation choice (no time-stretch DSP);
## song_time_ms() still reports the correct song position regardless of
## rate, since get_playback_position() tracks actual stream consumption,
## not real-world elapsed time. Gameplay never calls this -- it always
## plays at rate 1.0.
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
