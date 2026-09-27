class_name DarkPetRiggedActor
extends Node3D

signal tapped

@export var skeleton_path: NodePath = NodePath("DarkPetModel/DarkPetSkeleton/Skeleton3D")
@export var head_turn_limit: float = 0.16
@export var head_pitch_limit: float = 0.08
@export var look_smoothing: float = 4.0

@onready var model_root: Node3D = $DarkPetModel

var _skeleton: Skeleton3D
var _look_target := Vector3(0.0, 1.2, 4.0)
var _time := 0.0
var _touch_impulse := 0.0
var _bones: Dictionary = {}

func _ready() -> void:
	_skeleton = get_node_or_null(skeleton_path) as Skeleton3D
	if _skeleton == null:
		_skeleton = _find_skeleton(model_root)
	if _skeleton == null:
		push_error("DarkPetRiggedActor: Skeleton3D not found in imported GLB")
		return
	_cache_bones()

func _process(delta: float) -> void:
	if _skeleton == null:
		return
	_time += delta
	_touch_impulse = move_toward(_touch_impulse, 0.0, delta * 2.4)
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
		else:
			push_warning("Dark Pet bone missing: %s" % bone_name)

func _update_body() -> void:
	var breathe := sin(_time * 2.0) * 0.018
	_set_bone_rotation("Body", Vector3(breathe, 0.0, 0.0))

func _update_head(delta: float) -> void:
	if not _bones.has("Head"):
		return
	var head_global := _skeleton.get_bone_global_pose(_bones["Head"])
	var head_world := _skeleton.global_transform * head_global
	var local_target := head_world.affine_inverse() * _look_target
	var yaw := clampf(atan2(local_target.x, maxf(0.01, local_target.z)), -head_turn_limit, head_turn_limit)
	var pitch := clampf(-atan2(local_target.y, maxf(0.01, absf(local_target.z))), -head_pitch_limit, head_pitch_limit)
	var current := _skeleton.get_bone_pose_rotation(_bones["Head"])
	var desired := Quaternion.from_euler(Vector3(pitch, yaw, 0.0))
	_skeleton.set_bone_pose_rotation(_bones["Head"], current.slerp(desired, clampf(delta * look_smoothing, 0.0, 1.0)))

func _update_ears() -> void:
	var twitch := sin(_time * 1.7) * 0.045
	_set_bone_rotation("Ear_L", Vector3(0.0, 0.0, twitch - _touch_impulse * 0.18))
	_set_bone_rotation("Ear_R", Vector3(0.0, 0.0, -twitch + _touch_impulse * 0.18))

func _update_tail() -> void:
	var energy := 1.0 + _touch_impulse * 1.7
	_set_bone_rotation("Tail_01", Vector3(0.0, sin(_time * 1.15) * 0.12 * energy, sin(_time * 1.15) * 0.12 * energy))
	_set_bone_rotation("Tail_02", Vector3(0.0, sin(_time * 1.15 - 0.4) * 0.16 * energy, sin(_time * 1.15 - 0.4) * 0.18 * energy))
	_set_bone_rotation("Tail_03", Vector3(0.0, sin(_time * 1.15 - 0.8) * 0.20 * energy, sin(_time * 1.15 - 0.8) * 0.24 * energy))
	_set_bone_rotation("Tail_04", Vector3(0.0, sin(_time * 1.15 - 1.2) * 0.24 * energy, sin(_time * 1.15 - 1.2) * 0.30 * energy))

func _update_legs() -> void:
	var settle := sin(_time * 2.0) * 0.018
	_set_bone_rotation("Leg_FL", Vector3(settle, 0.0, 0.0))
	_set_bone_rotation("Leg_FR", Vector3(-settle * 0.6, 0.0, 0.0))
	_set_bone_rotation("Leg_BL", Vector3(-settle * 0.4, 0.0, 0.0))
	_set_bone_rotation("Leg_BR", Vector3(settle * 0.5, 0.0, 0.0))

func _set_bone_rotation(bone_name: String, euler: Vector3) -> void:
	if not _bones.has(bone_name):
		return
	_skeleton.set_bone_pose_rotation(_bones[bone_name], Quaternion.from_euler(euler))

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
