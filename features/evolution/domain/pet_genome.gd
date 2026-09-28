class_name PetGenome
extends RefCounted


const SCHEMA_VERSION: int = 1


var _stage: int = 1
var _body_growth: float = 0.0

var _traits: Dictionary = {}
var _mutations: Array[StringName] = []


func _init(
	stage: int = 1,
	body_growth: float = 0.0,
	traits: Dictionary = {},
	mutations: Array = []
) -> void:
	_stage = stage
	_body_growth = body_growth
	_traits = _normalize_traits(traits)
	_mutations = _normalize_mutations(mutations)


func stage() -> int:
	return _stage


func body_growth() -> float:
	return _body_growth


func trait(
	trait_id: StringName,
	fallback: StringName = &"base"
) -> StringName:
	if not _traits.has(trait_id):
		return fallback

	return StringName(
		str(_traits[trait_id])
	)


func has_trait(
	trait_id: StringName
) -> bool:
	return _traits.has(trait_id)


func traits_snapshot() -> Dictionary:
	return _traits.duplicate(true)


func mutation_ids() -> Array[StringName]:
	return _mutations.duplicate()


func has_mutation(
	mutation_id: StringName
) -> bool:
	return _mutations.has(mutation_id)


func is_valid() -> bool:
	if _stage < 1:
		return false

	if (
		_body_growth < 0.0
		or _body_growth > 1.0
	):
		return false

	for key_value in _traits.keys():
		var key := StringName(str(key_value))
		var value := StringName(
			str(_traits[key_value])
		)

		if (
			String(key).is_empty()
			or String(value).is_empty()
		):
			return false

	var seen: Dictionary = {}

	for mutation_id in _mutations:
		var mutation_text := String(
			mutation_id
		)

		if mutation_text.is_empty():
			return false

		if seen.has(mutation_id):
			return false

		seen[mutation_id] = true

	return true


func same_genome(
	other: PetGenome
) -> bool:
	if other == null:
		return false

	return (
		_stage == other._stage
		and is_equal_approx(
			_body_growth,
			other._body_growth
		)
		and _traits == other._traits
		and _mutations == other._mutations
	)


func to_dict() -> Dictionary:
	var serialized_traits: Dictionary = {}

	for key_value in _traits.keys():
		var key := StringName(str(key_value))

		serialized_traits[String(key)] = String(
			_trait_value(key)
		)

	var serialized_mutations: Array[String] = []

	for mutation_id in _mutations:
		serialized_mutations.append(
			String(mutation_id)
		)

	return {
		"schema": SCHEMA_VERSION,
		"stage": _stage,
		"body_growth": _body_growth,
		"traits": serialized_traits,
		"mutations": serialized_mutations,
	}


static func from_dict(
	data: Dictionary
) -> PetGenome:
	var traits_value: Variant = data.get(
		"traits",
		{}
	)

	if typeof(traits_value) != TYPE_DICTIONARY:
		return null

	var mutations_value: Variant = data.get(
		"mutations",
		[]
	)

	if typeof(mutations_value) != TYPE_ARRAY:
		return null

	var genome := PetGenome.new(
		int(data.get("stage", 1)),
		float(data.get("body_growth", 0.0)),
		(traits_value as Dictionary),
		(mutations_value as Array)
	)

	if not genome.is_valid():
		return null

	return genome


func _trait_value(
	trait_id: StringName
) -> StringName:
	return StringName(
		str(_traits.get(trait_id, ""))
	)


func _normalize_traits(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		var key := StringName(
			str(key_value).strip_edges().to_lower()
		)

		var value := StringName(
			str(source[key_value])
			.strip_edges()
			.to_lower()
		)

		result[key] = value

	return result


func _normalize_mutations(
	source: Array
) -> Array[StringName]:
	var result: Array[StringName] = []

	for value in source:
		result.append(
			StringName(
				str(value)
				.strip_edges()
				.to_lower()
			)
		)

	return result
