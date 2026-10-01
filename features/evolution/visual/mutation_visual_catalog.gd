class_name MutationVisualCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/visual/mutation_visuals.json"
)

const GENE_EXPR_PREFIX: String = "gene_expr_"
const MIN_GENE_STAGE: int = 1
const MAX_GENE_STAGE: int = 4


func load_default() -> Array[MutationVisualDefinition]:
	return load_from_path(DEFAULT_PATH)


func load_from_path(
	path: String
) -> Array[MutationVisualDefinition]:
	var result: Array[MutationVisualDefinition] = []

	if not FileAccess.file_exists(path):
		push_error(
			"MutationVisualCatalog: Không tìm thấy file: "
			+ path
		)
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"MutationVisualCatalog: Không mở được file: "
			+ path
		)
		return result

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		push_error(
			"MutationVisualCatalog: Root JSON phải là Array."
		)
		return result

	var seen: Dictionary = {}

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var definition := (
			MutationVisualDefinition.from_dict(
				value as Dictionary
			)
		)

		if definition == null:
			continue

		if seen.has(
			definition.mutation_id()
		):
			push_error(
				"MutationVisualCatalog: Trùng mutation_id: "
				+ String(
					definition.mutation_id()
				)
			)
			return []

		seen[definition.mutation_id()] = true
		result.append(definition)

	result.sort_custom(
		_sort_by_id
	)

	return result


func find_by_id(
	definitions: Array[MutationVisualDefinition],
	mutation_id: StringName
) -> MutationVisualDefinition:
	for definition in definitions:
		if (
			definition.mutation_id()
			== mutation_id
		):
			return definition

	# Gene expressions are generated dynamically by StageEvolutionResolver.
	# The Gene catalog is the canonical source for their visual instruction.
	# Keep hand-authored mutation_visuals.json entries as overrides, then
	# synthesize any missing gene_expr_<gene_id>_s<stage> definition here.
	return _build_gene_expression_visual(
		mutation_id
	)


func _build_gene_expression_visual(
	mutation_id: StringName
) -> MutationVisualDefinition:
	var token := String(
		mutation_id
	).strip_edges().to_lower()

	if not token.begins_with(
		GENE_EXPR_PREFIX
	):
		return null

	var suffix_index := token.rfind(
		"_s"
	)

	if suffix_index <= GENE_EXPR_PREFIX.length():
		return null

	var stage_text := token.substr(
		suffix_index + 2
	)

	if not stage_text.is_valid_int():
		return null

	var source_stage := stage_text.to_int()

	if (
		source_stage < MIN_GENE_STAGE
		or source_stage > MAX_GENE_STAGE
	):
		return null

	var gene_id := StringName(
		token.substr(
			GENE_EXPR_PREFIX.length(),
			suffix_index - GENE_EXPR_PREFIX.length()
		)
	)

	var gene_catalog := GeneCatalog.new()
	var gene := gene_catalog.find_by_id(
		gene_catalog.load_default(),
		gene_id
	)

	if gene == null:
		return null

	var instruction := (
		gene.prompt_stem()
		+ " This is the code-selected Gene expression for the Stage %d -> %d transition. "
		+ "Develop only this Gene locus and keep the result consistent with the target phenotype."
	) % [
		source_stage,
		source_stage + 1,
	]

	var preserve_hint := gene.preserve_hint()

	if preserve_hint.is_empty():
		preserve_hint = (
			"Preserve the same individual pet identity and every non-target Gene locus."
		)
	else:
		preserve_hint += (
			" Preserve the same individual pet identity and every non-target Gene locus."
		)

	var visual := MutationVisualDefinition.new(
		mutation_id,
		gene.locus(),
		instruction,
		preserve_hint,
		_edit_strength_for_locus(
			gene.locus()
		)
	)

	return (
		visual
		if visual.is_valid()
		else null
	)


func _edit_strength_for_locus(
	locus: StringName
) -> float:
	match locus:
		&"body", &"structure":
			return 0.20
		&"tail", &"mane":
			return 0.19
		&"ears", &"fur":
			return 0.18
		&"eyes", &"coat", &"paws":
			return 0.17
		&"mark", &"aura":
			return 0.16
		&"whiskers":
			return 0.15
		_:
			return 0.17


func _sort_by_id(
	a: MutationVisualDefinition,
	b: MutationVisualDefinition
) -> bool:
	return (
		String(a.mutation_id())
		< String(b.mutation_id())
	)
