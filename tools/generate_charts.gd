extends SceneTree
## Throwaway tooling script -- NOT part of the game or test suite. Generates
## 2 difficulty charts for each of 5 new songs under res://songs/<slug>/,
## reusing the real audio pipeline (editor/audio_import.gd's offline PCM
## decode + editor/audio_analysis.gd's onset/BPM/offset detection -- the
## same pipeline that produced songs/thats-why-i-gave-up-on-music/*.oct) so
## notes land on real detected onsets rather than a synthetic grid.
##
## On top of the onset-aligned base rhythm, each song gets a distinct
## "signature motif" (arpeggio sweep, long holds, held chords, mirror
## chords + spam, or wave trill + sinking spam) stamped at a few points
## through the track, scaled tamer/denser by difficulty tier. Difficulty
## density and motif intensity are controlled by the *_BY_TIER tables below.
##
## Run once, by hand, via:
##   <path-to-godot> --headless -s tools/generate_charts.gd --path .
## Safe to re-run (overwrites the 10 .oct files) or delete once the charts
## are committed -- it's not wired into any autoload or registered test.

const STAR_RATING_BY_TIER := {
	"very_easy": 1.0, "easy": 2.2, "normal": 3.4, "hard": 4.8, "very_hard": 6.2,
}
## Keep every Nth detected onset for the base (non-motif) rhythm -- higher
## stride = sparser = easier.
const STRIDE_BY_TIER := {
	"very_easy": 5, "easy": 3, "normal": 2, "hard": 1, "very_hard": 1,
}
## How many times the signature motif is stamped into the chart.
const MOTIF_COUNT_BY_TIER := {
	"very_easy": 1, "easy": 1, "normal": 2, "hard": 3, "very_hard": 4,
}
## Arpeggio sweep: subdivisions-per-beat (speed) and how many of the 8 lanes
## the sweep covers (a partial 4-lane sweep reads as a tamer echo of the
## full 8-lane cascade).
const ARPEGGIO_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 3.0, "normal": 4.0, "hard": 6.0, "very_hard": 8.0,
}
const ARPEGGIO_LANES_BY_TIER := {
	"very_easy": 4, "easy": 5, "normal": 6, "hard": 8, "very_hard": 8,
}
## Long-hold motif: hold length in beats.
const HOLD_BEATS_BY_TIER := {
	"very_easy": 1.5, "easy": 2.0, "normal": 3.0, "hard": 4.0, "very_hard": 6.0,
}
## Held-chord motif: simultaneous lanes held, and hold length in beats.
const CHORD_SIZE_BY_TIER := {
	"very_easy": 2, "easy": 2, "normal": 3, "hard": 3, "very_hard": 4,
}
const CHORD_HOLD_BEATS_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 3.0, "very_hard": 4.0,
}
## Mirror-chord + spam motif: spam-burst note count (16th-note pace).
const SPAM_COUNT_BY_TIER := {
	"very_easy": 3, "easy": 4, "normal": 6, "hard": 8, "very_hard": 12,
}
## Wave-trill motif: zigzag cycle count (also reused as the sinking-spam
## step count).
const TRILL_CYCLES_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 5, "very_hard": 6,
}

const SONGS: Array[Dictionary] = [
	{
		"slug": "unravel-tokyo-ghoul",
		"title": "Unravel",
		"artist": "TK from Ling tosite sigure",
		"audio_filename": "Unravel.mp3",
		"motif": "arpeggio_sweep",
		"difficulties": [
			{"tier": "normal", "name": "Normal", "file": "normal"},
			{"tier": "very_hard", "name": "Very Hard", "file": "very_hard"},
		],
	},
	{
		"slug": "one-voice",
		"title": "One Voice",
		"artist": "Rokudenashi",
		"audio_filename": "OneVoice.mp3",
		"motif": "long_holds",
		"difficulties": [
			{"tier": "easy", "name": "Easy", "file": "easy"},
			{"tier": "hard", "name": "Hard", "file": "hard"},
		],
	},
	{
		"slug": "a-thousand-years",
		"title": "A Thousand Years",
		"artist": "John Michael Howell, JVKE & ZVC",
		"audio_filename": "AThousandYears.mp3",
		"motif": "held_chords",
		"difficulties": [
			{"tier": "very_easy", "name": "Very Easy", "file": "very_easy"},
			{"tier": "normal", "name": "Normal", "file": "normal"},
		],
	},
	{
		"slug": "story-of-a-warrior",
		"title": "Story Of A Warrior",
		"artist": "John Michael Howell",
		"audio_filename": "StoryOfAWarrior.mp3",
		"motif": "mirror_spam",
		"difficulties": [
			{"tier": "normal", "name": "Normal", "file": "normal"},
			{"tier": "hard", "name": "Hard", "file": "hard"},
		],
	},
	{
		"slug": "drowning-love",
		"title": "Chasing Kou",
		"artist": "Shuichi Sakamoto",
		"audio_filename": "ChasingKou.mp3",
		"motif": "wave_trill",
		"difficulties": [
			{"tier": "easy", "name": "Easy", "file": "easy"},
			{"tier": "very_hard", "name": "Very Hard", "file": "very_hard"},
		],
	},
]


