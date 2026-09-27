class_name HomeDefinition3D
extends Resource


@export var id: StringName = &""
@export var environment_scene: PackedScene

@export_group("Pet")
@export var pet_position: Vector3 = Vector3.ZERO
@export var pet_rotation_degrees: Vector3 = Vector3.ZERO
@export var pet_scale: Vector3 = Vector3.ONE

@export_group("Camera")
@export var camera_position: Vector3 = Vector3(0.0, 1.18, 5.8)
@export var camera_rotation_degrees: Vector3 = Vector3.ZERO
@export_range(10.0, 90.0, 0.5) var camera_fov: float = 34.0

@export_group("Audio")
@export var ambient_audio: AudioStream


func is_valid() -> bool:
	return not id.is_empty() and environment_scene != null
