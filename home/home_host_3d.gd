class_name HomeHost3D
extends RefCounted


var _environment_instance: Node3D = null


func apply(
	definition: HomeDefinition3D,
	environment_slot: Node3D,
	pet_anchor: Node3D,
	camera: Camera3D
) -> bool:
	if definition == null or not definition.is_valid():
		return false

	if environment_slot == null or pet_anchor == null or camera == null:
		return false

	_clear_environment()

	var instance: Node = definition.environment_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		push_error("HomeDefinition3D environment_scene root must extend Node3D.")
		return false

	_environment_instance = instance as Node3D
	environment_slot.add_child(_environment_instance)

	pet_anchor.position = definition.pet_position
	pet_anchor.rotation_degrees = definition.pet_rotation_degrees
	pet_anchor.scale = definition.pet_scale

	camera.position = definition.camera_position
	camera.rotation_degrees = definition.camera_rotation_degrees
	camera.fov = definition.camera_fov
	camera.current = true

	return true


func clear() -> void:
	_clear_environment()


func _clear_environment() -> void:
	if _environment_instance == null:
		return

	if is_instance_valid(_environment_instance):
		_environment_instance.queue_free()

	_environment_instance = null
