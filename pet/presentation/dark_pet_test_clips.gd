extends RefCounted
## Reference-pet animation authoring. Bone names belong here, not in Pet Core.
## All tracks are local bone poses based on the imported rest pose.

const BONES: Array[String] = [
	"Body", "Head", "Ear_L", "Ear_R", "Tail_01", "Tail_02", "Tail_03",
	"Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"
]

static func build(skeleton: Skeleton3D, root: Node) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for clip_name: String in ["RESET", "idle", "curious", "happy", "walk_test"]:
		var clip := Animation.new()
		clip.length = 2.4 if clip_name != "walk_test" else 1.0
		clip.loop_mode = Animation.LOOP_NONE if clip_name == "RESET" else Animation.LOOP_LINEAR
		for bone_name: String in BONES:
			var bone_index := skeleton.find_bone(bone_name)
			if bone_index < 0:
				push_warning("Dark Pet test: missing bone " + bone_name)
				continue
			var rest := skeleton.get_bone_rest(bone_index)
			var path := NodePath(str(root.get_path_to(skeleton)) + ":" + bone_name)
			var rotation_track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(rotation_track, path)
			var samples := 1 if clip_name == "RESET" else 33
			for sample: int in range(samples):
				var phase := float(sample) / 32.0 * TAU
				var offset := _rotation(clip_name, bone_name, phase)
				var rotation := rest.basis.get_rotation_quaternion() * Quaternion.from_euler(offset)
				clip.rotation_track_insert_key(rotation_track, float(sample) / 32.0 * clip.length, rotation)
			if bone_name == "Body":
				var position_track := clip.add_track(Animation.TYPE_POSITION_3D)
				clip.track_set_path(position_track, path)
				for sample: int in range(samples):
					var phase := float(sample) / 32.0 * TAU
					var lift := 0.0 if clip_name == "RESET" else 0.008 * sin(phase)
					clip.position_track_insert_key(position_track, float(sample) / 32.0 * clip.length, rest.origin + Vector3.UP * lift)
		library.add_animation(clip_name, clip)
	return library

static func _rotation(clip: String, bone: String, phase: float) -> Vector3:
	if clip == "RESET":
		return Vector3.ZERO
	var wave := sin(phase)
	var angle := Vector3.ZERO
	if bone == "Head":
		angle.x = 0.025 * wave
		if clip == "curious":
			angle.y = 0.12 * wave
			angle.z = 0.08 * sin(phase + 0.5)
	if bone.begins_with("Ear_"):
		angle.z = (0.07 if clip == "happy" else 0.025) * wave
		if bone == "Ear_R":
			angle.z *= -1.0
	if bone.begins_with("Tail_"):
		angle.z = (0.10 if clip == "happy" else 0.035) * wave
	if clip == "walk_test" and bone.begins_with("Leg_"):
		var sign_value := 1.0 if bone in ["Leg_FL", "Leg_BR"] else -1.0
		angle.x = 0.14 * wave * sign_value
	return angle
