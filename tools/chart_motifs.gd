## Signature-motif builders for the 15 anime-OP songs added alongside the
## original five motifs that live inline in tools/generate_charts.gd. Same
## contract as those: each builder returns {"notes": Array[ChartNote],
## "span_ms": float} anchored at anchor_ms, scaled tamer/denser by the
## *_BY_TIER tables. Dispatched via build() from generate_charts.gd's
## _apply_motif(). Throwaway tooling -- not part of the game or tests.

## spotlight_switch (Idol): hits per two-lane trill before it "teleports".
const SPOTLIGHT_HITS_BY_TIER := {
	"very_easy": 3, "easy": 4, "normal": 6, "hard": 8, "very_hard": 10,
}
const SPOTLIGHT_PAIRS_BY_TIER := {
	"very_easy": 1, "easy": 2, "normal": 2, "hard": 3, "very_hard": 4,
}
const SPOTLIGHT_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 4.0, "very_hard": 4.0,
}
## skip_gallop (Yuusha): dotted-8th+16th gallop unit count.
const GALLOP_UNITS_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 6, "very_hard": 8,
}
## prowl_pounce (Kaibutsu): stalk notes, pounce chord width, claw-sweep length.
const PROWL_STEPS_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 4, "very_hard": 6,
}
const POUNCE_CHORD_BY_TIER := {
	"very_easy": 2, "easy": 2, "normal": 3, "hard": 4, "very_hard": 5,
}
const CLAW_SWEEP_BY_TIER := {
	"very_easy": 0, "easy": 0, "normal": 4, "hard": 6, "very_hard": 8,
}
## jackhammer_chaos (KICK BACK): same-lane jack pairs that slide sideways.
const JACK_UNITS_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 6, "very_hard": 8,
}
const JACK_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 4.0, "very_hard": 4.0,
}
## rising_salute (Peace Sign): ascending 3-lane stair triplets.
const SALUTE_UNITS_BY_TIER := {
	"very_easy": 1, "easy": 2, "normal": 2, "hard": 3, "very_hard": 4,
}
const SALUTE_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 3.0, "very_hard": 4.0,
}
## dual_stairs (Crossing Field): mirrored two-hand staircase steps.
const STAIR_STEPS_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 4, "very_hard": 4,
}
const STAIR_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 2.0, "hard": 3.0, "very_hard": 4.0,
}
## ballad_swells (Unlasting): crescendo hold length and resolving chord size.
const SWELL_HOLD_BEATS_BY_TIER := {
	"very_easy": 2.0, "easy": 3.0, "normal": 4.0, "hard": 5.0, "very_hard": 6.0,
}
const SWELL_CHORD_BY_TIER := {
	"very_easy": 1, "easy": 2, "normal": 2, "hard": 3, "very_hard": 3,
}
## hold_lattice (Zankyosanka): overlapping staggered holds + woven taps.
const LATTICE_HOLDS_BY_TIER := {
	"very_easy": 1, "easy": 2, "normal": 2, "hard": 3, "very_hard": 4,
}
const LATTICE_HOLD_BEATS_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 3.0, "very_hard": 4.0,
}
const LATTICE_TAPS_BY_TIER := {
	"very_easy": 0, "easy": 0, "normal": 2, "hard": 3, "very_hard": 4,
}
## offbeat_accent (SPECIALZ): chord stabs on the "and" of the beat.
const OFFBEAT_STABS_BY_TIER := {
	"very_easy": 1, "easy": 2, "normal": 3, "hard": 4, "very_hard": 6,
}
const OFFBEAT_CHORD_BY_TIER := {
	"very_easy": 1, "easy": 1, "normal": 2, "hard": 2, "very_hard": 2,
}
## flick_trill (Kaikai Kitan): tiny 3-note zigzag flick repeats.
const FLICK_REPEATS_BY_TIER := {
	"very_easy": 1, "easy": 1, "normal": 2, "hard": 3, "very_hard": 4,
}
const FLICK_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 4.0, "very_hard": 4.0,
}
## flame_burst (Inferno): eruption chord size and ember-run length.
const FLAME_CHORD_BY_TIER := {
	"very_easy": 2, "easy": 2, "normal": 3, "hard": 3, "very_hard": 4,
}
const FLAME_RUN_BY_TIER := {
	"very_easy": 0, "easy": 2, "normal": 4, "hard": 6, "very_hard": 8,
}
## stream_rush (Silhouette): zigzag adjacent-lane run length.
const STREAM_NOTES_BY_TIER := {
	"very_easy": 4, "easy": 6, "normal": 8, "hard": 12, "very_hard": 16,
}
const STREAM_SUBDIV_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 4.0, "very_hard": 4.0,
}
## raindrop_scatter (Kawaki wo Ameku): accelerating drip count.
const DRIP_NOTES_BY_TIER := {
	"very_easy": 3, "easy": 4, "normal": 6, "hard": 8, "very_hard": 10,
}
## punk_rush (Kyouran Hey Kids!!): floor-stomp chords then alternating roll.
const STOMP_BEATS_BY_TIER := {
	"very_easy": 2, "easy": 3, "normal": 4, "hard": 4, "very_hard": 4,
}
const RUSH_ROLL_BY_TIER := {
	"very_easy": 0, "easy": 4, "normal": 6, "hard": 8, "very_hard": 12,
}
## diva_belt (New Genesis): belt-hold length and orbiting tap count.
const BELT_HOLD_BEATS_BY_TIER := {
	"very_easy": 2.0, "easy": 2.0, "normal": 3.0, "hard": 3.0, "very_hard": 4.0,
}
const BELT_TAPS_BY_TIER := {
	"very_easy": 0, "easy": 1, "normal": 2, "hard": 3, "very_hard": 4,
}


