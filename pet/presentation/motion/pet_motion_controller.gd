extends Node
## Sole pose writer in living mode. Legacy AnimationPlayer MUST be stopped.
## Each frame composes offsets from cached rest; no cumulative rotations.
const Look = preload("res://pet/presentation/motion/pet_look_controller.gd")
const Secondary = preload("res://pet/presentation/motion/pet_secondary_motion.gd")
var look = Look.new()
var secondary = Secondary.new()
var profile: Resource
var skeleton: Skeleton3D
var enabled: bool = false
var paused: bool = false
var strength: float = 1.0
var bones: Dictionary = {}
var rests: Dictionary = {}
var start_poses: Dictionary = {}
var fade_age: float = 0.0
var idle_target_timer: float = 2.0

func configure(rig: Skeleton3D, rig_profile: Resource) -> void:
	skeleton = rig
	profile = rig_profile
	for index: int in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(index)
		bones[bone_name] = index
		rests[bone_name] = skeleton.get_bone_rest(index)

func activate() -> void:
	start_poses.clear()
	for key: String in bones:
		start_poses[key] = skeleton.get_bone_pose(bones[key])
	fade_age = 0.0
	look.clear()
	secondary = Secondary.new()
	idle_target_timer = 2.0
	paused = false
	enabled = true

func deactivate() -> void:
	enabled = false
	look.clear()

func focus(point: Vector3, touched: bool = true) -> void:
	if not enabled or paused:
		return
	look.focus(point)
	idle_target_timer = 5.0
	if touched:
		secondary.react()


func react() -> void:
	if not enabled or paused:
		return
	secondary.react()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not enabled or paused or skeleton == null:
		return
	# Avoid a large jump after resume from a suspended mobile app.
	var dt := clampf(delta, 0.0, 0.1)
	fade_age += dt
	var head_index: int = bones.get(String(profile.head), -1)
	if head_index < 0:
		return
	var head_frame := skeleton.global_transform * skeleton.get_bone_global_rest(head_index)
	idle_target_timer -= dt
	if idle_target_timer <= 0.0 and look.remaining <= 0.0:
		var point := Vector3(secondary.rng.randf_range(-0.2, 0.2), secondary.rng.randf_range(-0.08, 0.1), 2.0)
		look.focus(head_frame * point, secondary.rng.randf_range(0.6, 1.2))
		idle_target_timer = secondary.rng.randf_range(3.0, 6.0)
	look.step(dt, head_frame, profile)
	secondary.step(dt, look.remaining > 0.0)
	# Lower-amplitude inhale, longer exhale; no whole-model vertical bob.
	var phase := fmod(secondary.clock, 4.6) / 4.6
	var breath := smoothstep(0.0, 0.38, phase) if phase < 0.38 else 1.0 - smoothstep(0.38, 1.0, phase)
	breath -= 0.5
	var envelope: float = secondary.envelope()
	var pitch: float = look.angles.x + deg_to_rad(profile.breath_degrees) * breath - deg_to_rad(1.5) * envelope
	var yaw: float = look.angles.y
	var tilt: float = deg_to_rad(profile.tilt_degrees) * envelope
	# Reset every bone to avoid leftover walk poses, including unowned legs.
	skeleton.reset_bone_poses()
	_rotate(profile.neck, Vector3(pitch * 0.3, yaw * 0.3, 0.0))
	_rotate(profile.head, Vector3(pitch * 0.7, yaw * 0.7, tilt))
	for side: int in range(profile.ears.size()):
		_rotate(profile.ears[side], Vector3(0, 0, secondary.ear_offset(side, deg_to_rad(profile.ear_degrees))))
	for index: int in range(profile.tail.size()):
		_rotate(profile.tail[index], Vector3(0, secondary.tail_offset(index, deg_to_rad(profile.tail_degrees)), 0))
	var blend := smoothstep(0.0, 0.4, fade_age)
	if blend < 1.0:
		for key: String in bones:
			var index: int = bones[key]
			var start: Transform3D = start_poses[key]
			skeleton.set_bone_pose(index, start.interpolate_with(skeleton.get_bone_pose(index), blend))

func _rotate(bone_name: StringName, euler: Vector3) -> void:
	var key := String(bone_name)
	if not bones.has(key):
		return
	var rest: Transform3D = rests[key]
	skeleton.set_bone_pose_rotation(bones[key], rest.basis.get_rotation_quaternion() * Quaternion.from_euler(euler * strength))
