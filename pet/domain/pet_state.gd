class_name PetState
extends RefCounted


const STATE_NEUTRAL: StringName = &"neutral"
const STATE_HAPPY: StringName = &"happy"
const STATE_CURIOUS: StringName = &"curious"
const STATE_SURPRISED: StringName = &"surprised"
const STATE_SLEEPY: StringName = &"sleepy"


var primary: StringName = STATE_NEUTRAL


func reset() -> void:
	primary = STATE_NEUTRAL


func set_primary(next_state: StringName) -> void:
	primary = next_state


func is_state(value: StringName) -> bool:
	return primary == value
