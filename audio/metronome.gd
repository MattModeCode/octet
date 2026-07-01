class_name Metronome
extends RefCounted
## Procedural click-track generator. Originally built in Stage 1 (M0) purely
## as a test fixture to give the conductor and vertical slice something to
## play against; promoted to a shared production utility in Stage 3 (M1b)
## once the calibration screen (§2.8, audio/calibration.gd) needed a real
## steady metronome to tap along to. Lives under audio/ alongside Conductor
## since it's now a first-class audio-timing utility, not test-only code.
##
## Still used by tests/fixtures and game/vertical_slice.gd as a no-binary,
## fully reproducible audio source. Not a substitute for real audio import
## (Stage 4, §3.1).

const DEFAULT_BPM: float = 120.0
const DEFAULT_BARS: int = 4
const DEFAULT_BEATS_PER_BAR: int = 4
const SAMPLE_RATE: int = 44100

const CLICK_FREQ_HZ: float = 1000.0
const CLICK_DURATION_SEC: float = 0.03


## Builds a mono 16-bit click track: one short decaying sine "click" at the
## start of every beat, silence between. Total length = bars * beats_per_bar
## beats at [param bpm].
static func build(
	bpm: float = DEFAULT_BPM,
	bars: int = DEFAULT_BARS,
	beats_per_bar: int = DEFAULT_BEATS_PER_BAR,
	sample_rate: int = SAMPLE_RATE
) -> AudioStreamWAV:
	var beat_sec := 60.0 / bpm
	var total_beats := bars * beats_per_bar
	var total_frames := int(round(beat_sec * total_beats * sample_rate))
	var click_frames := int(round(CLICK_DURATION_SEC * sample_rate))

	var data := PackedByteArray()
	data.resize(total_frames * 2) # 16-bit mono -> 2 bytes/frame, zero-filled (silence).

	for beat in total_beats:
		var beat_start_frame := int(round(beat * beat_sec * sample_rate))
		for i in click_frames:
			var frame := beat_start_frame + i
			if frame >= total_frames:
				break
			var t := float(i) / sample_rate
			var envelope := 1.0 - (float(i) / click_frames)
			var sample := sin(TAU * CLICK_FREQ_HZ * t) * envelope
			var sample_i16 := int(clampf(sample * 32767.0, -32768.0, 32767.0))
			data.encode_s16(frame * 2, sample_i16)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


## Target song time (ms) of the given zero-indexed beat, at [param bpm] --
## the alignment anchor used both by the vertical slice's single note and
## by the calibration screen's "nearest beat" error measurement.
static func beat_target_ms(beat_index: int, bpm: float = DEFAULT_BPM) -> float:
	return beat_index * (60000.0 / bpm)


## Beat interval in ms at [param bpm] -- convenience for callers rounding a
## song time to its nearest beat.
static func beat_interval_ms(bpm: float = DEFAULT_BPM) -> float:
	return 60000.0 / bpm
