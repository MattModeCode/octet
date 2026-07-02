extends SceneTree
## Throwaway verification script (same pattern as Stage 3's handoff notes,
## deleted after use) -- builds a JudgeEngine directly, drives a few judged
## notes so hit_errors/judgment_counts are non-empty, sets
## PlaySession.last_engine, then instantiates results.tscn and checks for
## runtime errors on the populated path (breakdown bars + histogram),
## which a standalone F6 run can't reach since PlaySession.last_engine is
## null with no prior session.

func _initialize() -> void:
	await process_frame

	var play_session = get_autoload("PlaySession")
	var config_autoload = get_autoload("Config")

	var oct_io = load("res://core/oct_io.gd")
	var loaded_chart = oct_io.load_oct("res://tests/fixtures/m1a_fixture.oct")

	var judge_engine_script = load("res://game/judge_engine.gd")
	var mods = load("res://game/gameplay_mods.gd").new(false, false)
	var engine = judge_engine_script.new(loaded_chart, config_autoload.gameplay, config_autoload.scoring, mods)

	engine.update(0.0)
	engine.on_lane_press(0, 1000.0)
	engine.on_lane_press(4, 1000.0)
	engine.on_lane_press(2, 1520.0) # slightly late tap
	engine.on_lane_press(3, 2000.0)
	engine.update(2100.0)
	engine.on_lane_release(3, 2260.0)
	engine.update(5000.0) # let remaining windows lapse (misses etc.)

	play_session.last_engine = engine
	play_session.chart_list = ["res://tests/fixtures/m1a_fixture.oct"]
	play_session.chart_index = 0

	var results_scene = load("res://game/results.tscn")
	var results_instance = results_scene.instantiate()
	root.add_child(results_instance)
	await process_frame
	await process_frame

	print("VERIFY_RESULTS_OK: grade=%s score=%d accuracy=%.2f judgment_counts=%s hit_errors=%d" % [
		engine.grade(), engine.score, engine.accuracy() * 100.0, str(engine.judgment_counts), engine.hit_errors.size(),
	])

	quit()


func get_autoload(autoload_name: String):
	return Engine.get_main_loop().root.get_node(autoload_name)
