extends SceneTree
## Throwaway tooling script -- NOT part of the game or test suite. Builds the
## Map Hub's one seed bundle from the repo's only real chart content
## (songs/thats-why-i-gave-up-on-music/*.oct + its mp3) via the same
## OctetBundle.write_bundle() path the editor's export flow uses. Run once,
## by hand, via:
##   godot --headless -s tools/build_seed_bundle.gd --path .
## Safe to delete after maps/thats-why-i-gave-up-on-music.octet exists and is
## committed -- it's not wired into any autoload or registered test.

const SONG_DIR: String = "res://songs/thats-why-i-gave-up-on-music"
const AUDIO_PATH: String = SONG_DIR + "/ThatsWhyIGaveUpOnMusic.mp3"
const OUTPUT_PATH: String = "res://maps/thats-why-i-gave-up-on-music.octet"

const DIFFICULTY_FILES: Array[String] = ["easy.oct", "normal.oct", "hard.oct"]


func _initialize() -> void:
	var charts: Array[Chart] = []
	for file_name in DIFFICULTY_FILES:
		var chart := OctIO.load_oct(SONG_DIR.path_join(file_name))
		if chart == null:
			printerr("build_seed_bundle: failed to load %s" % file_name)
			quit(1)
			return
		charts.append(chart)

	var first_chart: Chart = charts[0]
	var manifest := {
		"title": first_chart.metadata.title,
		"artist": first_chart.metadata.artist,
		"mapper": first_chart.metadata.mapper,
	}

	var err := OctetBundle.write_bundle(OUTPUT_PATH, AUDIO_PATH, charts, manifest)
	if err != OK:
		printerr("build_seed_bundle: write_bundle failed with error %d" % err)
		quit(1)
		return

	var abs_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var size := FileAccess.get_file_as_bytes(OUTPUT_PATH).size()
	print("build_seed_bundle: wrote %s (%d bytes)" % [abs_path, size])
	quit(0)
