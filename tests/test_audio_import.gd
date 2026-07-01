extends RefCounted
class_name TestAudioImport
## Tests for editor/audio_import.gd's offline decode pipeline. No real
## MP3/OGG fixture is committed (see Metronome doc comment on why no audio
## binaries are checked in) -- WAV round-trips through a real file via
## AudioStreamWAV.save_to_wav()/AudioImport.load_audio_file(), and the
## waveform decode is verified directly against a Metronome click track,
## which is real, reproducible PCM.

const TEST_WAV_PATH: String = "user://test_audio_import.wav"


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "audio_import_load_wav_round_trip", "callable": test_load_wav_round_trip},
		{"name": "audio_import_unsupported_extension", "callable": test_unsupported_extension},
		{"name": "audio_import_waveform_peaks_match_clicks", "callable": test_waveform_peaks_match_clicks},
		{"name": "audio_import_decode_full_pcm_and_sample_rate", "callable": test_decode_full_pcm_and_sample_rate},
	]


func test_load_wav_round_trip() -> bool:
	var stream := Metronome.build(120.0, 1, 4) # 2s of audio.
	var save_err := stream.save_to_wav(TEST_WAV_PATH)
	var ok := TestRunner._assert(save_err == OK, "audio_import_load_wav_round_trip: save_to_wav failed with %d" % save_err)
	if not ok:
		return false

	var loaded := AudioImport.load_audio_file(TEST_WAV_PATH)
	ok = TestRunner._assert(loaded != null, "audio_import_load_wav_round_trip: load_audio_file returned null") and ok
	if loaded != null:
		ok = TestRunner._assert(is_equal_approx(loaded.get_length(), 2.0), "audio_import_load_wav_round_trip: expected ~2.0s length, got %s" % str(loaded.get_length())) and ok
	if ok:
		print("[PASS] audio_import_load_wav_round_trip")
	return ok


func test_unsupported_extension() -> bool:
	var result := AudioImport.load_audio_file("user://not_a_real_file.xyz")
	var ok := TestRunner._assert(result == null, "audio_import_unsupported_extension: expected null for unsupported extension")
	if ok:
		print("[PASS] audio_import_unsupported_extension")
	return ok


func test_waveform_peaks_match_clicks() -> bool:
	var stream := Metronome.build(120.0, 1, 4) # 2s, clicks at 0/500/1000/1500ms.
	var samples := AudioImport.decode_full_pcm(stream)
	var peaks := AudioImport.build_waveform_peaks(samples, 40) # 50ms/bucket.

	var ok := TestRunner._assert(peaks.size() == 40, "audio_import_waveform_peaks_match_clicks: expected 40 buckets, got %d" % peaks.size())
	var click_buckets: Array[int] = [0, 10, 20, 30]
	for bucket in click_buckets:
		ok = TestRunner._assert(peaks[bucket] > 0.5, "audio_import_waveform_peaks_match_clicks: bucket %d expected a click peak, got %s" % [bucket, str(peaks[bucket])]) and ok
	# A bucket between clicks should be silent.
	ok = TestRunner._assert(is_equal_approx(peaks[5], 0.0), "audio_import_waveform_peaks_match_clicks: bucket 5 expected silence, got %s" % str(peaks[5])) and ok
	if ok:
		print("[PASS] audio_import_waveform_peaks_match_clicks")
	return ok


func test_decode_full_pcm_and_sample_rate() -> bool:
	var stream := Metronome.build(120.0, 1, 4, 44100) # 2s @ 44100Hz.
	var samples := AudioImport.decode_full_pcm(stream)
	var ok := TestRunner._assert(not samples.is_empty(), "audio_import_decode_full_pcm_and_sample_rate: expected non-empty decoded samples")

	var rate := AudioImport.effective_sample_rate(samples, stream.get_length())
	ok = TestRunner._assert(absf(rate - 44100.0) < 50.0, "audio_import_decode_full_pcm_and_sample_rate: expected ~44100Hz, got %s" % str(rate)) and ok
	if ok:
		print("[PASS] audio_import_decode_full_pcm_and_sample_rate")
	return ok
