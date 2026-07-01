class_name DspFft
extends RefCounted
## From-scratch radix-2 iterative Cooley-Tukey FFT (PROJECT_BRIEF §3.2:
## "FFT each frame"). Godot exposes no FFT to GDScript --
## AudioEffectSpectrumAnalyzer is a real-time audio-bus effect, not usable
## for offline whole-buffer analysis on an arbitrary PCM array -- so this
## is hand-rolled. Correctness verified in isolation (tests/test_dsp_fft.gd:
## a pure sine at a known bin frequency must peak at that bin) before
## editor/audio_analysis.gd trusts it, the same discipline Stage 4 used
## for AudioStreamPlayback.mix_audio().
##
## Complex numbers are represented as parallel real/imaginary
## PackedFloat32Arrays rather than a Complex type (GDScript has none) --
## fft() operates in place on both.

## In-place FFT (forward). [param re]/[param im] must be the same
## power-of-2 length; [param im] should be all zeros for a real input
## signal. Standard iterative decimation-in-time algorithm: bit-reversal
## permutation, then log2(n) butterfly stages with incrementally rotated
## twiddle factors (avoids a sin/cos call per butterfly -- only once per
## stage).
static func fft(re: PackedFloat32Array, im: PackedFloat32Array) -> void:
	var n := re.size()
	if n <= 1:
		return

	# Bit-reversal permutation.
	var j := 0
	for i in range(n - 1):
		if i < j:
			var tmp_re := re[i]
			re[i] = re[j]
			re[j] = tmp_re
			var tmp_im := im[i]
			im[i] = im[j]
			im[j] = tmp_im
		var m := n >> 1
		while m >= 1 and (j & m) != 0:
			j ^= m
			m >>= 1
		j |= m

	# Butterfly stages.
	var length := 2
	while length <= n:
		var half := length >> 1
		var theta := -TAU / length
		var w_re := cos(theta)
		var w_im := sin(theta)
		var i := 0
		while i < n:
			var cur_re := 1.0
			var cur_im := 0.0
			for k in half:
				var idx_top := i + k
				var idx_bot := idx_top + half
				var t_re := cur_re * re[idx_bot] - cur_im * im[idx_bot]
				var t_im := cur_re * im[idx_bot] + cur_im * re[idx_bot]
				re[idx_bot] = re[idx_top] - t_re
				im[idx_bot] = im[idx_top] - t_im
				re[idx_top] = re[idx_top] + t_re
				im[idx_top] = im[idx_top] + t_im
				var next_re := cur_re * w_re - cur_im * w_im
				var next_im := cur_re * w_im + cur_im * w_re
				cur_re = next_re
				cur_im = next_im
			i += length
		length <<= 1


## Magnitude spectrum (sqrt(re^2 + im^2)) for each bin. Callers typically
## only need bins [0, n/2] (the rest mirrors for a real input), but this
## returns the full array and lets callers slice as needed.
static func magnitude_spectrum(re: PackedFloat32Array, im: PackedFloat32Array) -> PackedFloat32Array:
	var mags := PackedFloat32Array()
	mags.resize(re.size())
	for i in re.size():
		mags[i] = sqrt(re[i] * re[i] + im[i] * im[i])
	return mags


## Cached per-size Hann window (0.5 - 0.5*cos(2*pi*i/(n-1))) -- built once
## per distinct size and reused, since editor/audio_analysis.gd calls this
## once per analysis frame (potentially tens of thousands of times for a
## multi-minute song) with the same window_size every time.
static var _cached_window: PackedFloat32Array = PackedFloat32Array()
static var _cached_window_size: int = -1


static func hann_window(n: int) -> PackedFloat32Array:
	if _cached_window_size != n:
		var window := PackedFloat32Array()
		window.resize(n)
		for i in n:
			window[i] = 0.5 - 0.5 * cos(TAU * i / (n - 1))
		_cached_window = window
		_cached_window_size = n
	return _cached_window
