class_name StageGenePolicy
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/gene/stage_gene_policy.json"
)

const FIRST_STAGE: int = 1
const FINAL_STAGE: int = 4


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


func is_stage_defined(
	stage_index: int
) -> bool:
	return _stages.has(stage_index)


func allowed_loci(
	stage_index: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	var definition := stage(stage_index)

	if definition.is_empty():
		return result

	var raw_value: Variant = definition.get(
		"allowed_loci",
		[]
	)

	if typeof(raw_value) != TYPE_ARRAY:
		return result

	for value in raw_value as Array:
		result.append(
			StringName(str(value))
		)

	return result


func allows_locus(
	stage_index: int,
	locus: StringName
) -> bool:
	return allowed_loci(
		stage_index
	).has(
		_normalize_token(locus)
	)


func max_gene_items(
	stage_index: int
) -> int:
	return int(
		stage(stage_index).get(
			"max_gene_items",
			0
		)
	)


func can_accept_item(
	stage_index: int,
	current_item_count: int
) -> bool:
	if (
		not is_stage_defined(stage_index)
		or current_item_count < 0
	):
		return false

	return (
		current_item_count
		< max_gene_items(stage_index)
	)


static func load_default() -> StageGenePolicy:
	return load_from_path(DEFAULT_PATH)


static func load_from_path(
	path: String
) -> StageGenePolicy:
	if not FileAccess.file_exists(path):
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
			stage_index < FIRST_STAGE
			or stage_index > FINAL_STAGE
			or max_items < 0
			or policy._stages.has(stage_index)
			or typeof(loci_value) != TYPE_ARRAY
		):
			return null

		var loci: Array[StringName] = []

		for value in loci_value as Array:
			var locus := _normalize_token(
				StringName(str(value))
			)

			if (
				not PetGenomeSchema.is_visual_locus(
					locus
				)
				or loci.has(locus)
			):
				return null

			loci.append(locus)

		if (
			(max_items == 0 and not loci.is_empty())
			or (
				max_items > 0
				and loci.is_empty()
			)
		):
			return null

		policy._stages[stage_index] = {
			"stage": stage_index,
			"allowed_loci": _string_list(loci),
			"max_gene_items": max_items,
		}

	for required_stage in range(
		FIRST_STAGE,
		FINAL_STAGE + 1
	):
		if not policy._stages.has(
			required_stage
		):
			return null

	return policy


static func _normalize_token(
	value: StringName
) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)


static func _string_list(
	source: Array[StringName]
) -> Array[String]:
	var result: Array[String] = []

	for value in source:
		result.append(String(value))

	return result
