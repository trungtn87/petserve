class_name PetActor
extends Node2D


var _definition: PetDefinition = null


func setup(definition: PetDefinition) -> void:
	_definition = definition
	_on_definition_applied(definition)


func get_definition() -> PetDefinition:
	return _definition


func has_capability(capability_id: StringName) -> bool:
	return _definition != null and _definition.has_capability(capability_id)


func present_state(_state: PetState) -> void:
	pass


func _on_definition_applied(_definition: PetDefinition) -> void:
	pass
