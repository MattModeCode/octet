extends SceneTree
## Manual headless verification for WP-D (not part of the run_tests.gd
## suite -- exercises the actual editor_main.tscn scene end-to-end since
## there's no existing scene-level test harness for the editor). Invoke:
##   godot --headless -s tests/verify_wp_d.gd
## Deleted after use.

func _initialize() -> void:
	await process_frame
	await process_frame

	var scene: Control = load("res://editor/editor_main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	var editor_session: Object = root.get_node("EditorSession")

	var bpm_spin: SpinBox = scene.get_node("%BpmSpinBox")
	var offset_spin: SpinBox = scene.get_node("%OffsetSpinBox")
	var status_label: Label = scene.get_node("%StatusLabel")

	print("--- before import ---")
	print("bpm=%s offset=%s status=%s" % [bpm_spin.value, offset_spin.value, status_label.text])

	var song_path := ProjectSettings.globalize_path("res://ThatsWhyIGaveUpOnMusic.mp3")
	scene.call("_on_file_selected", song_path)

	print("--- immediately after import call (before analysis thread finishes) ---")
	print("bpm=%s offset=%s status=%s" % [bpm_spin.value, offset_spin.value, status_label.text])

	# Analysis runs on a background thread and is applied in _process; pump
	# frames until it lands or we time out.
	var waited := 0
	while waited < 300:
		await process_frame
		waited += 1
		if status_label.text.begins_with("Auto-detected"):
			break

	print("--- after auto-analysis applied (waited %d frames) ---" % waited)
	print("bpm=%s offset=%s status=%s" % [bpm_spin.value, offset_spin.value, status_label.text])

	var auto_bpm: float = bpm_spin.value
	assert(auto_bpm > 0.0, "expected auto-detected BPM > 0")
	assert(status_label.text.begins_with("Auto-detected"), "expected status to report auto-detection")

	# Now simulate a hand-edit and confirm a manual re-analyze still works
	# and doesn't get blocked by the clobber guard (guard only applies to
	# the auto path).
	bpm_spin.value = 77.0
	print("--- after hand-edit ---")
	print("bpm=%s user_edited=%s" % [bpm_spin.value, editor_session.bpm_offset_user_edited])
	assert(editor_session.bpm_offset_user_edited == true, "hand-editing BPM should set the edited flag")

	scene.call("_on_analyze_pressed")
	waited = 0
	while waited < 300:
		await process_frame
		waited += 1
		if status_label.text.begins_with("Analysis complete"):
			break

	print("--- after manual re-analyze ---")
	print("bpm=%s offset=%s status=%s user_edited=%s" % [bpm_spin.value, offset_spin.value, status_label.text, editor_session.bpm_offset_user_edited])
	assert(status_label.text.begins_with("Analysis complete"), "manual re-analyze should always apply and report completion")
	assert(editor_session.bpm_offset_user_edited == false, "manual re-analyze result should clear the edited flag")

	print("--- WP-D VERIFICATION PASSED ---")
	quit(0)
