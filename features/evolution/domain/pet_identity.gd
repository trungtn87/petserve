class_name PetIdentity
extends RefCounted


const SCHEMA_VERSION: int = 1


var _pet_id: String = ""
var _species: StringName = &""
var _element: StringName = &""
var _lineage_seed: int = 0
var _generation: int = 0


func _init(
	pet_id: String = "",
	species: StringName = &"",
	element: StringName = &"",
	lineage_seed: int = 0,
	generation: int = 0
) -> void:
	_pet_id = pet_id
	_species = species
	_element = element
	_lineage_seed = lineage_seed
	_generation = generation


func pet_id() -> String:
	return _pet_id


func species() -> StringName:
	return _species


func element() -> StringName:
	return _element


func lineage_seed() -> int:
	return _lineage_seed


func generation() -> int:
	return _generation


func is_valid() -> bool:
	return (
		not _pet_id.is_empty()
		and not String(_species).is_empty()
		and not String(_element).is_empty()
		and _lineage_seed > 0
		and _generation >= 0
	)


func same_identity(
	other: PetIdentity
) -> bool:
	if other == null:
		return false

	return (
		_pet_id == other._pet_id
		and _species == other._species
		and _element == other._element
		and _lineage_seed == other._lineage_seed
		and _generation == other._generation
	)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"pet_id": _pet_id,
		"species": String(_species),
		"element": String(_element),
		"lineage_seed": _lineage_seed,
		"generation": _generation,
	}


static func from_dict(
	data: Dictionary
) -> PetIdentity:
	var identity := PetIdentity.new(
		str(data.get("pet_id", "")),
		StringName(str(data.get("species", ""))),
		StringName(str(data.get("element", ""))),
		int(data.get("lineage_seed", 0)),
		int(data.get("generation", 0))
	)

	if not identity.is_valid():
		return null

	return identity
