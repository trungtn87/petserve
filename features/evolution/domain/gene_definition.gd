class_name GeneDefinition
extends RefCounted

var _id: StringName = &""
var _display_name: String = ""
var _locus: StringName = &""
var _direction: StringName = &""
var _primary_influence: float = 0.0
var _influence_tags: Dictionary = {}
var _rarity: String = "variable"
var _expression_chain: Array[StringName] = []
var _element_lock: StringName = &""
var _prompt_stem: String = ""
var _preserve_hint: String = ""

func _init(
	id: StringName = &"",
	display_name: String = "",
	locus: StringName = &"",
	direction: StringName = &"",
	primary_influence: float = 0.0,
	influence_tags: Dictionary = {},
	rarity: String = "variable",
	expression_chain: Array = [],
	element_lock: StringName = &"",
	prompt_stem: String = "",
	preserve_hint: String = ""
) -> void:
	_id = _normalize_token(id)
	_display_name = display_name.strip_edges()
	_locus = _normalize_token(locus)
	_direction = _normalize_token(direction)
	_primary_influence = primary_influence
	_influence_tags = _normalize_tags(influence_tags)
	_rarity = rarity.strip_edges().to_lower()
	_expression_chain = _normalize_chain(expression_chain, _direction)
	_element_lock = _normalize_token(element_lock)
	_prompt_stem = prompt_stem.strip_edges()
	_preserve_hint = preserve_hint.strip_edges()

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
	return _influence_tags.duplicate(true)

func rarity() -> String:
	return _rarity

func expression_chain() -> Array[StringName]:
	return _expression_chain.duplicate()

func element_lock() -> StringName:
	return _element_lock

func prompt_stem() -> String:
	return _prompt_stem

func preserve_hint() -> String:
	return _preserve_hint

func is_element_compatible(element: StringName) -> bool:
	var normalized := _normalize_token(element)
	return String(_element_lock).is_empty() or _element_lock == normalized

func next_expression(current_trait: StringName) -> StringName:
	var current := _normalize_token(current_trait)
	if current == PetGenomeSchema.BASE_TRAIT:
		return _direction
	var index := _expression_chain.find(current)
	if index < 0:
		return _direction
	if index + 1 >= _expression_chain.size():
		return &""
	return _expression_chain[index + 1]

func reinforces(current_trait: StringName) -> bool:
	var current := _normalize_token(current_trait)
	return current != PetGenomeSchema.BASE_TRAIT and _expression_chain.has(current)

func is_valid() -> bool:
	if (
		String(_id).is_empty()
		or _display_name.is_empty()
		or not PetGenomeSchema.is_gene_locus(_locus)
		or String(_direction).is_empty()
		or _direction == PetGenomeSchema.BASE_TRAIT
		or _primary_influence <= 0.0
		or _rarity.is_empty()
		or _expression_chain.is_empty()
		or _expression_chain[0] != _direction
		or _prompt_stem.is_empty()
	):
		return false
	if _locus in [&"mark", &"aura"] and String(_element_lock).is_empty():
		return false
	if _locus not in [&"mark", &"aura"] and not String(_element_lock).is_empty():
		return false
	var seen: Dictionary = {}
	for trait_id in _expression_chain:
		if String(trait_id).is_empty() or trait_id == PetGenomeSchema.BASE_TRAIT or seen.has(trait_id):
			return false
		seen[trait_id] = true
	for key_value in _influence_tags.keys():
		var key := String(key_value).strip_edges()
		if key.is_empty() or float(_influence_tags[key_value]) <= 0.0:
			return false
	return true

func to_dict() -> Dictionary:
	var chain: Array[String] = []
	for trait_id in _expression_chain:
		chain.append(String(trait_id))
	return {
		"id": String(_id),
		"display_name": _display_name,
		"locus": String(_locus),
		"direction": String(_direction),
		"primary_influence": _primary_influence,
		"influence_tags": influence_tags(),
		"rarity": _rarity,
		"expression_chain": chain,
		"element_lock": String(_element_lock),
		"prompt_stem": _prompt_stem,
		"preserve_hint": _preserve_hint,
	}

static func from_dict(data: Dictionary) -> GeneDefinition:
	var tags_value: Variant = data.get("influence_tags", {})
	var chain_value: Variant = data.get("expression_chain", [])
	if typeof(tags_value) != TYPE_DICTIONARY or typeof(chain_value) != TYPE_ARRAY:
		return null
	var definition := GeneDefinition.new(
		StringName(str(data.get("id", ""))),
		String(data.get("display_name", "")),
		StringName(str(data.get("locus", ""))),
		StringName(str(data.get("direction", ""))),
		float(data.get("primary_influence", 0.0)),
		tags_value as Dictionary,
		String(data.get("rarity", "variable")),
		chain_value as Array,
		StringName(str(data.get("element_lock", ""))),
		String(data.get("prompt_stem", "")),
		String(data.get("preserve_hint", ""))
	)
	return definition if definition.is_valid() else null

static func _normalize_token(value: StringName) -> StringName:
	return StringName(String(value).strip_edges().to_lower().replace(" ", "_"))

static func _normalize_tags(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		var key := String(key_value).strip_edges().to_lower().replace(" ", "_")
		if not key.is_empty():
			result[key] = float(source[key_value])
	return result

static func _normalize_chain(source: Array, direction: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for value in source:
		var trait_id := _normalize_token(StringName(str(value)))
		if String(trait_id).is_empty() or trait_id == PetGenomeSchema.BASE_TRAIT or result.has(trait_id):
			continue
		result.append(trait_id)
	if result.is_empty():
		result.append(direction)
	elif result[0] != direction:
		result.push_front(direction)
	return result
