class_name MutationDefinition
extends RefCounted


var _id: StringName = &""
var _target_trait: StringName = &""
var _result_trait: StringName = &""
var _required_trait: StringName = &"base"

var _min_stage: int = 1
var _max_stage: int = 0
var _weight: int = 1

var _allowed_species: Array[StringName] = []
var _allowed_elements: Array[StringName] = []
var _conflicts: Array[StringName] = []


func _init(
	id: StringName = &"",
	target_trait: StringName = &"",
	result_trait: StringName = &"",
	required_trait: StringName = &"base",
	min_stage: int = 1,
	max_stage: int = 0,
	weight: int = 1,
	allowed_species: Array = [],
	allowed_elements: Array = [],
	conflicts: Array = []
) -> void:
	_id = _normalize_token(id)
	_target_trait = _normalize_token(target_trait)
	_result_trait = _normalize_token(result_trait)
	_required_trait = _normalize_token(required_trait)

	_min_stage = min_stage
	_max_stage = max_stage
	_weight = weight

	_allowed_species = _normalize_list(allowed_species)
	_allowed_elements = _normalize_list(allowed_elements)
	_conflicts = _normalize_list(conflicts)


func id() -> StringName:
	return _id


func target_trait() -> StringName:
	return _target_trait


func result_trait() -> StringName:
	return _result_trait


func required_trait() -> StringName:
	return _required_trait


func min_stage() -> int:
	return _min_stage


func max_stage() -> int:
	return _max_stage


func weight() -> int:
	return _weight


func is_valid() -> bool:
	if (
		String(_id).is_empty()
		or String(_target_trait).is_empty()
		or String(_result_trait).is_empty()
		or String(_required_trait).is_empty()
	):
		return false

	if _min_stage < 1:
		return false

	if (
		_max_stage != 0
		and _max_stage < _min_stage
	):
		return false

	if _weight <= 0:
		return false

	if _result_trait == _required_trait:
		return false

	return true


func is_compatible(
	identity: PetIdentity,
	genome: PetGenome
) -> bool:
	if (
		identity == null
		or genome == null
		or not is_valid()
		or not identity.is_valid()
		or not genome.is_valid()
	):
		return false

	if genome.has_mutation(_id):
		return false

	if genome.stage() < _min_stage:
		return false

	if (
		_max_stage > 0
		and genome.stage() > _max_stage
	):
		return false

	if (
		not _allowed_species.is_empty()
		and not _allowed_species.has(
			identity.species()
		)
	):
		return false

	if (
		not _allowed_elements.is_empty()
		and not _allowed_elements.has(
			identity.element()
		)
	):
		return false

	for conflict_id in _conflicts:
		if genome.has_mutation(conflict_id):
			return false

	var current_trait := genome.get_trait(
		_target_trait,
		&"base"
	)

	return current_trait == _required_trait


func to_dict() -> Dictionary:
	return {
		"id": String(_id),
		"target_trait": String(_target_trait),
		"result_trait": String(_result_trait),
		"required_trait": String(_required_trait),
		"min_stage": _min_stage,
		"max_stage": _max_stage,
		"weight": _weight,
		"allowed_species": _string_list(
			_allowed_species
		),
		"allowed_elements": _string_list(
			_allowed_elements
		),
		"conflicts": _string_list(
			_conflicts
		),
	}


static func from_dict(
	data: Dictionary
) -> MutationDefinition:
	var definition := MutationDefinition.new(
		StringName(str(data.get("id", ""))),
		StringName(str(data.get("target_trait", ""))),
		StringName(str(data.get("result_trait", ""))),
		StringName(str(data.get(
			"required_trait",
			"base"
		))),
		int(data.get("min_stage", 1)),
		int(data.get("max_stage", 0)),
		int(data.get("weight", 1)),
		_array_value(
			data.get("allowed_species", [])
		),
		_array_value(
			data.get("allowed_elements", [])
		),
		_array_value(
			data.get("conflicts", [])
		)
	)

	if not definition.is_valid():
		return null

	return definition


static func _array_value(
	value: Variant
) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []

	return value as Array


static func _normalize_token(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)


static func _normalize_list(
	source: Array
) -> Array[StringName]:
	var result: Array[StringName] = []

	for value in source:
		var token := _normalize_token(
			StringName(str(value))
		)

		if (
			not String(token).is_empty()
			and not result.has(token)
		):
			result.append(token)

	return result


static func _string_list(
	source: Array[StringName]
) -> Array[String]:
	var result: Array[String] = []

	for value in source:
		result.append(String(value))

	return result
