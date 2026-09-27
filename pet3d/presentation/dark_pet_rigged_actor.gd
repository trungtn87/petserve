class_name DarkPetRiggedActor
extends Node3D

signal tapped

@export var skeleton_path: NodePath = NodePath("DarkPetModel/DarkPetSkeleton/Skeleton3D")
@export var head_turn_limit: float = 0.16
@export var head_pitch_limit: float = 0.08
@export var look_smoothing: float = 4.0
@export var debug_rig_motion: bool = true
@export var debug_material_override: bool = true

@onready var model_root: Node3D = $DarkPetModel

var _skeleton: Skeleton3D
var _look_target := Vector3(0.0, 1.2, 4.0)
var _time := 0.0
var _touch_impulse := 0.0
var _bones: Dictionary = {}
var _rest_rotations: Dictionary = {}

func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		push_error("DarkPetRiggedActor: Skeleton3D not found in imported GLB")
		return
	_cache_bones()
	if debug_material_override:
		_apply_debug_material(model_root)

func _process(delta: float) -> void:
	if _skeleton == null:
		return
	_time += delta
	_touch_impulse = move_toward(_touch_impulse, 0.0, delta * 1.35)
	_update_body()
	_update_head(delta)
	_update_ears()
	_update_tail()
	_update_legs()

func set_look_target(target: Vector3) -> void:
	_look_target = target

func react_to_touch() -> void:
	_touch_impulse = 1.0
	tapped.emit()

func _cache_bones() -> void:
	for bone_name in ["Root", "Body", "Neck", "Head", "Ear_L", "Ear_R", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Tail_01", "Tail_02", "Tail_03", "Tail_04"]:
		var index := _skeleton.find_bone(bone_name)
		if index >= 0:
			_bones[bone_name] = index
			_rest_rotations[bone_name] = _skeleton.get_bone_pose_rotation(index)
		else:
			push_warning("Dark Pet bone missing: %s" % bone_name)

func _update_body() -> void:
	var breathe := sin(_time * 2.0) * 0.018
	_set_bone_offset("Body", Vector3(breathe, 0.0, 0.0))

func _update_head(delta: float) -> void:
	if not _bones.has("Head"):
		return
	var head_global := _skeleton.get_bone_global_pose(_bones["Head"])
	var head_world := _skeleton.global_transform * head_global
	var local_target := head_world.affine_inverse() * _look_target
	var yaw := clampf(atan2(local_target.x, maxf(0.01, local_target.z)), -head_turn_limit, head_turn_limit)
	var pitch := clampf(-atan2(local_target.y, maxf(0.01, absf(local_target.z))), -head_pitch_limit, head_pitch_limit)
	if debug_rig_motion:
		yaw += sin(_time * 0.8) * 0.06
	var target_offset := Quaternion.from_euler(Vector3(pitch, yaw, 0.0))
	var rest: Quaternion = _rest_rotations.get("Head", Quaternion.IDENTITY)
	var desired := rest * target_offset
	var current := _skeleton.get_bone_pose_rotation(_bones["Head"])
	_skeleton.set_bone_pose_rotation(_bones["Head"], current.slerp(desired, clampf(delta * look_smoothing, 0.0, 1.0)))

func _update_ears() -> void:
	var twitch := sin(_time * 2.1) * (0.10 if debug_rig_motion else 0.045)
	var hit := _touch_impulse * (0.55 if debug_rig_motion else 0.18)
	_set_bone_offset("Ear_L", Vector3(0.0, 0.0, twitch - hit))
	_set_bone_offset("Ear_R", Vector3(0.0, 0.0, -twitch + hit))

func _update_tail() -> void:
	var idle_scale := 1.55 if debug_rig_motion else 1.0
	var hit_scale := 3.2 if debug_rig_motion else 1.7
	var energy := idle_scale + _touch_impulse * hit_scale
	_set_bone_offset("Tail_01", Vector3(0.0, sin(_time * 1.3) * 0.12 * energy, sin(_time * 1.3) * 0.12 * energy))
	_set_bone_offset("Tail_02", Vector3(0.0, sin(_time * 1.3 - 0.4) * 0.16 * energy, sin(_time * 1.3 - 0.4) * 0.18 * energy))
	_set_bone_offset("Tail_03", Vector3(0.0, sin(_time * 1.3 - 0.8) * 0.20 * energy, sin(_time * 1.3 - 0.8) * 0.24 * energy))
	_set_bone_offset("Tail_04", Vector3(0.0, sin(_time * 1.3 - 1.2) * 0.24 * energy, sin(_time * 1.3 - 1.2) * 0.30 * energy))

func _update_legs() -> void:
	var amount := 0.035 if debug_rig_motion else 0.018
	var settle := sin(_time * 2.0) * amount
	_set_bone_offset("Leg_FL", Vector3(settle, 0.0, 0.0))
	_set_bone_offset("Leg_FR", Vector3(-settle * 0.6, 0.0, 0.0))
	_set_bone_offset("Leg_BL", Vector3(-settle * 0.4, 0.0, 0.0))
	_set_bone_offset("Leg_BR", Vector3(settle * 0.5, 0.0, 0.0))

func _set_bone_offset(bone_name: String, euler: Vector3) -> void:
	if not _bones.has(bone_name):
		return
	var rest: Quaternion = _rest_rotations.get(bone_name, Quaternion.IDENTITY)
	_skeleton.set_bone_pose_rotation(_bones[bone_name], rest * Quaternion.from_euler(euler))

func _apply_debug_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.16, 0.10, 0.28, 1.0)
		material.roughness = 0.78
		material.metallic = 0.0
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
