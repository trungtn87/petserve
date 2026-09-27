class_name DarkPetRiggedActor
extends PetActor3D


@export var skeleton_path: NodePath = NodePath("DarkPetModel/DarkPetSkeleton/Skeleton3D")
@export var debug_material_override: bool = true
@export var diagnostic_mode: bool = false
@export var diagnostic_step_seconds: float = 2.4

@export_group("Soft Idle Motion")
@export_range(0.2, 3.0, 0.05) var breath_speed: float = 0.65
@export_range(0.0, 3.0, 0.05) var breath_degrees: float = 0.9
@export_range(0.0, 0.03, 0.001) var breath_lift: float = 0.010
@export_range(0.0, 3.0, 0.05) var body_sway_degrees: float = 0.8
@export_range(0.0, 10.0, 0.1) var head_look_yaw_degrees: float = 7.0
@export_range(0.0, 8.0, 0.1) var head_look_pitch_degrees: float = 4.5
@export_range(1.0, 12.0, 0.1) var head_follow_smoothing: float = 3.8
@export_range(0.0, 5.0, 0.1) var ear_idle_degrees: float = 2.4
@export_range(0.0, 16.0, 0.1) var tail_idle_degrees: float = 5.5
@export_range(0.2, 3.0, 0.05) var tail_speed: float = 0.75
@export_range(1.0, 12.0, 0.1) var tail_smoothing: float = 4.0
@export_range(0.0, 3.0, 0.05) var weight_shift_degrees: float = 0.35
@export_range(0.0, 10.0, 0.1) var touch_reaction_degrees: float = 4.0
@export_range(0.0, 3.0, 0.05) var look_height: float = 1.15

@onready var model_root: Node3D = $DarkPetModel

var _skeleton: Skeleton3D
var _time := 0.0
var _bones: Dictionary = {}
var _rest_rotations: Dictionary = {}
var _diagnostic_step := -1

var _model_rest_position := Vector3.ZERO
var _look_target := Vector3.ZERO
var _has_look_target := false
var _look_yaw := 0.0
var _look_pitch := 0.0
var _touch_reaction := 0.0
var _tail_offsets := Vector4.ZERO

const DIAGNOSTIC_STEPS := [
	"HEAD",
	"EAR LEFT",
	"EAR RIGHT",
	"FRONT LEGS",
	"BACK LEGS",
	"TAIL",
	"ALL"
]

func _ready() -> void:
	_model_rest_position = model_root.position
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		push_error("DarkPetRiggedActor: Skeleton3D not found")
		return
	_cache_bones()
	if debug_material_override:
		_apply_debug_material(model_root)

func _process(delta: float) -> void:
	if _skeleton == null:
		return

	_time += delta

	if diagnostic_mode:
		_model_root_to_rest()
		_update_diagnostic()
		return

	_update_touch_reaction(delta)
	_update_normal_idle(delta)

func set_look_target(target: Vector3) -> void:
	_look_target = target
	_has_look_target = true

func react_to_touch() -> void:
	if diagnostic_mode:
		_time = (floor(_time / diagnostic_step_seconds) + 1.0) * diagnostic_step_seconds
	else:
		_touch_reaction = 1.0
	tapped.emit()

func _update_normal_idle(delta: float) -> void:
	_reset_bones()
	_update_look(delta)

	var breath := sin(_time * breath_speed * TAU * 0.5)
	var slow_sway := sin(_time * 0.55 + 0.7)
	var breath_angle := deg_to_rad(breath_degrees) * breath
	var sway_angle := deg_to_rad(body_sway_degrees) * slow_sway

	model_root.position = _model_rest_position + Vector3(0.0, breath * breath_lift, 0.0)

	_set_bone_offset(
		"Body",
		Vector3(
			breath_angle,
			0.0,
			sway_angle
		)
	)

	var auto_yaw := (
		sin(_time * 0.43 + 0.4) * deg_to_rad(1.15)
		+ sin(_time * 0.19 + 1.7) * deg_to_rad(0.55)
	)
	var auto_pitch := sin(_time * 0.37 + 0.9) * deg_to_rad(0.70)
	var touch_nod := -deg_to_rad(touch_reaction_degrees) * _touch_reaction

	var head_yaw := _look_yaw + auto_yaw
	var head_pitch := _look_pitch + auto_pitch + touch_nod

	_set_bone_offset(
		"Neck",
		Vector3(
			head_pitch * 0.34,
			head_yaw * 0.34,
			-sway_angle * 0.20
		)
	)

	_set_bone_offset(
		"Head",
		Vector3(
			head_pitch * 0.66,
			head_yaw * 0.66,
			sin(_time * 0.31) * deg_to_rad(0.35)
		)
	)

	_update_ears()
	_update_tail(delta)
	_update_weight_shift(breath)

