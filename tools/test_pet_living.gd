extends SceneTree
const Look = preload("res://pet/presentation/motion/pet_look_controller.gd")
const Profile = preload("res://pet/presentation/motion/pet_rig_profile.gd")
const Secondary = preload("res://pet/presentation/motion/pet_secondary_motion.gd")

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: quit(1))
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://scenes/tests/pet_3d_test.tscn") as PackedScene
	var screen := scene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	var actor: Node = screen.actor
	var motion: Node = actor.motion
	motion.set_process(false)
	assert(actor.current_clip == "living" and not actor.player.active)
	# Screen-space input must produce a world-space attention point, on desktop + touch.
	var input := InputEventScreenTouch.new()
	input.index = 0
	input.pressed = true
	input.position = screen.viewport_container.size * Vector2(0.75, 0.4)
	screen._viewport_input(input)
	assert(motion.look.remaining > 0.0)
	assert(motion.secondary.reaction_age == 0.0)
	var original_target: Vector3 = motion.look.target_world
	input.index = 1
	input.position = Vector2.ZERO
	screen._viewport_input(input)
	assert(motion.look.target_world == original_target, "Second finger must not steal attention")
	for i: int in range(90):
		motion.advance(1.0 / 60.0)
	assert(motion.look.angles.length() > 0.01)
	assert(absf(motion.look.angles.y) <= deg_to_rad(motion.profile.yaw_degrees))
	assert(absf(motion.look.angles.x) <= deg_to_rad(motion.profile.pitch_degrees))
	# Current phase intentionally leaves body/root/legs exactly at rest.
	for bone: String in ["Root", "Body", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"]:
		var index: int = actor.skeleton.find_bone(bone)
		assert(actor.skeleton.get_bone_pose(index).is_equal_approx(actor.skeleton.get_bone_rest(index)))
	var head: int = actor.skeleton.find_bone("Head")
	var before: Transform3D = actor.skeleton.get_bone_pose(head)
	actor.set_paused(true)
	var clock: float = motion.secondary.clock
	motion.advance(1.0)
	actor.focus(Vector3(0, 2, 3))
	assert(motion.secondary.clock == clock)
	assert(actor.skeleton.get_bone_pose(head).is_equal_approx(before))
	actor.set_paused(false)
	motion.advance(1.0 / 60.0)
	assert(motion.secondary.clock > clock)
	actor.reset_pose()
	motion.advance(0.1)
	assert(actor.skeleton.get_bone_pose(head).is_equal_approx(actor.skeleton.get_bone_rest(head)))
	# Transition from a diagnostic walk back to living must preserve pose at activation.
	actor.play_clip("walk_test")
	actor.player.advance(0.3)
	before = actor.skeleton.get_bone_pose(head)
	actor.start_living()
	motion.advance(0.0)
	assert(actor.skeleton.get_bone_pose(head).is_equal_approx(before))
	for i: int in range(600):
		motion.advance(1.0 / 60.0)
		var q: Quaternion = actor.skeleton.get_bone_pose_rotation(head)
		assert(q.is_finite() and q.is_normalized())
	# FPS invariance of exponential look smoothing, including transformed actors.
	var frame := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(4, 2, 1))
	var results: Array[Vector2] = []
	for fps: int in [30, 60, 120]:
		var look = Look.new()
		look.focus(frame * Vector3(2, 1, 3), 5.0)
		for i: int in range(fps):
			look.step(1.0 / fps, frame, Profile.new())
		results.append(look.angles)
	assert(results[0].distance_to(results[2]) < 0.00001)
	assert(results[1].x < 0.0 and results[1].y > 0.0)
	var behind = Look.new()
	behind.focus(frame * Vector3(0, 0, -2))
	behind.step(0.1, frame, Profile.new())
	assert(behind.angles == Vector2.ZERO)
	var response = Secondary.new()
	assert(response.react())
	assert(not response.react(), "Touch spam must respect cooldown")
	response.step(4.0, false)
	assert(response.envelope() == 0.0)
	assert(response.react())
	print("PASS: touch mapping, multitouch, actual bone movement, limits, stable feet bones, pause/reset, transition, finite poses, FPS 30/60/120, rotated target, behind target, touch cooldown")
	screen.queue_free()
	await process_frame
	quit()
