class_name PetFacade
extends RefCounted


const EVENT_NONE: String = "none"
const EVENT_STATE_CHANGED: String = "state_changed"


var _state: PetState
var _started: bool = false


func _init() -> void:
	_state = PetState.new()


func start() -> void:
	if _started:
		return

	_state.reset()
	_started = true


func is_started() -> bool:
	return _started


func get_primary_state() -> StringName:
	return _state.primary


func set_primary_state(next_state: StringName) -> String:
	if not _started:
		return EVENT_NONE

	if _state.is_state(next_state):
		return EVENT_NONE

	_state.set_primary(next_state)
	return EVENT_STATE_CHANGED


func reset() -> void:
	_state.reset()