func _update_look(delta: float) -> void:
	var desired_yaw := 0.0
	var desired_pitch := 0.0

	if _has_look_target:
		var local_target := to_local(_look_target)
		desired_yaw = clampf(
			local_target.x * 0.080,
			-deg_to_rad(head_look_yaw_degrees),
			deg_to_rad(head_look_yaw_degrees)
		)
		desired_pitch = clampf(
			-(local_target.y - look_height) * 0.065,
			-deg_to_rad(head_look_pitch_degrees),
			deg_to_rad(head_look_pitch_degrees)
		)

	var weight := _damp(head_follow_smoothing, delta)
	_look_yaw = lerp_angle(_look_yaw, desired_yaw, weight)
	_look_pitch = lerp_angle(_look_pitch, desired_pitch, weight)

func _update_ears() -> void:
	var idle_amount := deg_to_rad(ear_idle_degrees)
	var touch_amount := deg_to_rad(touch_reaction_degrees) * _touch_reaction

	var left_idle := sin(_time * 0.82 + 0.25) * idle_amount
	var right_idle := sin(_time * 0.73 + 1.10) * idle_amount * 0.85

	_set_bone_offset(
		"Ear_L",
		Vector3(0.0, 0.0, left_idle - touch_amount)
	)
	_set_bone_offset(
		"Ear_R",
		Vector3(0.0, 0.0, -right_idle + touch_amount)
	)

func _update_tail(delta: float) -> void:
	var base_amount := deg_to_rad(tail_idle_degrees)
	var touch_wave := (
		sin(_time * 7.0)
		* deg_to_rad(touch_reaction_degrees)
		* _touch_reaction
	)

	var target_1 := sin(_time * tail_speed) * base_amount * 0.48 + touch_wave * 0.35
	var target_2 := sin(_time * tail_speed - 0.30) * base_amount * 0.68 + touch_wave * 0.55
	var target_3 := sin(_time * tail_speed - 0.60) * base_amount * 0.86 + touch_wave * 0.75
	var target_4 := sin(_time * tail_speed - 0.90) * base_amount + touch_wave

	var weight := _damp(tail_smoothing, delta)
	_tail_offsets.x = lerpf(_tail_offsets.x, target_1, weight)
	_tail_offsets.y = lerpf(_tail_offsets.y, target_2, weight)
	_tail_offsets.z = lerpf(_tail_offsets.z, target_3, weight)
	_tail_offsets.w = lerpf(_tail_offsets.w, target_4, weight)

	_set_bone_offset("Tail_01", Vector3(0.0, _tail_offsets.x * 0.42, _tail_offsets.x))
	_set_bone_offset("Tail_02", Vector3(0.0, _tail_offsets.y * 0.48, _tail_offsets.y))
	_set_bone_offset("Tail_03", Vector3(0.0, _tail_offsets.z * 0.54, _tail_offsets.z))
	_set_bone_offset("Tail_04", Vector3(0.0, _tail_offsets.w * 0.60, _tail_offsets.w))

func _update_weight_shift(breath: float) -> void:
	var shift := sin(_time * 0.62 + 1.2) * deg_to_rad(weight_shift_degrees)
	var settle := breath * deg_to_rad(weight_shift_degrees) * 0.35

	_set_bone_offset("Leg_FL", Vector3(shift + settle, 0.0, 0.0))
	_set_bone_offset("Leg_FR", Vector3(-shift * 0.70 - settle, 0.0, 0.0))
	_set_bone_offset("Leg_BL", Vector3(-shift * 0.55, 0.0, 0.0))
	_set_bone_offset("Leg_BR", Vector3(shift * 0.45, 0.0, 0.0))

