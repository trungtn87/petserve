class_name PetVisualSpec
extends RefCounted


var _pet_id: String = ""
var _style_id: StringName = &""
var _mutation_id: StringName = &""
var _target_region: StringName = &""

var _edit_strength: float = 0.0

var _identity_prompt: String = ""
var _style_prompt: String = ""
var _state_prompt: String = ""
var _change_prompt: String = ""
var _preserve_prompt: String = ""
var _negative_prompt: String = ""


func _init(
	pet_id: String = "",
	style_id: StringName = &"",
	mutation_id: StringName = &"",
	target_region: StringName = &"",
	edit_strength: float = 0.0,
	identity_prompt: String = "",
	style_prompt: String = "",
	state_prompt: String = "",
	change_prompt: String = "",
	preserve_prompt: String = "",
	negative_prompt: String = ""
) -> void:
	_pet_id = pet_id
	_style_id = style_id
	_mutation_id = mutation_id
	_target_region = target_region
	_edit_strength = edit_strength
	_identity_prompt = identity_prompt
	_style_prompt = style_prompt
	_state_prompt = state_prompt
	_change_prompt = change_prompt
	_preserve_prompt = preserve_prompt
	_negative_prompt = negative_prompt


func pet_id() -> String:
	return _pet_id


func style_id() -> StringName:
	return _style_id


func mutation_id() -> StringName:
	return _mutation_id


func target_region() -> StringName:
	return _target_region


func edit_strength() -> float:
	return _edit_strength


func identity_prompt() -> String:
	return _identity_prompt


func style_prompt() -> String:
	return _style_prompt


func state_prompt() -> String:
	return _state_prompt


func change_prompt() -> String:
	return _change_prompt


func preserve_prompt() -> String:
	return _preserve_prompt


func negative_prompt() -> String:
	return _negative_prompt


func is_valid() -> bool:
	return (
		not _pet_id.is_empty()
		and not String(_style_id).is_empty()
		and not String(_mutation_id).is_empty()
		and not String(_target_region).is_empty()
		and _edit_strength > 0.0
		and _edit_strength <= 1.0
		and not _identity_prompt.is_empty()
		and not _style_prompt.is_empty()
		and not _change_prompt.is_empty()
		and not _preserve_prompt.is_empty()
		and not _negative_prompt.is_empty()
	)


func to_dict() -> Dictionary:
	return {
		"pet_id": _pet_id,
		"style_id": String(_style_id),
		"mutation_id": String(_mutation_id),
		"target_region": String(_target_region),
		"edit_strength": _edit_strength,
		"identity_prompt": _identity_prompt,
		"style_prompt": _style_prompt,
		"state_prompt": _state_prompt,
		"change_prompt": _change_prompt,
		"preserve_prompt": _preserve_prompt,
		"negative_prompt": _negative_prompt,
	}
