class_name AudioAnalysis
extends RefCounted
## Automatic analysis (PROJECT_BRIEF §3.2): onset detection, tempo (BPM)
## estimation, beat-phase/offset, exposed via the brief's fixed interface
## `analyze(pcm) -> { bpm, offset_ms, onsets[] }`. Pure GDScript -- no Rust
## toolchain is available in this environment (verified: rustc/cargo not
## found), which settles §3.2's "decide Rust GDExtension vs GDScript
## fallback" in favour of the GDScript path the brief explicitly allows.
## Built on editor/dsp_fft.gd (verified correct in isolation first) and
## editor/audio_import.gd's real offline PCM decode.
##
## Results are meant to be applied as EDITABLE starting values (§3.2:
## "expose the results... as editable values") -- editor_main.gd writes
## them into the normal BPM/offset SpinBoxes, not a locked read-only field.

const WINDOW_SIZE: int = 1024
const HOP_SIZE: int = 512
const MIN_BPM: float = 60.0
const MAX_BPM: float = 220.0
const PREFERRED_BPM_MIN: float = 90.0
const PREFERRED_BPM_MAX: float = 180.0
const OFFSET_HISTOGRAM_BUCKETS: int = 32
## Minimum spacing (ms) enforced between two accepted onset peaks -- keeps
## a single transient's energy spread across a couple of frames from
## registering as multiple onsets.
const ONSET_MIN_GAP_MS: float = 60.0
## Peak-picking threshold: mean + PEAK_THRESHOLD_K * stddev of the onset
## envelope.
const PEAK_THRESHOLD_K: float = 1.2


## Runs the full pipeline over [param pcm] (mono signed samples,
## editor/audio_import.gd's decode_full_pcm output) at [param sample_rate].
## Returns {"bpm": float, "offset_ms": float, "onsets": Array[float]}
## (onset times in ms). Returns a zeroed/empty result rather than
## crashing if [param pcm] is too short to analyze.
static func analyze(pcm: PackedFloat32Array, sample_rate: float) -> Dictionary:
	if pcm.size() < WINDOW_SIZE or sample_rate <= 0.0:
		return {"bpm": 0.0, "offset_ms": 0.0, "onsets": []}

	var hop_ms := (HOP_SIZE / sample_rate) * 1000.0
	var envelope := _spectral_flux_envelope(pcm)
	var onsets := _pick_onsets(envelope, hop_ms)

	var bpm := _estimate_bpm(envelope, hop_ms)
	var offset_ms := _estimate_offset(onsets, bpm)

	var onset_times: Array[float] = []
	for onset in onsets:
		onset_times.append(onset.time_ms)

	return {"bpm": bpm, "offset_ms": offset_ms, "onsets": onset_times}


## Frames [param pcm] into WINDOW_SIZE windows at 50% overlap (HOP_SIZE),
## Hann-windows each, FFTs it, and returns the spectral-flux onset
## envelope: envelope[i] = sum of positive magnitude differences between
## frame i and frame i-1 across all bins (half-wave rectified, per §3.2).
static func _spectral_flux_envelope(pcm: PackedFloat32Array) -> PackedFloat32Array:
	var window := DspFft.hann_window(WINDOW_SIZE)
	var half_bins := WINDOW_SIZE / 2

	var frame_count := int(floor(float(pcm.size() - WINDOW_SIZE) / HOP_SIZE)) + 1
	var envelope := PackedFloat32Array()
	envelope.resize(maxi(0, frame_count))

	var prev_mags := PackedFloat32Array()
	prev_mags.resize(half_bins)

	for frame in frame_count:
		var start := frame * HOP_SIZE
		var re := PackedFloat32Array()
		var im := PackedFloat32Array()
		re.resize(WINDOW_SIZE)
		im.resize(WINDOW_SIZE)
		for i in WINDOW_SIZE:
			re[i] = pcm[start + i] * window[i]

		DspFft.fft(re, im)
		var mags := DspFft.magnitude_spectrum(re, im)

		var flux := 0.0
		for bin in half_bins:
			var diff := mags[bin] - prev_mags[bin]
			if diff > 0.0:
				flux += diff
		envelope[frame] = flux
		prev_mags = mags.slice(0, half_bins)

	return envelope


## Adaptive-threshold peak-picking over the onset envelope: a frame is an
## accepted onset if it's a local maximum, exceeds mean + k*stddev, and is
## at least ONSET_MIN_GAP_MS past the last accepted onset (keeping
## whichever of two close peaks is stronger). Returns an array of
## {"time_ms": float, "strength": float}.
static func _pick_onsets(envelope: PackedFloat32Array, hop_ms: float) -> Array[Dictionary]:
	var onsets: Array[Dictionary] = []
	if envelope.size() < 3:
		return onsets

	var mean := 0.0
	for value in envelope:
		mean += value
	mean /= envelope.size()

	var variance := 0.0
	for value in envelope:
		variance += (value - mean) * (value - mean)
	variance /= envelope.size()
	var threshold := mean + PEAK_THRESHOLD_K * sqrt(variance)

	for i in range(1, envelope.size() - 1):
		var value := envelope[i]
		if value < threshold:
			continue
		if value < envelope[i - 1] or value < envelope[i + 1]:
			continue

		var time_ms := i * hop_ms
		if not onsets.is_empty() and time_ms - onsets[-1].time_ms < ONSET_MIN_GAP_MS:
			if value > onsets[-1].strength:
				onsets[-1] = {"time_ms": time_ms, "strength": value}
			continue

		onsets.append({"time_ms": time_ms, "strength": value})

	return onsets


