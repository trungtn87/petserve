class_name PetActor3D
extends Node3D

signal tapped

var _definition: PetDefinition = null
var _presented_state: StringName = &""

func setup(definition: PetDefinition) -> void:
	_definition = definition
	_on_definition_applied(definition)

func present_state(state: PetState) -> void:
	if state == null or state.primary == _presented_state:
		return
	_presented_state = state.primary
	_on_state_presented(state.primary)

func notify_tapped() -> void:
	tapped.emit()

func _on_definition_applied(_definition: PetDefinition) -> void:
	pass

func _on_state_presented(_state_id: StringName) -> void:
	pass
