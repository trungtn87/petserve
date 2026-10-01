class_name StageGenePolicy
extends RefCounted

const DEFAULT_PATH: String = "res://data/evolution/gene/stage_gene_policy.json"
const FIRST_STAGE: int = 1
const FINAL_STAGE: int = 4
const UNLIMITED_ITEMS: int = -1

var _stages: Dictionary = {}

func stage(stage_index: int) -> Dictionary:
	var value: Variant = _stages.get(stage_index, {})
	return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}

func allowed_loci(stage_index: int) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw_value: Variant = stage(stage_index).get("allowed_loci", [])
	if typeof(raw_value) != TYPE_ARRAY:
		return result
	for value in raw_value as Array:
		result.append(StringName(str(value)))
	return result

func max_gene_items(stage_index: int) -> int:
	return int(stage(stage_index).get("max_gene_items", 0))

func is_unlimited(stage_index: int) -> bool:
	return max_gene_items(stage_index) == UNLIMITED_ITEMS

func can_accept_gene(stage_index: int, locus: StringName) -> bool:
	var normalized_locus := _normalize_name(locus)
	if not PetGenomeSchema.is_gene_locus(normalized_locus):
		return false
	if max_gene_items(stage_index) == 0:
		return false
	return allowed_loci(stage_index).has(normalized_locus)

func has_stage(stage_index: int) -> bool:
	return _stages.has(stage_index)

static func load_default() -> StageGenePolicy:
	return load_from_path(DEFAULT_PATH)

static func load_from_path(path: String) -> StageGenePolicy:
	if not FileAccess.file_exists(path):
		push_error("StageGenePolicy: không tìm thấy " + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_ARRAY:
		return null
	var policy := StageGenePolicy.new()
	for raw_value in parsed as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return null
		var raw := raw_value as Dictionary
		var stage_index := int(raw.get("stage", 0))
		var max_items := int(raw.get("max_gene_items", 0))
		var loci_value: Variant = raw.get("allowed_loci", [])
		if (
			stage_index < FIRST_STAGE
			or stage_index > FINAL_STAGE
			or max_items < UNLIMITED_ITEMS
			or policy._stages.has(stage_index)
			or typeof(loci_value) != TYPE_ARRAY
		):
			return null
		var loci: Array[StringName] = []
		var seen: Dictionary = {}
		for locus_value in loci_value as Array:
			var locus := _normalize_name(StringName(str(locus_value)))
			if String(locus).is_empty() or not PetGenomeSchema.is_gene_locus(locus) or seen.has(locus):
				return null
			seen[locus] = true
			loci.append(locus)
		if (max_items == 0 and not loci.is_empty()) or (max_items != 0 and loci.is_empty()):
			return null
		policy._stages[stage_index] = {
			"stage": stage_index,
			"max_gene_items": max_items,
			"allowed_loci": loci,
		}
	for required_stage in range(FIRST_STAGE, FINAL_STAGE + 1):
		if not policy.has_stage(required_stage):
			return null
	return policy

static func _normalize_name(value: StringName) -> StringName:
	return StringName(String(value).strip_edges().to_lower().replace(" ", "_"))
