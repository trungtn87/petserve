class_name StageGenePolicy
extends RefCounted


const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = (
	"res://data/evolution/gene/stage_gene_policy.json"
)


var _stages: Dictionary = {}


static func load_default() -> StageGenePolicy:
	var file := FileAccess.open(
		DEFAULT_PATH,
		FileAccess.READ
	)

	if file == null:
		return null

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return null

	return from_dict(
		parsed as Dictionary
	)


static func from_dict(
	data: Dictionary
) -> StageGenePolicy:
	if int(
		data.get(
			"schema",
			0
		)
	) != SCHEMA_VERSION:
		return null

	var stages_value: Variant = data.get(
		"stages",
		[]
	)

	if typeof(stages_value) != TYPE_ARRAY:
		return null

	var policy := StageGenePolicy.new()

	for raw_stage in stages_value as Array:
		if typeof(raw_stage) != TYPE_DICTIONARY:
			return null

		var entry: Dictionary = raw_stage
		var stage_index := int(
			entry.get(
				"stage",
				0
			)
		)
		var max_items := int(
			entry.get(
				"max_gene_items",
				-1
			)
		)
		var loci_value: Variant = entry.get(
			"allowed_loci",
			[]
		)

		if (
			stage_index < 1
			or max_items < 0
			or policy._stages.has(
				stage_index
			)
			or typeof(loci_value) != TYPE_ARRAY
		):
			return null

		var normalized_loci: Array[StringName] = []

		for raw_locus in loci_value as Array:
			var locus := StringName(
				str(raw_locus)
				.strip_edges()
				.to_lower()
			)

			if (
				String(locus).is_empty()
				or not PetGenomeSchema.is_visual_locus(
					locus
				)
				or normalized_loci.has(
					locus
				)
			):
				return null

			normalized_loci.append(
				locus
			)

		policy._stages[stage_index] = {
			"max_gene_items": max_items,
			"allowed_loci": normalized_loci,
		}

	if not policy.is_valid():
		return null

	return policy


func is_valid() -> bool:
	for stage_index in range(
		1,
		5
	):
		if not _stages.has(
			stage_index
		):
			return false

	for key_value in _stages.keys():
		var stage_index := int(
			key_value
		)

		if stage_index < 1 or stage_index > 4:
			return false

		var entry: Dictionary = _stages[
			key_value
		]

		var max_items := int(
			entry.get(
				"max_gene_items",
				-1
			)
		)

		if max_items < 0:
			return false

		var loci_value: Variant = entry.get(
			"allowed_loci",
			[]
		)

		if typeof(loci_value) != TYPE_ARRAY:
			return false

		for raw_locus in loci_value as Array:
			if not PetGenomeSchema.is_visual_locus(
				StringName(
					str(raw_locus)
				)
			):
				return false

	return true


func max_gene_items(
	stage_index: int
) -> int:
	var entry := _stage_entry(
		stage_index
	)

	if entry.is_empty():
		return 0

	return int(
		entry.get(
			"max_gene_items",
			0
		)
	)


func allowed_loci(
	stage_index: int
) -> Array[StringName]:
	var entry := _stage_entry(
		stage_index
	)
	var result: Array[StringName] = []

	if entry.is_empty():
		return result

	for raw_locus in (
		entry.get(
			"allowed_loci",
			[]
		) as Array
	):
		result.append(
			StringName(
				str(raw_locus)
			)
		)

	return result


func allows_locus(
	stage_index: int,
	locus: StringName
) -> bool:
	return allowed_loci(
		stage_index
	).has(
		StringName(
			String(locus)
			.strip_edges()
			.to_lower()
		)
	)


func remaining_slots(
	stage_index: int,
	used_gene_items: int
) -> int:
	return max(
		0,
		max_gene_items(
			stage_index
		) - max(
			0,
			used_gene_items
		)
	)


func can_accept_gene_item(
	stage_index: int,
	used_gene_items: int,
	locus: StringName
) -> bool:
	return (
		remaining_slots(
			stage_index,
			used_gene_items
		) > 0
		and allows_locus(
			stage_index,
			locus
		)
	)


func _stage_entry(
	stage_index: int
) -> Dictionary:
	if not _stages.has(
		stage_index
	):
		return {}

	return (
		_stages[stage_index] as Dictionary
	).duplicate(true)
