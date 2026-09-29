class_name GeneDefinition
extends RefCounted


var _id: StringName = &""
var _display_name: String = ""
var _locus: StringName = &""
var _direction: StringName = &""
var _primary_influence: float = 0.0
var _influence_tags: Dictionary = {}
var _rarity: String = "uncommon"


func _init(
	id: StringName = &"",
	display_name: String = "",
	locus: StringName = &"",
	direction: StringName = &"",
	primary_influence: float = 0.0,
	influence_tags: Dictionary = {},
	rarity: String = "uncommon"
) -> void:
	_id = _normalize_token(id)
	_display_name = display_name.strip_edges()
	_locus = _normalize_token(locus)
	_direction = _normalize_token(direction)
	_primary_influence = primary_influence
	_influence_tags = _normalize_tags(
		influence_tags
	)
	_rarity = rarity.strip_edges().to_lower()


func id() -> StringName:
	return _id


func display_name() -> String:
	return _display_name


func locus() -> StringName:
	return _locus


func direction() -> StringName:
	return _direction


func primary_influence() -> float:
	return _primary_influence


func influence_tags() -> Dictionary:
	return _influence_tags.duplicate(
		true
	)


func rarity() -> String:
	return _rarity


func is_valid() -> bool:
	if (
		String(_id).is_empty()
		or _display_name.is_empty()
		or not PetGenomeSchema.is_visual_locus(
			_locus
		)
		or String(_direction).is_empty()
		or _direction
			== PetGenomeSchema.BASE_TRAIT
		or _primary_influence <= 0.0
		or _rarity.is_empty()
	):
		return false

	for key_value in _influence_tags.keys():
		var key := String(
			key_value
		).strip_edges()

		if (
			key.is_empty()
			or float(
				_influence_tags[key_value]
			) <= 0.0
		):
			return false

	return true


func to_dict() -> Dictionary:
	return {
		"id": String(_id),
		"display_name": _display_name,
		"locus": String(_locus),
		"direction": String(
			_direction
		),
		"primary_influence": (
			_primary_influence
		),
		"influence_tags": (
			influence_tags()
		),
		"rarity": _rarity,
	}


static func from_dict(
	data: Dictionary
) -> GeneDefinition:
	var tags_value: Variant = data.get(
		"influence_tags",
		{}
	)

	if typeof(tags_value) != TYPE_DICTIONARY:
		return null

	var definition := GeneDefinition.new(
		StringName(
			str(
				data.get(
					"id",
					""
				)
			)
		),
		String(
			data.get(
				"display_name",
				""
			)
		),
		StringName(
			str(
				data.get(
					"locus",
					""
				)
			)
		),
		StringName(
			str(
				data.get(
					"direction",
					""
				)
			)
		),
		float(
			data.get(
				"primary_influence",
				0.0
			)
		),
		tags_value as Dictionary,
		String(
			data.get(
				"rarity",
				"uncommon"
			)
		)
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


static func _normalize_tags(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		var key := String(
			key_value
		).strip_edges().to_lower().replace(
			" ",
			"_"
		)

		if key.is_empty():
			continue

		result[key] = float(
			source[key_value]
		)

	return result
