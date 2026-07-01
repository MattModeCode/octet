extends RefCounted
class_name TestDspFft
## Correctness check for editor/dsp_fft.gd, verified in isolation before
## editor/audio_analysis.gd's onset/tempo pipeline is built on top of it --
## a pure sine wave at a known bin frequency must produce a magnitude
## spectrum that peaks at that exact bin.


func get_tests() -> Array[Dictionary]:
	return [
		{"name": "dsp_fft_sine_peaks_at_expected_bin", "callable": test_sine_peaks_at_expected_bin},
		{"name": "dsp_fft_dc_signal_peaks_at_bin_zero", "callable": test_dc_signal_peaks_at_bin_zero},
		{"name": "dsp_fft_hann_window_endpoints_near_zero", "callable": test_hann_window_endpoints_near_zero},
	]


func test_sine_peaks_at_expected_bin() -> bool:
	var n := 1024
	var bin := 20 # an arbitrary bin well within [1, n/2).
	var re := PackedFloat32Array()
	var im := PackedFloat32Array()
	re.resize(n)
	im.resize(n)
	for i in n:
		re[i] = sin(TAU * bin * i / n)
		im[i] = 0.0

	DspFft.fft(re, im)
	var mags := DspFft.magnitude_spectrum(re, im)

	var peak_bin := 0
	var peak_mag := 0.0
	for i in range(n / 2):
		if mags[i] > peak_mag:
			peak_mag = mags[i]
			peak_bin = i

	var ok := TestRunner._assert(peak_bin == bin, "dsp_fft_sine_peaks_at_expected_bin: expected peak at bin %d, got %d" % [bin, peak_bin])
	if ok:
		print("[PASS] dsp_fft_sine_peaks_at_expected_bin")
	return ok


func test_dc_signal_peaks_at_bin_zero() -> bool:
	var n := 256
	var re := PackedFloat32Array()
	var im := PackedFloat32Array()
	re.resize(n)
	im.resize(n)
	for i in n:
		re[i] = 1.0 # constant (DC) signal.

	DspFft.fft(re, im)
	var mags := DspFft.magnitude_spectrum(re, im)

	var ok := TestRunner._assert(mags[0] > mags[1] * 10.0, "dsp_fft_dc_signal_peaks_at_bin_zero: expected bin 0 to dominate, got mags[0]=%s mags[1]=%s" % [str(mags[0]), str(mags[1])])
	if ok:
		print("[PASS] dsp_fft_dc_signal_peaks_at_bin_zero")
	return ok


func test_hann_window_endpoints_near_zero() -> bool:
	var window := DspFft.hann_window(1024)
	var ok := TestRunner._assert(window.size() == 1024, "dsp_fft_hann_window_endpoints_near_zero: expected size 1024, got %d" % window.size())
	ok = TestRunner._assert(window[0] < 0.001, "dsp_fft_hann_window_endpoints_near_zero: expected window[0] near 0, got %s" % str(window[0])) and ok
	ok = TestRunner._assert(window[512] > 0.99, "dsp_fft_hann_window_endpoints_near_zero: expected window center near 1, got %s" % str(window[512])) and ok
	if ok:
		print("[PASS] dsp_fft_hann_window_endpoints_near_zero")
	return ok