func _update_touch_reaction(delta: float) -> void:
	if _touch_reaction <= 0.0:
		return

	_touch_reaction *= exp(-4.2 * delta)
	if _touch_reaction < 0.001:
		_touch_reaction = 0.0

func _update_diagnostic() -> void:
	var step := int(floor(_time / diagnostic_step_seconds)) % DIAGNOSTIC_STEPS.size()
	if step != _diagnostic_step:
		_diagnostic_step = step
		print("DARK PET RIG TEST: ", DIAGNOSTIC_STEPS[step])

	_reset_bones()

	var phase := fmod(_time, diagnostic_step_seconds) / diagnostic_step_seconds
	var wave := sin(phase * TAU) * 0.55

	match step:
		0:
			_set_bone_offset("Head", Vector3(0.0, wave, 0.0))
		1:
			_set_bone_offset("Ear_L", Vector3(0.0, 0.0, wave * 1.25))
		2:
			_set_bone_offset("Ear_R", Vector3(0.0, 0.0, wave * 1.25))
		3:
			_set_bone_offset("Leg_FL", Vector3(wave, 0.0, 0.0))
			_set_bone_offset("Leg_FR", Vector3(-wave, 0.0, 0.0))
		4:
			_set_bone_offset("Leg_BL", Vector3(wave, 0.0, 0.0))
			_set_bone_offset("Leg_BR", Vector3(-wave, 0.0, 0.0))
		5:
			_animate_tail_diagnostic(wave)
		6:
			_set_bone_offset("Head", Vector3(0.0, wave * 0.45, 0.0))
			_set_bone_offset("Ear_L", Vector3(0.0, 0.0, wave * 0.7))
			_set_bone_offset("Ear_R", Vector3(0.0, 0.0, -wave * 0.7))
			_set_bone_offset("Leg_FL", Vector3(wave * 0.35, 0.0, 0.0))
			_set_bone_offset("Leg_FR", Vector3(-wave * 0.35, 0.0, 0.0))
			_animate_tail_diagnostic(wave * 0.75)

func _animate_tail_diagnostic(amount: float) -> void:
	_set_bone_offset("Tail_01", Vector3(0.0, amount * 0.45, amount * 0.40))
	_set_bone_offset("Tail_02", Vector3(0.0, amount * 0.65, amount * 0.60))
	_set_bone_offset("Tail_03", Vector3(0.0, amount * 0.85, amount * 0.80))
	_set_bone_offset("Tail_04", Vector3(0.0, amount, amount))

func _cache_bones() -> void:
	for bone_name in [
		"Root",
		"Body",
		"Neck",
		"Head",
		"Ear_L",
		"Ear_R",
		"Leg_FL",
		"Leg_FR",
		"Leg_BL",
		"Leg_BR",
		"Tail_01",
		"Tail_02",
		"Tail_03",
		"Tail_04"
	]:
		var index := _skeleton.find_bone(bone_name)
		if index >= 0:
			_bones[bone_name] = index
			_rest_rotations[bone_name] = _skeleton.get_bone_pose_rotation(index)
		else:
			push_warning("Dark Pet bone missing: %s" % bone_name)

func _reset_bones() -> void:
	for bone_name in _bones:
		var index: int = _bones[bone_name]
		var rest: Quaternion = _rest_rotations[bone_name]
		_skeleton.set_bone_pose_rotation(index, rest)

func _set_bone_offset(bone_name: String, euler: Vector3) -> void:
	if not _bones.has(bone_name):
		return

	var rest: Quaternion = _rest_rotations[bone_name]
	_skeleton.set_bone_pose_rotation(
		_bones[bone_name],
		rest * Quaternion.from_euler(euler)
	)

func _model_root_to_rest() -> void:
	model_root.position = _model_rest_position

func _damp(speed: float, delta: float) -> float:
	return 1.0 - exp(-speed * delta)

func _apply_debug_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.18, 0.11, 0.30, 1.0)
		material.roughness = 0.8
		material.vertex_color_use_as_albedo = true
		mesh_instance.material_override = material

	for child in node.get_children():
		_apply_debug_material(child)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D

	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found

	return null
