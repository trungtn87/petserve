extends SceneTree
var failures: int = 0
var taps: int = 0
var completed: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var home: CatHomeScreen = load("res://scenes/pet/pet_home_2_5d.tscn").instantiate()
	root.add_child(home)
	await process_frame
	var actor := home.get_pet_actor() as CatPet2D
	check(actor != null, "Home must spawn the shared 2.5D actor")
	if actor == null:
		quit(1)
		return
	actor.set_process(false)
	var profile := actor.profile
	check(profile.is_valid(), "Reference profile must be valid")
	var invalid: CatPresentationProfile = profile.duplicate(true)
	invalid.parts[&"head"]["parent"] = &"eye_left"
	check(not invalid.is_valid(), "Cyclic art hierarchy rejected before construction")
	check(actor._sprites.size() == 10, "All reference parts must spawn")
	check(actor._pivots[&"eye_left"].get_parent() == actor._pivots[&"head"], "Face must follow head")
	for key: StringName in profile.parts:
		var region: Rect2 = profile.parts[key]["region"]
		check(Rect2(Vector2.ZERO, profile.atlas.get_size()).encloses(region), "Part outside atlas: " + str(key))
	actor.action_finished.connect(func(_id: StringName) -> void: completed += 1)
	actor.tapped.connect(func() -> void: taps += 1)
	check(actor.play_action(&"eat"), "Eating supported")
	for i in range(240):
		actor._process(1.0 / 60.0)
	check(actor.action == &"idle" and completed == 1, "Eat must finish exactly once")
	for action: StringName in [&"lie", &"sleep"]:
		check(actor.play_action(action), "Rest action supported")
		for i in range(600):
			actor._process(1.0 / 60.0)
		check(actor.action == action, "Rest must persist until awakened")
	check(actor._sprites[&"eye_left"].texture == actor._textures[&"eye_left_closed"], "Sleeping eyes closed")
	check(actor.play_action(&"wake"), "Wake supported")
	actor._process(0.2)
	check(actor.action == &"idle", "Wake returns to idle")
	check(not actor.play_action(&"unknown"), "Unknown actions rejected")
	# A second data-only profile can remove optional parts without modifying the actor.
	var minimal: CatPresentationProfile = profile.duplicate(true)
	minimal.id = &"test_optional_parts"
	minimal.parts.erase(&"fx")
	minimal.parts.erase(&"ear_right")
	minimal.parts.erase(&"eye_right")
	check(actor.set_profile(minimal), "Optional-parts profile can be applied")
	actor._process(0.1)
	check(actor._sprites.size() == 7, "Removed parts must not survive a swap")
	check(actor.set_profile(profile), "Reference profile can be restored")
	check(actor._sprites.size() == 10, "Profile swap must not accumulate parts")
	# Hit test uses viewport coordinates and wakes only on the actual pet.
	actor.play_action(&"sleep")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(2, 2)
	actor._unhandled_input(mouse)
	check(taps == 0 and actor.action == &"sleep", "Background tap must not wake pet")
	mouse.position = actor.get_global_transform_with_canvas() * Vector2(20, -120)
	actor._unhandled_input(mouse)
	check(taps == 1 and actor.action == &"idle", "Pet tap wakes once")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = mouse.position
	actor._unhandled_input(touch)
	check(taps == 1, "Synthetic mouse + touch pair must not double-trigger")
	# Home actions do not mutate the egg or save system.
	home._on_action(&"food")
	check(actor.action == &"eat", "Home food action routes to eating")
	home._on_action(&"sleep")
	check(actor.action == &"sleep", "Home sleep action routes to sleeping")
	home.free()
	await process_frame
	print("CAT_2_5D_CHECKS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(0 if failures == 0 else 1)