func _initialize() -> void:
	for song: Dictionary in SONGS:
		var audio_path: String = "res://songs/%s/%s" % [song.slug, song.audio_filename]
		var stream: AudioStream = AudioImport.load_audio_file(audio_path)
		if stream == null:
			printerr("generate_charts: failed to load audio for %s at %s" % [song.slug, audio_path])
			continue

		var samples: PackedFloat32Array = AudioImport.decode_full_pcm(stream)
		var sample_rate: float = AudioImport.effective_sample_rate(samples, stream.get_length())
		var analysis: Dictionary = AudioAnalysis.analyze(samples, sample_rate)
		var duration_ms: float = stream.get_length() * 1000.0

		var bpm: float = analysis.bpm if analysis.bpm > 0.0 else 120.0
		var beat_ms: float = 60000.0 / bpm
		var onsets: Array = analysis.onsets
		if onsets.is_empty():
			onsets = _synthetic_grid(beat_ms, duration_ms)

		print("generate_charts: %s -> bpm=%.2f offset=%.1fms onsets=%d duration=%.0fms" % [
			song.slug, bpm, analysis.offset_ms, onsets.size(), duration_ms])

		for diff: Dictionary in song.difficulties:
			var chart: Chart = _build_chart(song, diff, bpm, analysis.offset_ms, onsets, duration_ms)
			var out_path: String = "res://songs/%s/%s.oct" % [song.slug, diff.file]
			var err: Error = OctIO.save_oct(chart, out_path)
			if err != OK:
				printerr("generate_charts: failed to save %s (error %d)" % [out_path, err])
			else:
				print("generate_charts: wrote %s (%d notes)" % [out_path, chart.notes.size()])

	quit(0)


## Fallback note-time source for a song whose onset detection came back
## empty (e.g. a very quiet intro) -- a plain beat grid so generation never
## produces an empty chart.
func _synthetic_grid(beat_ms: float, duration_ms: float) -> Array:
	var grid: Array = []
	var t: float = 500.0
	while t < duration_ms - 500.0:
		grid.append(t)
		t += beat_ms
	return grid


func _build_chart(song: Dictionary, diff: Dictionary, bpm: float, offset_ms: float, onsets: Array, duration_ms: float) -> Chart:
	var tier: String = diff.tier
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s::%s" % [song.slug, tier])
	var beat_ms: float = 60000.0 / bpm

	var stride: int = STRIDE_BY_TIER.get(tier, 2)
	var thinned: Array = _thin_onsets(onsets, stride)
	var notes: Array[ChartNote] = _assign_base_lanes(rng, thinned)

	var motif_count: int = MOTIF_COUNT_BY_TIER.get(tier, 2)
	var anchors: Array = _pick_motif_anchors(onsets, duration_ms, motif_count, beat_ms * 4.0)

	var preview_time_ms: int = int(round(duration_ms * 0.3))
	var occurrence_index: int = 0
	for anchor: float in anchors:
		var result: Dictionary = _apply_motif(song.motif, tier, rng, anchor, beat_ms, occurrence_index)
		var motif_notes: Array = result.notes
		var span: float = result.span_ms
		notes = _strip_notes_in_window(notes, anchor - 10.0, anchor + span + 10.0)
		notes.append_array(motif_notes)
		if occurrence_index == 0 and not motif_notes.is_empty():
			preview_time_ms = int(round(anchor))
		occurrence_index += 1

	notes.sort_custom(func(a: ChartNote, b: ChartNote) -> bool:
		if a.time_ms != b.time_ms:
			return a.time_ms < b.time_ms
		return a.lane < b.lane
	)

	var chart := Chart.new()
	chart.format_version = 1
	chart.metadata = ChartMetadata.new()
	chart.metadata.title = song.title
	chart.metadata.artist = song.artist
	chart.metadata.mapper = "Octet Team"
	chart.metadata.difficulty_name = diff.name
	chart.metadata.star_rating = STAR_RATING_BY_TIER.get(tier, 3.0)
	chart.metadata.tags = PackedStringArray(["auto-generated", "signature:%s" % song.motif])
	chart.metadata.preview_time_ms = preview_time_ms

	chart.audio = ChartAudio.new()
	chart.audio.filename = song.audio_filename
	chart.audio.duration_ms = int(round(duration_ms))

	var tp := TimingPoint.new()
	tp.time_ms = int(round(offset_ms))
	tp.bpm = bpm
	tp.meter = 3 if song.motif == "held_chords" else 4
	chart.timing_points = [tp]

	chart.notes = notes
	return chart


