class_name PetActor3DHost
extends RefCounted


var _actor: PetActor3D = null


func spawn(definition: PetDefinition, parent: Node3D) -> PetActor3D:
	if definition == null or not definition.is_valid() or parent == null:
		return null

	clear()

	var instance: Node = definition.actor_scene.instantiate()
	if not instance is PetActor3D:
		instance.queue_free()
		push_error("PetDefinition actor_scene root must extend PetActor3D for a 3D home.")
		return null

	_actor = instance as PetActor3D
	parent.add_child(_actor)
	_actor.setup(definition)

	return _actor


func get_actor() -> PetActor3D:
	return _actor


func clear() -> void:
	if _actor == null:
		return

	if is_instance_valid(_actor):
		_actor.queue_free()

	_actor = null
