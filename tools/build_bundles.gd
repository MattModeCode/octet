extends SceneTree
## Throwaway tooling script -- NOT part of the game or test suite. Generalizes
## tools/build_seed_bundle.gd (kept as-is, historical/disposable) to pack
## every song under res://songs/ into its own maps/<slug>.octet bundle via
## the same OctetBundle.write_bundle() path the editor's export flow uses --
## including the pre-existing thats-why-i-gave-up-on-music bundle, which
## needs rebuilding now that its charts' artist metadata changed (was
## "Unknown Artist", now the real artist).
##
## Run once, by hand, via:
##   <path-to-godot> --headless -s tools/build_bundles.gd --path .
## Safe to re-run (overwrites the .octet files) or delete once the bundles
## are committed -- it's not wired into any autoload or registered test.

const ALL_TIER_FILES: Array = [
	"very_easy.oct", "easy.oct", "normal.oct", "hard.oct", "very_hard.oct",
]

const SONGS: Array[Dictionary] = [
	{
		"slug": "thats-why-i-gave-up-on-music",
		"audio_filename": "ThatsWhyIGaveUpOnMusic.mp3",
		"difficulty_files": ["easy.oct", "normal.oct", "hard.oct"],
	},
	{
		"slug": "unravel-tokyo-ghoul",
		"audio_filename": "Unravel.mp3",
		"difficulty_files": ["normal.oct", "very_hard.oct"],
	},
	{
		"slug": "one-voice",
		"audio_filename": "OneVoice.mp3",
		"difficulty_files": ["easy.oct", "hard.oct"],
	},
	{
		"slug": "a-thousand-years",
		"audio_filename": "AThousandYears.mp3",
		"difficulty_files": ["very_easy.oct", "normal.oct"],
	},
	{
		"slug": "story-of-a-warrior",
		"audio_filename": "StoryOfAWarrior.mp3",
		"difficulty_files": ["normal.oct", "hard.oct"],
	},
	{
		"slug": "drowning-love",
		"audio_filename": "ChasingKou.mp3",
		"difficulty_files": ["easy.oct", "very_hard.oct"],
	},
	## -- anime OP/ED batch: all five tiers each.
	{"slug": "idol", "audio_filename": "Idol.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "yuusha", "audio_filename": "Yuusha.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "kaibutsu", "audio_filename": "Kaibutsu.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "kickback", "audio_filename": "KickBack.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "peace-sign", "audio_filename": "PeaceSign.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "crossing-field", "audio_filename": "CrossingField.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "unlasting", "audio_filename": "Unlasting.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "zankyosanka", "audio_filename": "Zankyosanka.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "specialz", "audio_filename": "Specialz.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "kaikai-kitan", "audio_filename": "KaikaiKitan.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "inferno", "audio_filename": "Inferno.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "silhouette", "audio_filename": "Silhouette.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "crying-for-rain", "audio_filename": "CryingForRain.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "kyouran-hey-kids", "audio_filename": "KyouranHeyKids.mp3", "difficulty_files": ALL_TIER_FILES},
	{"slug": "new-genesis", "audio_filename": "NewGenesis.mp3", "difficulty_files": ALL_TIER_FILES},
]


func _initialize() -> void:
	var failures := 0
	for song: Dictionary in SONGS:
		var song_dir: String = "res://songs/%s" % song.slug
		var audio_path: String = song_dir.path_join(song.audio_filename)
		var output_path: String = "res://maps/%s.octet" % song.slug

		var charts: Array[Chart] = []
		for file_name: String in song.difficulty_files:
			var chart := OctIO.load_oct(song_dir.path_join(file_name))
			if chart == null:
				printerr("build_bundles: failed to load %s/%s" % [song_dir, file_name])
				failures += 1
				chart = null
				continue
			charts.append(chart)

		if charts.size() != song.difficulty_files.size():
			printerr("build_bundles: skipping %s -- not all difficulty charts loaded" % song.slug)
			failures += 1
			continue

		var first_chart: Chart = charts[0]
		var manifest := {
			"title": first_chart.metadata.title,
			"artist": first_chart.metadata.artist,
			"mapper": first_chart.metadata.mapper,
		}

		var err := OctetBundle.write_bundle(output_path, audio_path, charts, manifest)
		if err != OK:
			printerr("build_bundles: write_bundle failed for %s (error %d)" % [song.slug, err])
			failures += 1
			continue

		var size := FileAccess.get_file_as_bytes(output_path).size()
		print("build_bundles: wrote %s (%d bytes)" % [output_path, size])

	if failures > 0:
		printerr("build_bundles: %d song(s) failed" % failures)
		quit(1)
		return
	quit(0)
