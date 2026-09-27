extends RefCounted
## Rig-v4 diagnostic clips; local +Z forward. Each clip owns the same tracks.
const BONES: Array[String] = [
	"Body", "Neck", "Head", "Ear_L", "Ear_R", "Tail_01", "Tail_02", "Tail_03", "Tail_04",
	"Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"
]
const LENGTHS: Dictionary = {"RESET": 0.1, "idle": 4.6, "curious": 3.2, "happy": 2.4, "walk_test": 1.2}

static func build(skeleton: Skeleton3D, root: Node) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for clip_name: String in LENGTHS:
		var clip := Animation.new()
		clip.length = LENGTHS[clip_name]
		clip.loop_mode = Animation.LOOP_NONE if clip_name == "RESET" else Animation.LOOP_LINEAR
		for bone_name: String in BONES:
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index < 0:
				push_warning("Dark Pet test: missing bone " + bone_name)
				continue
			var rest := skeleton.get_bone_rest(bone_index)
			var path := NodePath(str(root.get_path_to(skeleton)) + ":" + bone_name)
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
			var samples := 1 if clip_name == "RESET" else 65
			for sample: int in range(samples):
				var phase := float(sample) / 64.0 * TAU
				var rotation := rest.basis.get_rotation_quaternion() * Quaternion.from_euler(_rotation(clip_name, bone_name, phase))
				clip.rotation_track_insert_key(track, float(sample) / 64.0 * clip.length, rotation)
		library.add_animation(clip_name, clip)
	return library

static func _rotation(clip: String, bone: String, phase: float) -> Vector3:
	if clip == "RESET":
		return Vector3.ZERO
	var wave := sin(phase)
	var angle := Vector3.ZERO
	if bone == "Neck":
		angle.x = deg_to_rad(0.4) * wave
	if bone == "Head":
		angle.x = deg_to_rad(0.8) * wave
		if clip == "curious":
			# Look, pause briefly at each side, then turn. Not a continuous roll.
			angle.y = deg_to_rad(11.0) * smoothstep(-0.8, 0.8, wave) * 2.0 - deg_to_rad(11.0)
			angle.z = deg_to_rad(4.0) * wave
		elif clip == "happy":
			angle.x = deg_to_rad(2.2) * sin(phase * 2.0)
	if bone.begins_with("Ear_"):
		var side := 1.0 if bone == "Ear_L" else -1.0
		angle.z = deg_to_rad(4.5 if clip == "happy" else 1.4) * sin(phase + (0.3 if side < 0.0 else 0.0)) * side
	if bone.begins_with("Tail_"):
		var segment := int(bone.right(2)) - 1
		# The repaired chain runs backwards in -Z; yaw sways it sideways.
		angle.y = deg_to_rad(6.0 if clip == "happy" else 2.0) * sin(phase * (2.0 if clip == "happy" else 1.0) - segment * 0.4)
	if clip == "walk_test" and bone.begins_with("Leg_"):
		# Four-beat walk order. Single-bone legs still cannot bend or lock a foot.
		var phases := {"Leg_BL": 0.0, "Leg_FL": PI * 0.5, "Leg_BR": PI, "Leg_FR": PI * 1.5}
		angle.x = deg_to_rad(9.0) * sin(phase + float(phases[bone]))
	return angle
