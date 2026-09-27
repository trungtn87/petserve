class_name HomeHost
extends RefCounted


var _environment_instance: Node = null


func apply(
	definition: HomeDefinition,
	environment_slot: Node,
	pet_anchor: Marker2D
) -> bool:
	if definition == null or not definition.is_valid():
		return false

	if environment_slot == null or pet_anchor == null:
		return false

	_clear_environment()

	_environment_instance = definition.environment_scene.instantiate()
	environment_slot.add_child(_environment_instance)
	pet_anchor.position = definition.pet_anchor

	return true


func clear() -> void:
	_clear_environment()


func _clear_environment() -> void:
	if _environment_instance == null:
		return

	if is_instance_valid(_environment_instance):
		_environment_instance.queue_free()

	_environment_instance = null
