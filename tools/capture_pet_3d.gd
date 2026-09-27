extends SceneTree
## Optional visual QA. Run with a rendering display, not --headless.
## godot --path . --script res://tools/capture_pet_3d.gd -- /absolute/output/folder
var output: String
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not args[0].is_absolute_path():
		push_error("Pass an absolute screenshot output folder after --")
		quit(1)
		return
	output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(360, 640)
	var screen := (load("res://scenes/tests/pet_3d_test.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await create_timer(0.2).timeout
	screen.actor.motion.set_process(false)
	screen.actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for view: Array in [["front", 18.0], ["side", 108.0], ["rear", 198.0]]:
		screen._rotate_actor(view[1])
		for clip: String in ["RESET", "curious", "happy", "walk_test"]:
			if clip == "RESET":
				screen._reset_pose()
			else:
				screen._select_clip(clip)
				screen.actor.player.advance(0.3)
				screen.actor.player.seek(screen.actor.player.current_animation_length * 0.25, true)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(view[0] + "_" + clip + ".png"))
	screen._rotate_actor(18.0)
	screen._start_living()
	screen.actor.focus(screen.camera.global_position)
	for frame: int in range(120):
		screen.actor.motion.advance(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("living_%03d.png" % frame))
	print("VISUAL_CAPTURE_OK ", output)
	quit()
