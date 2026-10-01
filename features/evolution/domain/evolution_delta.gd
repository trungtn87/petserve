class_name EvolutionDelta
extends RefCounted


var _mutation_id: StringName = &""
var _target_trait: StringName = &""
var _from_trait: StringName = &""
var _to_trait: StringName = &""
var _step_index: int = 0


func _init(
	mutation_id: StringName = &"",
	target_trait: StringName = &"",
	from_trait: StringName = &"",
	to_trait: StringName = &"",
	step_index: int = 0
) -> void:
	_mutation_id = mutation_id
	_target_trait = target_trait
	_from_trait = from_trait
	_to_trait = to_trait
	_step_index = step_index


func mutation_id() -> StringName:
	return _mutation_id


func target_trait() -> StringName:
	return _target_trait


func from_trait() -> StringName:
	return _from_trait


func to_trait() -> StringName:
	return _to_trait


func step_index() -> int:
	return _step_index


func is_valid() -> bool:
	return (
		not String(_mutation_id).is_empty()
		and not String(_target_trait).is_empty()
		and not String(_from_trait).is_empty()
		and not String(_to_trait).is_empty()
		and _from_trait != _to_trait
		and _step_index >= 1
	)


func to_dict() -> Dictionary:
	return {
		"mutation_id": String(_mutation_id),
		"target_trait": String(_target_trait),
		"from_trait": String(_from_trait),
		"to_trait": String(_to_trait),
		"step_index": _step_index,
	}
