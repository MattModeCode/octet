extends RefCounted
class_name TestAudioAnalysis
## Tests for editor/audio_analysis.gd's onset/tempo/offset pipeline
## (PROJECT_BRIEF §3.2), built on the already-verified editor/dsp_fft.gd.
##
## This is a synthetic-click sanity check (a Metronome fixture of known
## BPM), not a claim about real-song detection accuracy -- §3.2 itself
## sets that expectation ("auto-detection typically gets ~90% of songs
## close on the first pass... always provide fast manual correction").
## The second test is a genuine timed benchmark answering the open
## question from the Stage 4 handoff: is pure-GDScript FFT/spectral-flux
## performance "tolerable" on a multi-minute song (§3.2's stated MVP-
## fallback bar)?


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "audio_analysis_detects_known_bpm", "callable": test_detects_known_bpm},
		{"name": "audio_analysis_performance_benchmark", "callable": test_performance_benchmark},
	]


func test_detects_known_bpm() -> bool:
	var bpm := 128.0
	var stream := Metronome.build(bpm, 16, 4) # 16 bars @ 128 BPM ~= 15s, clicks on every beat.
	var samples := AudioImport.decode_full_pcm(stream)
	var sample_rate := AudioImport.effective_sample_rate(samples, stream.get_length())

	var result := AudioAnalysis.analyze(samples, sample_rate)

	var ok := TestRunner._assert(absf(result.bpm - bpm) < 3.0,
		"audio_analysis_detects_known_bpm: expected ~%.1f BPM, got %s" % [bpm, str(result.bpm)])
	ok = TestRunner._assert(result.offset_ms < (60000.0 / bpm) * 0.25,
		"audio_analysis_detects_known_bpm: expected offset near 0 (clicks start at t=0), got %s ms" % str(result.offset_ms)) and ok
	ok = TestRunner._assert(result.onsets.size() >= 30,
		"audio_analysis_detects_known_bpm: expected onsets roughly matching the ~64 clicks, got %d" % result.onsets.size()) and ok
	if ok:
		print("[PASS] audio_analysis_detects_known_bpm (bpm=%.2f offset=%.1fms onsets=%d)" % [result.bpm, result.offset_ms, result.onsets.size()])
	return ok


## Benchmarks analyze() against a 30-second synthetic click track and
## extrapolates linearly to a 4-minute (240s) song -- the pipeline's cost
## (windowed FFT + flux per frame, autocorrelation over a fixed lag range)
## scales linearly with sample count, so this extrapolation is sound. Kept
## to 30s (not a full 4 minutes) so the test suite itself stays fast to
## iterate on; this is a regression-guard ceiling, not a tight perf target.
func test_performance_benchmark() -> bool:
	var stream := Metronome.build(120.0, 15, 4) # 15 bars @ 120 BPM = 30s.
	var samples := AudioImport.decode_full_pcm(stream)
	var sample_rate := AudioImport.effective_sample_rate(samples, stream.get_length())

	var start_ms := Time.get_ticks_msec()
	var result := AudioAnalysis.analyze(samples, sample_rate)
	var elapsed_ms := Time.get_ticks_msec() - start_ms

	var extrapolated_4min_sec := (elapsed_ms / 1000.0) * (240.0 / 30.0)
	print("audio_analysis_performance_benchmark: 30s clip analyzed in %dms (bpm=%.1f); extrapolated 4min estimate: %.1fs" % [elapsed_ms, result.bpm, extrapolated_4min_sec])

	# Generous regression-guard ceiling, not a tight target: a 30s clip
	# taking longer than this would indicate something is pathologically
	# slow (e.g. an accidental O(n^2)), not just "GDScript is slow."
	var ok := TestRunner._assert(elapsed_ms < 60000, "audio_analysis_performance_benchmark: 30s clip took %dms, expected under 60000ms" % elapsed_ms)
	if ok:
		print("[PASS] audio_analysis_performance_benchmark")
	return ok
