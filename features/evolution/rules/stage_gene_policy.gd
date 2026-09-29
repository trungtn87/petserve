class_name StageGenePolicy
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/gene/stage_gene_policy.json"
)


var _stages: Dictionary = {}


func stage(
	stage_index: int
) -> Dictionary:
	var value: Variant = _stages.get(
		stage_index,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func allowed_loci(
	stage_index: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	var definition := stage(
		stage_index
	)
	var raw_value: Variant = definition.get(
		"allowed_loci",
		[]
	)

	if typeof(raw_value) != TYPE_ARRAY:
		return result

	for value in raw_value as Array:
		result.append(
			StringName(
				str(value)
			)
		)

	return result


func max_gene_items(
	stage_index: int
) -> int:
	return int(
		stage(
			stage_index
		).get(
			"max_gene_items",
			0
		)
	)


func can_accept_gene(
	stage_index: int,
	locus: StringName
) -> bool:
	if not PetGenomeSchema.is_visual_locus(
		locus
	):
		return false

	if max_gene_items(
		stage_index
	) <= 0:
		return false

	return allowed_loci(
		stage_index
	).has(
		locus
	)


func has_stage(
	stage_index: int
) -> bool:
	return _stages.has(
		stage_index
	)


static func load_default() -> StageGenePolicy:
	return load_from_path(
		DEFAULT_PATH
	)


static func load_from_path(
	path: String
) -> StageGenePolicy:
	if not FileAccess.file_exists(
		path
	):
		push_error(
			"StageGenePolicy: không tìm thấy "
			+ path
		)
		return null

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return null

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		return null

	var policy := StageGenePolicy.new()

	for raw_value in parsed as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null

		var raw := raw_value as Dictionary
		var stage_index := int(
			raw.get(
				"stage",
				0
			)
		)
		var max_items := int(
			raw.get(
				"max_gene_items",
				-1
			)
		)
		var loci_value: Variant = raw.get(
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

		var loci: Array[StringName] = []
		var seen: Dictionary = {}

		for locus_value in loci_value as Array:
			var locus := StringName(
				str(locus_value)
				.strip_edges()
				.to_lower()
			)

			if (
				String(locus).is_empty()
				or not PetGenomeSchema.is_visual_locus(
					locus
				)
				or seen.has(
					locus
				)
			):
				return null

			seen[locus] = true
			loci.append(
				locus
			)

		if (
			(max_items == 0 and not loci.is_empty())
			or (max_items > 0 and loci.is_empty())
		):
			return null

		policy._stages[stage_index] = {
			"stage": stage_index,
			"max_gene_items": max_items,
			"allowed_loci": loci,
		}

	if policy._stages.is_empty():
		return null

	return policy