static func build(motif_name: String, tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	match motif_name:
		"spotlight_switch":
			return _spotlight_switch(tier, rng, anchor_ms, beat_ms)
		"skip_gallop":
			return _skip_gallop(tier, rng, anchor_ms, beat_ms)
		"prowl_pounce":
			return _prowl_pounce(tier, rng, anchor_ms, beat_ms)
		"jackhammer_chaos":
			return _jackhammer_chaos(tier, rng, anchor_ms, beat_ms, occurrence_index)
		"rising_salute":
			return _rising_salute(tier, anchor_ms, beat_ms, occurrence_index)
		"dual_stairs":
			return _dual_stairs(tier, anchor_ms, beat_ms, occurrence_index)
		"ballad_swells":
			return _ballad_swells(tier, rng, anchor_ms, beat_ms)
		"hold_lattice":
			return _hold_lattice(tier, rng, anchor_ms, beat_ms)
		"offbeat_accent":
			return _offbeat_accent(tier, rng, anchor_ms, beat_ms)
		"flick_trill":
			return _flick_trill(tier, rng, anchor_ms, beat_ms)
		"flame_burst":
			return _flame_burst(tier, rng, anchor_ms, beat_ms)
		"stream_rush":
			return _stream_rush(tier, rng, anchor_ms, beat_ms)
		"raindrop_scatter":
			return _raindrop_scatter(tier, rng, anchor_ms, beat_ms)
		"punk_rush":
			return _punk_rush(tier, rng, anchor_ms, beat_ms)
		"diva_belt":
			return _diva_belt(tier, rng, anchor_ms, beat_ms)
		_:
			return {"notes": [] as Array[ChartNote], "span_ms": 0.0}


static func _tap(lane: int, time_ms: float) -> ChartNote:
	var n := ChartNote.new()
	n.lane = clampi(lane, 0, 7)
	n.time_ms = int(round(time_ms))
	n.type = "tap"
	return n


static func _hold(lane: int, time_ms: float, end_ms: float) -> ChartNote:
	var n := ChartNote.new()
	n.lane = clampi(lane, 0, 7)
	n.time_ms = int(round(time_ms))
	n.type = "hold"
	n.end_time_ms = int(round(end_ms))
	return n


## Idol: a two-lane trill under a spotlight that abruptly "teleports" to a
## different lane pair mid-phrase, like the idol switching poses.
static func _spotlight_switch(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var hits: int = SPOTLIGHT_HITS_BY_TIER.get(tier, 6)
	var pairs: int = SPOTLIGHT_PAIRS_BY_TIER.get(tier, 2)
	var step_ms: float = beat_ms / SPOTLIGHT_SUBDIV_BY_TIER.get(tier, 3.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var low: int = rng.randi_range(0, 2)
	for p in pairs:
		for i in hits:
			notes.append(_tap(low if i % 2 == 0 else low + 1, t))
			t += step_ms
		var next_low: int = rng.randi_range(4, 6)
		if p % 2 == 1:
			next_low = rng.randi_range(0, 2)
		low = next_low
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## Yuusha: light dotted skip-step gallops (long-short) hopping to an adjacent
## lane pair each repeat -- bouncy, like the OP's skipping momentum.
static func _skip_gallop(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var units: int = GALLOP_UNITS_BY_TIER.get(tier, 4)
	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var lane: int = rng.randi_range(1, 5)
	var dir: int = 1 if lane < 4 else -1
	for u in units:
		notes.append(_tap(lane, t))
		var second_lane: int = lane + 1 if tier in ["hard", "very_hard"] else lane
		notes.append(_tap(second_lane, t + beat_ms * 0.75))
		t += beat_ms * 1.5
		lane += dir
		if lane <= 0 or lane >= 6:
			dir = -dir
	return {"notes": notes, "span_ms": t - anchor_ms}


## Kaibutsu: a quiet low-lane prowl at beat pace, then a sudden wide pounce
## chord and (upper tiers) a descending claw sweep.
static func _prowl_pounce(tier: String, _rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var steps: int = PROWL_STEPS_BY_TIER.get(tier, 4)
	var chord: int = POUNCE_CHORD_BY_TIER.get(tier, 3)
	var sweep: int = CLAW_SWEEP_BY_TIER.get(tier, 4)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	for i in steps:
		notes.append(_tap(i % 2, t))
		t += beat_ms
	var chord_lanes: Array = range(8 - chord, 8)
	for lane: int in chord_lanes:
		notes.append(_tap(lane, t))
	t += beat_ms * 0.5
	var step_ms: float = beat_ms / 4.0
	for i in sweep:
		notes.append(_tap(7 - i, t))
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## KICK BACK: relentless same-lane jack pairs that slide one lane sideways
## after every pair -- a chainsaw dragged across the keyboard.
static func _jackhammer_chaos(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	var units: int = JACK_UNITS_BY_TIER.get(tier, 4)
	var step_ms: float = beat_ms / JACK_SUBDIV_BY_TIER.get(tier, 3.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var dir: int = 1 if occurrence_index % 2 == 0 else -1
	var lane: int = rng.randi_range(1, 3) if dir == 1 else rng.randi_range(4, 6)
	for u in units:
		notes.append(_tap(lane, t))
		notes.append(_tap(lane, t + step_ms))
		t += step_ms * 2.0
		lane += dir
		if lane <= 0 or lane >= 7:
			dir = -dir
	return {"notes": notes, "span_ms": t - anchor_ms}


## Peace Sign: ascending three-lane stair triplets, each unit starting two
## lanes higher -- a salute climbing the whole keyboard over the phrase.
static func _rising_salute(tier: String, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	var units: int = SALUTE_UNITS_BY_TIER.get(tier, 2)
	var step_ms: float = beat_ms / SALUTE_SUBDIV_BY_TIER.get(tier, 3.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var start: int = occurrence_index % 2
	for u in units:
		var base: int = mini(start + u * 2, 5)
		for i in 3:
			notes.append(_tap(base + i, t))
			t += step_ms
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## Crossing Field: both hands run mirrored staircases that converge to the
## centre, then (on the next occurrence) diverge back out.
static func _dual_stairs(tier: String, anchor_ms: float, beat_ms: float, occurrence_index: int) -> Dictionary:
	var steps: int = STAIR_STEPS_BY_TIER.get(tier, 4)
	var step_ms: float = beat_ms / STAIR_SUBDIV_BY_TIER.get(tier, 2.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var converging: bool = occurrence_index % 2 == 0
	for i in steps:
		var left: int = i if converging else 3 - i
		notes.append(_tap(left, t))
		notes.append(_tap(7 - left, t))
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## Unlasting: one long crescendo hold that resolves into a soft chord --
## sparse and patient, like the ballad's swelling phrases.
static func _ballad_swells(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var hold_beats: float = SWELL_HOLD_BEATS_BY_TIER.get(tier, 4.0)
	var chord: int = SWELL_CHORD_BY_TIER.get(tier, 2)

	var notes: Array[ChartNote] = []
	var hold_lane: int = rng.randi_range(2, 5)
	var hold_end: float = anchor_ms + hold_beats * beat_ms
	notes.append(_hold(hold_lane, anchor_ms, hold_end))
	var lanes: Array = [0, 7, 1, 6]
	for i in chord:
		notes.append(_tap(lanes[i], hold_end))
	return {"notes": notes, "span_ms": hold_beats * beat_ms}


## Zankyosanka: staggered overlapping holds one beat apart on distinct lanes
## (echoing vocal trails), with taps woven between on upper tiers.
static func _hold_lattice(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var hold_count: int = LATTICE_HOLDS_BY_TIER.get(tier, 2)
	var hold_beats: float = LATTICE_HOLD_BEATS_BY_TIER.get(tier, 3.0)
	var tap_count: int = LATTICE_TAPS_BY_TIER.get(tier, 2)

	var notes: Array[ChartNote] = []
	var hold_lanes: Array = []
	var base: int = rng.randi_range(0, 7 - (hold_count - 1) * 2)
	for i in hold_count:
		hold_lanes.append(base + i * 2)
	var t: float = anchor_ms
	for lane: int in hold_lanes:
		notes.append(_hold(lane, t, t + hold_beats * beat_ms))
		t += beat_ms
	var span: float = (t - beat_ms + hold_beats * beat_ms) - anchor_ms
	for i in tap_count:
		var tap_lane: int = base + 1 + i * 2
		if tap_lane > 7 or hold_lanes.has(tap_lane):
			tap_lane = 7 if not hold_lanes.has(7) else 0
		notes.append(_tap(tap_lane, anchor_ms + (i + 1) * beat_ms * 1.5))
	return {"notes": notes, "span_ms": span}


## SPECIALZ: chord stabs planted on the "and" of the beat -- the whole motif
## lives off-grid, matching the song's lurching syncopation.
static func _offbeat_accent(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var stabs: int = OFFBEAT_STABS_BY_TIER.get(tier, 3)
	var chord: int = OFFBEAT_CHORD_BY_TIER.get(tier, 2)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms + beat_ms * 0.5
	for s in stabs:
		var lane: int = rng.randi_range(0, 7 - (chord - 1) * 3)
		for c in chord:
			notes.append(_tap(lane + c * 3, t))
		if tier == "very_hard":
			notes.append(_tap(clampi(lane - 1, 0, 7), t - beat_ms * 0.25))
		t += beat_ms
	return {"notes": notes, "span_ms": t - beat_ms * 0.5 - anchor_ms}


## Kaikai Kitan: tiny three-note zigzag flicks (L, L+2, L+1) that jump to a
## new position each repeat -- quick wrist flicks, never sustained.
static func _flick_trill(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var repeats: int = FLICK_REPEATS_BY_TIER.get(tier, 2)
	var step_ms: float = beat_ms / FLICK_SUBDIV_BY_TIER.get(tier, 3.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	for r in repeats:
		var base: int = rng.randi_range(0, 5)
		for offset: int in [0, 2, 1]:
			notes.append(_tap(base + offset, t))
			t += step_ms
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## Inferno: a calm-shattering eruption -- an adjacent-lane chord slams down,
## an ember run crackles outward, then the chord slams again.
static func _flame_burst(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var chord: int = FLAME_CHORD_BY_TIER.get(tier, 3)
	var run: int = FLAME_RUN_BY_TIER.get(tier, 4)

	var notes: Array[ChartNote] = []
	var base: int = rng.randi_range(0, 7 - chord)
	for c in chord:
		notes.append(_tap(base + c, anchor_ms))
	var t: float = anchor_ms + beat_ms * 0.5
	var step_ms: float = beat_ms / 4.0
	var lane: int = base
	for i in run:
		lane = clampi(lane + (1 if i % 2 == 0 else 2), 0, 7)
		notes.append(_tap(lane, t))
		t += step_ms
	for c in chord:
		notes.append(_tap(base + c, t))
	return {"notes": notes, "span_ms": t - anchor_ms}


## Silhouette: a continuous zigzag stream walking adjacent lanes with
## direction bounces -- pure velocity, the song's driving run feel.
static func _stream_rush(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var count: int = STREAM_NOTES_BY_TIER.get(tier, 8)
	var step_ms: float = beat_ms / STREAM_SUBDIV_BY_TIER.get(tier, 3.0)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var lane: int = rng.randi_range(2, 5)
	var dir: int = 1 if rng.randf() < 0.5 else -1
	for i in count:
		notes.append(_tap(lane, t))
		t += step_ms
		lane += dir
		if lane <= 0 or lane >= 7:
			dir = -dir
	return {"notes": notes, "span_ms": t - anchor_ms}


## Kawaki wo Ameku: accelerating raindrop taps with shrinking gaps that end
## in a two-note "puddle splash" -- irregular timing is the whole point.
static func _raindrop_scatter(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var count: int = DRIP_NOTES_BY_TIER.get(tier, 6)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var gap: float = beat_ms * 0.5
	var last_lane: int = -1
	for i in count:
		var lane: int = rng.randi_range(0, 7)
		if lane == last_lane:
			lane = (lane + 3) % 8
		notes.append(_tap(lane, t))
		last_lane = lane
		t += gap
		gap = maxf(gap * 0.85, beat_ms * 0.2)
	var splash: int = rng.randi_range(0, 4)
	notes.append(_tap(splash, t))
	notes.append(_tap(splash + 3, t))
	return {"notes": notes, "span_ms": t - anchor_ms}


## Kyouran Hey Kids!!: four-on-the-floor two-lane stomps, then a fast
## alternating two-lane roll -- punk downbeats into a scramble.
static func _punk_rush(tier: String, rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var stomps: int = STOMP_BEATS_BY_TIER.get(tier, 4)
	var roll: int = RUSH_ROLL_BY_TIER.get(tier, 6)

	var notes: Array[ChartNote] = []
	var t: float = anchor_ms
	var low: int = rng.randi_range(0, 2)
	for s in stomps:
		notes.append(_tap(low, t))
		notes.append(_tap(low + 4, t))
		t += beat_ms
	var step_ms: float = beat_ms / 4.0
	var pair: Array = [rng.randi_range(3, 4), rng.randi_range(5, 6)]
	for i in roll:
		notes.append(_tap(pair[i % 2], t))
		t += step_ms
	return {"notes": notes, "span_ms": t - anchor_ms}


## New Genesis: a sustained centre-lane belt hold while taps orbit on the
## outer lanes; the top tier belts both centre lanes at once.
static func _diva_belt(tier: String, _rng: RandomNumberGenerator, anchor_ms: float, beat_ms: float) -> Dictionary:
	var hold_beats: float = BELT_HOLD_BEATS_BY_TIER.get(tier, 3.0)
	var taps: int = BELT_TAPS_BY_TIER.get(tier, 2)

	var notes: Array[ChartNote] = []
	var hold_end: float = anchor_ms + hold_beats * beat_ms
	notes.append(_hold(3, anchor_ms, hold_end))
	if tier == "very_hard":
		notes.append(_hold(4, anchor_ms, hold_end))
	var orbit: Array = [0, 6, 1, 7] if tier == "very_hard" else [0, 7, 1, 6]
	var tap_step: float = hold_beats * beat_ms / float(taps + 1)
	for i in taps:
		notes.append(_tap(orbit[i % orbit.size()], anchor_ms + (i + 1) * tap_step))
	return {"notes": notes, "span_ms": hold_beats * beat_ms}