## -- base rhythm -------------------------------------------------------

func _thin_onsets(onsets: Array, stride: int) -> Array:
	var thinned: Array = []
	for i in onsets.size():
		if i % stride == 0:
			thinned.append(onsets[i])
	return thinned


## Assigns a lane to each base-rhythm time, avoiding an immediate repeat of
## the previous lane so plain taps read as movement across the keyboard
## rather than a single-lane drone (that's reserved for the spam motifs).
func _assign_base_lanes(rng: RandomNumberGenerator, times: Array) -> Array[ChartNote]:
	var notes: Array[ChartNote] = []
	var last_lane: int = -1
	for t: float in times:
		var lane: int = rng.randi_range(0, 7)
		var attempts: int = 0
		while lane == last_lane and attempts < 5:
			lane = rng.randi_range(0, 7)
			attempts += 1
		var note := ChartNote.new()
		note.lane = lane
		note.time_ms = int(round(t))
		note.type = "tap"
		notes.append(note)
		last_lane = lane
	return notes


func _strip_notes_in_window(notes: Array[ChartNote], start_ms: float, end_ms: float) -> Array[ChartNote]:
	var kept: Array[ChartNote] = []
	for note: ChartNote in notes:
		if note.time_ms < start_ms or note.time_ms > end_ms:
			kept.append(note)
	return kept