## Autocorrelation-based tempo estimate (§3.2 step 2): scans lags
## corresponding to MIN_BPM..MAX_BPM, picks the strongest periodicity, then
## folds octave errors (half/double lag) toward the PREFERRED_BPM range
## when a harmonic/subharmonic scores comparably to the raw best.
static func _estimate_bpm(envelope: PackedFloat32Array, hop_ms: float) -> float:
	if envelope.size() < 4 or hop_ms <= 0.0:
		return 0.0

	var min_lag := maxi(1, int(floor((60000.0 / MAX_BPM) / hop_ms)))
	var max_lag := mini(envelope.size() - 1, int(ceil((60000.0 / MIN_BPM) / hop_ms)))
	if min_lag >= max_lag:
		return 0.0

	var scores := {}
	var best_lag := min_lag
	var best_score := -1.0
	for lag in range(min_lag, max_lag + 1):
		var score := _autocorrelation_at_lag(envelope, lag)
		scores[lag] = score
		if score > best_score:
			best_score = score
			best_lag = lag

	var chosen_lag := _resolve_octave_error(scores, best_lag, best_score, hop_ms)
	return 60000.0 / (chosen_lag * hop_ms)


## Deliberately NOT normalized by the overlap count (envelope.size() - lag):
## that count shrinks as lag grows, which computes a *mean* rather than the
## standard autocorrelation *sum* and systematically inflates the score at
## larger lags -- caught empirically (tests/test_audio_analysis.gd first
## failed with a clean half-tempo octave error, 63.8 BPM instead of 128,
## on a fixture whose onsets were themselves detected at the correct
## spacing) before this fix. The raw sum is the textbook definition and
## removes the bias entirely.
static func _autocorrelation_at_lag(envelope: PackedFloat32Array, lag: int) -> float:
	var sum := 0.0
	var count := envelope.size() - lag
	for i in count:
		sum += envelope[i] * envelope[i + lag]
	return sum


## If halving or doubling the best lag scores at least
## OCTAVE_FOLD_RATIO as well as the raw best AND lands its implied BPM
## inside the preferred band (while the raw best doesn't), prefer the
## folded candidate. This resolves the classic half/double-tempo ambiguity
## (§3.2 step 2) without discarding a genuinely strong raw best.
const OCTAVE_FOLD_RATIO: float = 0.7


static func _resolve_octave_error(scores: Dictionary, best_lag: int, best_score: float, hop_ms: float) -> int:
	var best_bpm := 60000.0 / (best_lag * hop_ms)
	if best_bpm >= PREFERRED_BPM_MIN and best_bpm <= PREFERRED_BPM_MAX:
		return best_lag

	# Both floor AND ceil of best_lag/2 are checked, not a single rounded
	# value -- when best_lag is odd (e.g. 81), half-lag rounding is
	# ambiguous between two adjacent integer lags, and they can score very
	# differently. Caught empirically: a fixture whose raw best_lag (81,
	# ~64 BPM) was really double the true period folded correctly to 40
	# (~129 BPM, scored well above threshold) but NOT to 41 (~126 BPM,
	# scored below threshold) -- checking only round(81/2.0) = 41 missed
	# the one that actually worked. Picks the best-scoring valid candidate
	# among all three, not just the first that passes.
	var candidates: Array[int] = [
		best_lag * 2,
		int(floor(best_lag / 2.0)),
		int(ceil(best_lag / 2.0)),
	]
	var chosen_lag := best_lag
	var chosen_score := -1.0
	for candidate_lag in candidates:
		if candidate_lag == best_lag or not scores.has(candidate_lag):
			continue
		var candidate_score: float = scores[candidate_lag]
		if candidate_score < best_score * OCTAVE_FOLD_RATIO:
			continue
		var candidate_bpm := 60000.0 / (candidate_lag * hop_ms)
		if candidate_bpm < PREFERRED_BPM_MIN or candidate_bpm > PREFERRED_BPM_MAX:
			continue
		if candidate_score > chosen_score:
			chosen_score = candidate_score
			chosen_lag = candidate_lag

	return chosen_lag


## Beat-phase/offset estimate (§3.2 step 3): histograms
## (onset_time mod beat_interval), weighted by onset strength, across
## OFFSET_HISTOGRAM_BUCKETS buckets; the best bucket's center is the
## estimated first-beat offset.
static func _estimate_offset(onsets: Array[Dictionary], bpm: float) -> float:
	if onsets.is_empty() or bpm <= 0.0:
		return 0.0

	var beat_interval_ms := 60000.0 / bpm
	var bucket_width := beat_interval_ms / OFFSET_HISTOGRAM_BUCKETS
	var buckets := PackedFloat32Array()
	buckets.resize(OFFSET_HISTOGRAM_BUCKETS)

	for onset in onsets:
		var phase = fmod(onset.time_ms, beat_interval_ms)
		var bucket := clampi(int(phase / bucket_width), 0, OFFSET_HISTOGRAM_BUCKETS - 1)
		buckets[bucket] += onset.strength

	var best_bucket := 0
	var best_weight := buckets[0]
	for i in range(1, OFFSET_HISTOGRAM_BUCKETS):
		if buckets[i] > best_weight:
			best_weight = buckets[i]
			best_bucket = i

	return (best_bucket + 0.5) * bucket_width
