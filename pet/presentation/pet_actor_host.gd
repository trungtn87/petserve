class_name PetActorHost
extends RefCounted


var _actor: PetActor = null


func spawn(definition: PetDefinition, parent: Node) -> PetActor:
	if definition == null or not definition.is_valid() or parent == null:
		return null

	clear()

	var instance: Node = definition.actor_scene.instantiate()
	if not instance is PetActor:
		instance.queue_free()
		push_error("PetDefinition actor_scene root must extend PetActor.")
		return null

	_actor = instance as PetActor
	parent.add_child(_actor)
	_actor.setup(definition)
	return _actor


func get_actor() -> PetActor:
	return _actor


func clear() -> void:
	if _actor == null:
		return

	if is_instance_valid(_actor):
		_actor.queue_free()

	_actor = null
