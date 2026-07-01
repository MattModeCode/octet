class_name AudioImport
extends RefCounted
## Audio import (PROJECT_BRIEF §3.1): accepts MP3, OGG Vorbis, and WAV,
## loads them as playable AudioStreams, and decodes real PCM offline (no
## realtime audio device needed) to build the waveform envelope the editor
## renders (§3.3). Automatic tempo/onset analysis (§3.2) is Stage 6 (M3)
## scope -- this only prepares the data that stage's DSP will eventually
## consume, plus what the waveform view needs today.
##
## The offline decode relies on AudioStreamPlayback.mix_audio(rate_scale,
## frames) -- a real, scriptable method present on every AudioStreamPlayback
## subclass (confirmed empirically against Godot 4.7: WAV/MP3/OggVorbis
## playback objects all expose it) that returns actual decoded PCM frames
## without needing playback through a live audio device, and returns fewer
## frames than requested once the stream is exhausted -- the end-of-stream
## signal this uses.

const SUPPORTED_EXTENSIONS: PackedStringArray = ["wav", "mp3", "ogg", "oga"]

## Chunk size (frames) pulled per mix_audio() call while decoding for the
## waveform envelope. Large enough to keep the decode loop's call count
## reasonable for a multi-minute song, small enough to keep peak
## resolution meaningful.
const DECODE_CHUNK_FRAMES: int = 8192


## Loads the audio file at [param path] as a playable AudioStream, picking
## the loader by file extension. Returns null (and pushes an error) for an
## unsupported extension or a failed load -- never crashes on bad input.
static func load_audio_file(path: String) -> AudioStream:
	var extension := path.get_extension().to_lower()
	match extension:
		"wav":
			var wav := AudioStreamWAV.load_from_file(path)
			if wav == null:
				push_error("AudioImport.load_audio_file: failed to load WAV at %s" % path)
			return wav
		"mp3":
			var mp3 := AudioStreamMP3.load_from_file(path)
			if mp3 == null:
				push_error("AudioImport.load_audio_file: failed to load MP3 at %s" % path)
			return mp3
		"ogg", "oga":
			var ogg := AudioStreamOggVorbis.load_from_file(path)
			if ogg == null:
				push_error("AudioImport.load_audio_file: failed to load OGG at %s" % path)
			return ogg
		_:
			push_error("AudioImport.load_audio_file: unsupported extension '%s' (supported: %s)" % [extension, SUPPORTED_EXTENSIONS])
			return null


## Decodes [param stream] end to end and returns a peak-amplitude envelope
## with [param bucket_count] evenly spaced buckets spanning its full
## duration -- one representative value (0.0-1.0) per bucket, the max
## absolute sample magnitude across both channels in that time slice. This
## is the data editor/waveform_view.gd renders as bars; it is a real decode
## of the actual audio, not an approximation.
##
## Note: AudioStreamPlayback exposes no public sample-rate accessor for
## compressed formats (confirmed empirically -- MP3/OggVorbis expose
## get_length() but nothing rate-related), so this buckets by actual
## decoded frame count rather than a precomputed expected total: a full
## first pass collects per-frame magnitude, then that array is split into
## bucket_count buckets. One-time editor-import cost, not a hot path.
static func build_waveform_peaks(stream: AudioStream, bucket_count: int) -> PackedFloat32Array:
	var peaks := PackedFloat32Array()
	peaks.resize(bucket_count)
	if bucket_count <= 0:
		return peaks

	var magnitudes := PackedFloat32Array()
	var playback := stream.instantiate_playback()
	playback.start()

	while true:
		var chunk: PackedVector2Array = playback.call("mix_audio", 1.0, DECODE_CHUNK_FRAMES)
		if chunk.is_empty():
			break
		for frame in chunk:
			magnitudes.append(maxf(absf(frame.x), absf(frame.y)))
		if chunk.size() < DECODE_CHUNK_FRAMES:
			break

	if magnitudes.is_empty():
		return peaks

	var frames_per_bucket := maxf(1.0, float(magnitudes.size()) / bucket_count)
	for i in magnitudes.size():
		var bucket := mini(int(float(i) / frames_per_bucket), bucket_count - 1)
		if magnitudes[i] > peaks[bucket]:
			peaks[bucket] = magnitudes[i]

	return peaks
