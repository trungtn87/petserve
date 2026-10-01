class_name SpeciesMythicMutationDefinition
extends RefCounted


const MIN_STAGE: int = 2
const FINAL_STAGE: int = 5
const MAX_BASIS_POINTS: int = 10000


var _id: StringName = &""
var _display_name: String = ""
var _species: StringName = &""
var _first_expression_stage: int = 3
var _final_expression_stage: int = 4
var _activation_basis_points: int = 0
var _egg_stage4_eligible: bool = false
var _required_loci: Array[StringName] = []
var _target_regions: Array[StringName] = []
var _required_traits: Dictionary = {}
var _gene_tag_affinity: Dictionary = {}
var _stage_prompts: Dictionary = {}
var _preserve_hint: String = ""


func _init(
	id: StringName = &"",
	display_name: String = "",
	species: StringName = &"",
	first_expression_stage: int = 3,
	final_expression_stage: int = 4,
	activation_basis_points: int = 0,
	egg_stage4_eligible: bool = false,
	required_loci: Array = [],
	target_regions: Array = [],
	required_traits: Dictionary = {},
	gene_tag_affinity: Dictionary = {},
	stage_prompts: Dictionary = {},
	preserve_hint: String = ""
) -> void:
	_id = _normalize_token(id)
	_display_name = display_name.strip_edges()
	_species = _normalize_token(species)
	_first_expression_stage = first_expression_stage
	_final_expression_stage = final_expression_stage
	_activation_basis_points = activation_basis_points
	_egg_stage4_eligible = egg_stage4_eligible
	_required_loci = _normalize_loci(required_loci)
	_target_regions = _normalize_regions(target_regions)
	_required_traits = _normalize_traits(required_traits)
	_gene_tag_affinity = _normalize_affinity(gene_tag_affinity)
	_stage_prompts = _normalize_prompts(stage_prompts)
	_preserve_hint = preserve_hint.strip_edges()


func id() -> StringName:
	return _id


func display_name() -> String:
	return _display_name


func species() -> StringName:
	return _species


func first_expression_stage() -> int:
	return _first_expression_stage


func final_expression_stage() -> int:
	return _final_expression_stage


func activation_basis_points() -> int:
	return _activation_basis_points


func is_activation_configured() -> bool:
	return _activation_basis_points > 0


func egg_stage4_eligible() -> bool:
	return _egg_stage4_eligible


func required_loci() -> Array[StringName]:
	return _required_loci.duplicate()


func recipe_matches(
	accumulated_loci: Array
) -> bool:
	if _required_loci.size() != 3:
		return false

	var normalized: Array[StringName] = []

	for value in accumulated_loci:
		var gene_id := _normalize_token(
			StringName(
				str(value)
			)
		)

		if (
			String(gene_id).is_empty()
			or normalized.has(
				gene_id
			)
		):
			continue

		normalized.append(
			gene_id
		)

	for required_id in _required_loci:
		if not normalized.has(
			required_id
		):
			return false

	return true


func target_regions() -> Array[StringName]:
	return _target_regions.duplicate()


func required_traits() -> Dictionary:
	return _required_traits.duplicate(true)


func gene_tag_affinity() -> Dictionary:
	return _gene_tag_affinity.duplicate(true)


func preserve_hint() -> String:
	return _preserve_hint


func prompt_for_stage(
	stage_index: int
) -> String:
	return String(
		_stage_prompts.get(
			stage_index,
			""
		)
	)


func supports_stage(
	stage_index: int
) -> bool:
	return (
		stage_index >= _first_expression_stage
		and stage_index <= _final_expression_stage
		and not prompt_for_stage(
			stage_index
		).is_empty()
	)


func required_traits_match(
	genome: PetGenome
) -> bool:
	if genome == null:
		return false

	for key_value in _required_traits.keys():
		var locus := StringName(
			str(key_value)
		)
		var required_trait := StringName(
			str(
				_required_traits[
					key_value
				]
			)
		)

		if genome.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		) != required_trait:
			return false

	return true


func effective_basis_points(
	tag_influences: Dictionary
) -> int:
	var result := _activation_basis_points

	for key_value in _gene_tag_affinity.keys():
		var tag := String(
			key_value
		)
		var influence := float(
			tag_influences.get(
				tag,
				0.0
			)
		)
		var basis_points_per_unit := float(
			_gene_tag_affinity[
				key_value
			]
		)

		result += int(
			round(
				influence
				* basis_points_per_unit
			)
		)

	return clampi(
		result,
		0,
		MAX_BASIS_POINTS
	)


