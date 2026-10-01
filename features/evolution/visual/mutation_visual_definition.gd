class_name MutationVisualDefinition
extends RefCounted


var _mutation_id: StringName = &""
var _target_region: StringName = &""
var _instruction: String = ""
var _preserve_hint: String = ""
var _edit_strength: float = 0.0


func _init(
	mutation_id: StringName = &"",
	target_region: StringName = &"",
	instruction: String = "",
	preserve_hint: String = "",
	edit_strength: float = 0.0
) -> void:
	_mutation_id = _normalize_token(
		mutation_id
	)
	_target_region = _normalize_token(
		target_region
	)
	_instruction = instruction.strip_edges()
	_preserve_hint = preserve_hint.strip_edges()
	_edit_strength = edit_strength


func mutation_id() -> StringName:
	return _mutation_id


func target_region() -> StringName:
	return _target_region


func instruction() -> String:
	return _instruction


func preserve_hint() -> String:
	return _preserve_hint


func edit_strength() -> float:
	return _edit_strength


func is_valid() -> bool:
	return (
		not String(_mutation_id).is_empty()
		and not String(_target_region).is_empty()
		and not _instruction.is_empty()
		and not _preserve_hint.is_empty()
		and _edit_strength > 0.0
		and _edit_strength <= 1.0
	)


static func from_dict(
	data: Dictionary
) -> MutationVisualDefinition:
	var definition := MutationVisualDefinition.new(
		StringName(str(data.get(
			"mutation_id",
			""
		))),
		StringName(str(data.get(
			"target_region",
			""
		))),
		str(data.get("instruction", "")),
		str(data.get("preserve_hint", "")),
		float(data.get("edit_strength", 0.0))
	)

	if not definition.is_valid():
		return null

	return definition


static func _normalize_token(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)