func _pick_distinct_lanes(rng: RandomNumberGenerator, count: int) -> Array:
	var lanes: Array = range(8)
	for i in range(lanes.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = lanes[i]
		lanes[i] = lanes[j]
		lanes[j] = tmp
	return lanes.slice(0, count)


## Picks [param count] onset times spread through the middle 70% of the
## track (skipping the intro/outro), snapped to the nearest real onset so
## motifs land on an actual audio hit, with a minimum gap so two motif
## occurrences never overlap.
func _pick_motif_anchors(onsets: Array, duration_ms: float, count: int, min_gap_ms: float) -> Array:
	var anchors: Array = []
	if onsets.is_empty() or count <= 0:
		return anchors

	var start_frac: float = 0.15
	var end_frac: float = 0.85
	var span: float = (end_frac - start_frac) * duration_ms

	for i in count:
		var target: float = start_frac * duration_ms + (span * (i + 0.5) / count)
		var nearest: float = onsets[0]
		var best_diff: float = absf(onsets[0] - target)
		for onset: float in onsets:
			var diff: float = absf(onset - target)
			if diff < best_diff:
				best_diff = diff
				nearest = onset
		if anchors.is_empty() or (nearest - anchors[-1]) >= min_gap_ms:
			anchors.append(nearest)
	return anchors


## -- signature motifs ----------------------------------------------------

func _apply_motif(motif_name: String, tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	match motif_name:
		"arpeggio_sweep":
			return _motif_arpeggio_sweep(tier, anchor_ms, beat_ms, occurrence_index)
		"long_holds":
			return _motif_long_holds(rng, tier, anchor_ms, beat_ms)
		"held_chords":
			return _motif_held_chords(rng, tier, anchor_ms, beat_ms)
		"mirror_spam":
			return _motif_mirror_spam(rng, tier, anchor_ms, beat_ms)
		"wave_trill":
			return _motif_wave_trill(tier, anchor_ms, beat_ms, occurrence_index)
		_:
			return {"notes": [] as Array[ChartNote], "span_ms": 0.0}


## Unravel: a rapid full-lane (or partial, on lower tiers) cascade sweep
## across the 8 lanes -- direction alternates 0->7 / 7->0 between
## occurrences so it doesn't always crawl the same way.
func _motif_arpeggio_sweep(tier: String, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	var subdivisions: float = ARPEGGIO_SUBDIV_BY_TIER.get(tier, 4.0)
	var step_ms: float = beat_ms / subdivisions
	var lane_count: int = ARPEGGIO_LANES_BY_TIER.get(tier, 6)

	var all_lanes: Array = range(8)
	if occurrence_index % 2 == 1:
		all_lanes.reverse()
	var lanes: Array = all_lanes.slice(0, lane_count)

	var notes: Array[ChartNote] = []
	for i in lanes.size():
		var n := ChartNote.new()
		n.lane = lanes[i]
		n.time_ms = int(round(anchor_ms + i * step_ms))
		n.type = "tap"
		notes.append(n)
	return {"notes": notes, "span_ms": step_ms * (lanes.size() - 1)}


## One Voice: a single long-sustained hold, echoing a held vocal tail.
func _motif_long_holds(rng: RandomNumberGenerator, tier: String, anchor_ms: float, beat_ms: float) -> Dictionary:
	var hold_beats: float = HOLD_BEATS_BY_TIER.get(tier, 2.0)
	var n := ChartNote.new()
	n.lane = rng.randi_range(0, 7)
	n.time_ms = int(round(anchor_ms))
	n.type = "hold"
	n.end_time_ms = int(round(anchor_ms + hold_beats * beat_ms))
	return {"notes": [n] as Array[ChartNote], "span_ms": hold_beats * beat_ms}


## A Thousand Years: several lanes held simultaneously, like a sustained
## piano chord under the waltz-feel 3/4 meter this song's timing point uses.
func _motif_held_chords(rng: RandomNumberGenerator, tier: String, anchor_ms: float, beat_ms: float) -> Dictionary:
	var size: int = CHORD_SIZE_BY_TIER.get(tier, 3)
	var hold_beats: float = CHORD_HOLD_BEATS_BY_TIER.get(tier, 3.0)
	var lanes: Array = _pick_distinct_lanes(rng, size)

	var notes: Array[ChartNote] = []
	for lane: int in lanes:
		var n := ChartNote.new()
		n.lane = lane
		n.time_ms = int(round(anchor_ms))
		n.type = "hold"
		n.end_time_ms = int(round(anchor_ms + hold_beats * beat_ms))
		notes.append(n)
	return {"notes": notes, "span_ms": hold_beats * beat_ms}


## Story Of A Warrior: two symmetric mirror chords (lanes i and 7-i struck
## together) one beat apart, followed by a single-lane drum-roll spam burst.
func _motif_mirror_spam(rng: RandomNumberGenerator, tier: String, anchor_ms: float, beat_ms: float) -> Dictionary:
	var notes: Array[ChartNote] = []
	var t: float = anchor_ms

	for _k in 2:
		var i: int = rng.randi_range(0, 3)
		for lane in [i, 7 - i]:
			var n := ChartNote.new()
			n.lane = lane
			n.time_ms = int(round(t))
			n.type = "tap"
			notes.append(n)
		t += beat_ms

	var spam_lane: int = rng.randi_range(0, 7)
	var count: int = SPAM_COUNT_BY_TIER.get(tier, 6)
	var step_ms: float = beat_ms / 4.0
	for i in count:
		var n := ChartNote.new()
		n.lane = spam_lane
		n.time_ms = int(round(t + i * step_ms))
		n.type = "tap"
		notes.append(n)

	return {"notes": notes, "span_ms": (t + count * step_ms) - anchor_ms}


## Drowning Love: alternates a zigzag cross-lane trill (pairs stepping
## outward from the center, like a wave) with a "sinking" single-lane spam
## that descends lane-by-lane with widening gaps, trailing off.
func _motif_wave_trill(tier: String, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	var step_ms: float = beat_ms / 4.0
	var notes: Array[ChartNote] = []
	var t: float = anchor_ms

	if occurrence_index % 2 == 0:
		var pairs: Array = [[3, 4], [2, 5], [1, 6], [0, 7]]
		var cycles: int = TRILL_CYCLES_BY_TIER.get(tier, 4)
		for c in cycles:
			var pair: Array = pairs[c % pairs.size()]
			for lane in pair:
				var n := ChartNote.new()
				n.lane = lane
				n.time_ms = int(round(t))
				n.type = "tap"
				notes.append(n)
				t += step_ms
	else:
		var gap: float = step_ms
		for lane in range(7, -1, -1):
			var n := ChartNote.new()
			n.lane = lane
			n.time_ms = int(round(t))
			n.type = "tap"
			notes.append(n)
			t += gap
			gap *= 1.2

	return {"notes": notes, "span_ms": t - anchor_ms}
