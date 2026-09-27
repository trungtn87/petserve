extends SceneTree
## Run after import: godot --headless --path . --script res://tools/test_pet_3d.gd

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/tests/pet_3d_test.tscn") as PackedScene
	var screen := scene.instantiate()
	root.add_child(screen)
	await process_frame
	var actor: Node = screen.actor
	assert(actor.skeleton != null, "GLB must have a skeleton")
	assert(actor.skeleton.get_bone_count() == 14, "Unexpected reference rig")
	var head: int = actor.skeleton.find_bone("Head")
	var rest: Quaternion = actor.skeleton.get_bone_rest(head).basis.get_rotation_quaternion()
	for clip: String in ["idle", "curious", "happy", "walk_test"]:
		screen._select_clip(clip)
		actor.player.advance(0.3)
		actor.player.seek(actor.player.current_animation_length * 0.25, true)
		await process_frame
		assert(actor.player.is_playing(), "Clip must play")
		assert(actor.player.current_animation == clip)
		assert(not actor.skeleton.get_bone_pose_rotation(head).is_equal_approx(rest), "Animation must reach skeleton")
		actor.set_paused(true)
		assert(not actor.player.is_playing())
		actor.set_paused(false)
		assert(actor.player.is_playing())
	screen._rotate_actor(90.0)
	assert(is_equal_approx(actor.rotation_degrees.y, 90.0))
	screen._reset_pose()
	assert(not actor.player.is_playing())
	assert(actor.skeleton.get_bone_pose_rotation(head).is_equal_approx(rest))
	print("PASS: rig, four clips, bone tracks, pause/resume, rotation, reset")
	screen.queue_free()
	await process_frame
	quit()