func is_valid() -> bool:
	if (
		String(_id).is_empty()
		or _display_name.is_empty()
		or String(_species).is_empty()
		or _first_expression_stage < MIN_STAGE
		or _first_expression_stage > FINAL_STAGE
		or _final_expression_stage
			< _first_expression_stage
		or _final_expression_stage > FINAL_STAGE
		or _activation_basis_points < 0
		or _activation_basis_points > MAX_BASIS_POINTS
		or (
			not _required_loci.is_empty()
			and _required_loci.size() != 3
		)
		or _target_regions.is_empty()
		or _preserve_hint.is_empty()
	):
		return false

	var seen_loci: Dictionary = {}

	for locus in _required_loci:
		if (
			not PetGenomeSchema.is_visual_locus(
				locus
			)
			or seen_loci.has(
				locus
			)
		):
			return false

		seen_loci[locus] = true

	for region in _target_regions:
		if not PetGenomeSchema.is_visual_locus(
			region
		):
			return false

	for key_value in _required_traits.keys():
		var locus := StringName(
			str(key_value)
		)
		var trait_id := StringName(
			str(
				_required_traits[
					key_value
				]
			)
		)

		if (
			not PetGenomeSchema.is_visual_locus(
				locus
			)
			or String(trait_id).is_empty()
		):
			return false

	for key_value in _gene_tag_affinity.keys():
		if (
			String(key_value).strip_edges().is_empty()
			or float(
				_gene_tag_affinity[
					key_value
				]
			) < 0.0
		):
			return false

	for stage_index in range(
		_first_expression_stage,
		_final_expression_stage + 1
	):
		if prompt_for_stage(
			stage_index
		).is_empty():
			return false

	return true


func to_dict() -> Dictionary:
	var regions: Array[String] = []
	var loci: Array[String] = []

	for locus in _required_loci:
		loci.append(
			String(locus)
		)

	for region in _target_regions:
		regions.append(
			String(region)
		)

	var prompts: Dictionary = {}

	for key_value in _stage_prompts.keys():
		prompts[str(
			int(key_value)
		)] = String(
			_stage_prompts[
				key_value
			]
		)

	return {
		"id": String(_id),
		"display_name": _display_name,
		"species": String(_species),
		"first_expression_stage": (
			_first_expression_stage
		),
		"final_expression_stage": (
			_final_expression_stage
		),
		"activation_basis_points": (
			_activation_basis_points
		),
		"egg_stage4_eligible": (
			_egg_stage4_eligible
		),
		"required_loci": loci,
		"target_regions": regions,
		"required_traits": (
			_required_traits.duplicate(true)
		),
		"gene_tag_affinity": (
			_gene_tag_affinity.duplicate(true)
		),
		"stage_prompts": prompts,
		"preserve_hint": _preserve_hint,
	}


static func from_dict(
	data: Dictionary
) -> SpeciesMythicMutationDefinition:
	var loci_value: Variant = data.get(
		"required_loci",
		[]
	)
	var regions_value: Variant = data.get(
		"target_regions",
		[]
	)
	var traits_value: Variant = data.get(
		"required_traits",
		{}
	)
	var affinity_value: Variant = data.get(
		"gene_tag_affinity",
		{}
	)
	var prompts_value: Variant = data.get(
		"stage_prompts",
		{}
	)

	if (
		typeof(loci_value) != TYPE_ARRAY
		or typeof(regions_value) != TYPE_ARRAY
		or typeof(traits_value) != TYPE_DICTIONARY
		or typeof(affinity_value) != TYPE_DICTIONARY
		or typeof(prompts_value) != TYPE_DICTIONARY
	):
		return null

	var definition := SpeciesMythicMutationDefinition.new(
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
					"species",
					""
				)
			)
		),
		int(
			data.get(
				"first_expression_stage",
				3
			)
		),
		int(
			data.get(
				"final_expression_stage",
				4
			)
		),
		int(
			data.get(
				"activation_basis_points",
				0
			)
		),
		bool(
			data.get(
				"egg_stage4_eligible",
				false
			)
		),
		loci_value as Array,
		regions_value as Array,
		traits_value as Dictionary,
		affinity_value as Dictionary,
		prompts_value as Dictionary,
		String(
			data.get(
				"preserve_hint",
				""
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
			.replace(
				" ",
				"_"
			)
	)


static func _normalize_loci(
	source: Array
) -> Array[StringName]:
	var result: Array[StringName] = []

	for value in source:
		var locus := _normalize_token(
			StringName(
				str(value)
			)
		)

		if (
			String(locus).is_empty()
			or result.has(
				locus
			)
		):
			continue

		result.append(
			locus
		)

	return result


static func _normalize_regions(
	source: Array
) -> Array[StringName]:
	var result: Array[StringName] = []

	for value in source:
		var region := _normalize_token(
			StringName(
				str(value)
			)
		)

		if (
			String(region).is_empty()
			or result.has(region)
		):
			continue

		result.append(
			region
		)

	return result


static func _normalize_traits(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		var locus := _normalize_token(
			StringName(
				str(key_value)
			)
		)
		var trait_id := _normalize_token(
			StringName(
				str(
					source[
						key_value
					]
				)
			)
		)

		result[String(locus)] = String(
			trait_id
		)

	return result


static func _normalize_affinity(
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
			source[
				key_value
			]
		)

	return result


static func _normalize_prompts(
	source: Dictionary
) -> Dictionary:
	var result: Dictionary = {}

	for key_value in source.keys():
		var stage_index := int(
			str(key_value)
		)
		var prompt := String(
			source[
				key_value
			]
		).strip_edges()

		if (
			stage_index < MIN_STAGE
			or stage_index > FINAL_STAGE
			or prompt.is_empty()
		):
			continue

		result[stage_index] = prompt

	return result
