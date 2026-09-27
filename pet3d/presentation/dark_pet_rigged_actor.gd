class_name DarkPetRiggedActor
extends Node3D

signal tapped

@export var skeleton_path: NodePath = NodePath("DarkPetModel/DarkPetSkeleton/Skeleton3D")
@export var debug_material_override: bool = true
@export var diagnostic_mode: bool = true
@export var diagnostic_step_seconds: float = 2.4

@onready var model_root: Node3D = $DarkPetModel

var _skeleton: Skeleton3D
var _time := 0.0
var _bones: Dictionary = {}
var _rest_rotations: Dictionary = {}
var _diagnostic_step := -1

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
		_update_diagnostic()
	else:
		_update_normal_idle()

func set_look_target(_target: Vector3) -> void:
	pass

func react_to_touch() -> void:
	if diagnostic_mode:
		_time = (floor(_time / diagnostic_step_seconds) + 1.0) * diagnostic_step_seconds
	else:
		_set_bone_offset("Ear_L", Vector3(0, 0, -0.35))
		_set_bone_offset("Ear_R", Vector3(0, 0, 0.35))
	tapped.emit()

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
			_animate_tail(wave)
		6:
			_set_bone_offset("Head", Vector3(0.0, wave * 0.45, 0.0))
			_set_bone_offset("Ear_L", Vector3(0.0, 0.0, wave * 0.7))
			_set_bone_offset("Ear_R", Vector3(0.0, 0.0, -wave * 0.7))
			_set_bone_offset("Leg_FL", Vector3(wave * 0.35, 0.0, 0.0))
			_set_bone_offset("Leg_FR", Vector3(-wave * 0.35, 0.0, 0.0))
			_animate_tail(wave * 0.75)

func _update_normal_idle() -> void:
	_reset_bones()
	_set_bone_offset("Body", Vector3(sin(_time * 2.0) * 0.018, 0, 0))
	_animate_tail(sin(_time * 1.3) * 0.20)

func _animate_tail(amount: float) -> void:
	_set_bone_offset("Tail_01", Vector3(0, amount * 0.45, amount * 0.40))
	_set_bone_offset("Tail_02", Vector3(0, amount * 0.65, amount * 0.60))
	_set_bone_offset("Tail_03", Vector3(0, amount * 0.85, amount * 0.80))
	_set_bone_offset("Tail_04", Vector3(0, amount, amount))

func _cache_bones() -> void:
	for bone_name in ["Root", "Body", "Neck", "Head", "Ear_L", "Ear_R", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Tail_01", "Tail_02", "Tail_03", "Tail_04"]:
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
	_skeleton.set_bone_pose_rotation(_bones[bone_name], rest * Quaternion.from_euler(euler))

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
