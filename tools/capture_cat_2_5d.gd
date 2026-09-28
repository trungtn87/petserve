extends SceneTree
func _initialize() -> void:
	call_deferred("_capture")
func _capture() -> void:
	root.size = Vector2i(360, 640)
	var home: CatHomeScreen = load("res://scenes/pet/pet_home_2_5d.tscn").instantiate()
	root.add_child(home)
	await process_frame
	var actor: CatPet2D = home.get_pet_actor()
	DirAccess.make_dir_recursive_absolute("res://docs/previews/cat2d")
	for action: StringName in [&"idle", &"eat", &"lie", &"sleep", &"wake"]:
		actor.play_action(action)
		await create_timer(2.0 if action == &"idle" else 1.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/previews/cat2d/%s.png" % action)
	home.menu.open_menu()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/cat2d/menu.png")
	quit()
