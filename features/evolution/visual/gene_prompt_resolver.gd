class_name GenePromptResolver
extends RefCounted


const SpeciesExpression = preload(
	"res://features/evolution/visual/species_gene_expression.gd"
)

func build(
	state: GeneDevelopmentState,
	element: StringName,
	target_stage: int,
	species: StringName = &""
) -> String:
	if state == null:
		return ""
	return build_from_scores(
		state.gene_scores_snapshot(),
		element,
		target_stage,
		species
	)


func build_from_scores(
	scores: Dictionary,
	element: StringName,
	target_stage: int,
	species: StringName = &""
) -> String:
	if scores.is_empty():
		return ""

	var definitions := GeneCatalog.new().load_default()
	var sections: Array[String] = []
	var species_adapter = null

	if not String(
		species
	).is_empty():
		species_adapter = SpeciesExpression.new()

	for locus in PetGenomeSchema.VISUAL_LOCI:
		var rows: Array[Dictionary] = []

		for definition in definitions:
			if (
				definition == null
				or definition.locus() != locus
				or not definition.is_element_compatible(
					element
				)
			):
				continue

			var key := GeneDevelopmentState.score_key(
				definition.locus(),
				definition.direction()
			)
			var score := float(
				scores.get(
					key,
					0.0
				)
			)

			if score <= 0.0:
				continue

			rows.append({
				"definition": definition,
				"score": score,
			})

		rows.sort_custom(
			_sort_rows
		)

		if rows.is_empty():
			continue

		var lines: Array[String] = []

		for index in range(
			rows.size()
		):
			var row := rows[index]
			var definition := row.get(
				"definition"
			) as GeneDefinition
			var score := float(
				row.get(
					"score",
					0.0
				)
			)
			var tier := GeneExpressionScale.tier_for_score(
				score
			)
			var role := (
				"DOMINANT"
				if index == 0
				else "SECONDARY BLEND"
			)

			var instruction := definition.prompt_stem()
			var preserve := definition.preserve_hint()

			if species_adapter != null:
				var translated: String = String(
					species_adapter.translate(
						species,
						definition.locus(),
						definition.direction()
					)
				)

				if not translated.is_empty():
					instruction = translated

				preserve = (
					"Preserve %s."
					% species_adapter.anatomy(
						species
					)
				)

			lines.append(
				"- %s / %s / %.0f pts / %s: %s %s %s"
				% [
					role,
					String(tier).to_upper(),
					score,
					String(
						definition.direction()
					),
					_tier_instruction(
						tier
					),
					instruction,
					preserve,
				]
			)

		sections.append(
			"Locus %s:\n%s"
			% [
				String(locus),
				"\n".join(lines),
			]
		)

	if sections.is_empty():
		return ""

	return (
		"Accumulated Gene Score phenotype for evolution Stage %d. "
		+ "Every listed positive-score Gene must produce a visible phenotype; score controls intensity, not whether it appears. "
		+ "Scores persist across stages. Multiple directions in one locus may blend; "
		+ "the highest score establishes the primary direction. Secondary directions contribute complementary details rather than averaging the form into a generic body. Structure Genes coordinate existing body regions. Express every trait within the target stage maturity envelope. Do not invent unlisted directions.\n%s"
	) % [
		target_stage,
		"\n".join(sections),
	]


func _tier_instruction(
	tier: StringName
) -> String:
	match tier:
		GeneExpressionScale.TRACE:
			return "Express a subtle but unambiguous visible version of this direction; it must still be readable at first glance:"
		GeneExpressionScale.DEVELOPING:
			return "Make this direction clearly visible at first glance in shape or pattern at full-body scale:"
		GeneExpressionScale.EXPRESSED:
			return "Make this a prominent signature feature: structural Genes must change the silhouette, while energy Genes stay localized:"
		GeneExpressionScale.DOMINANT:
			return "Make this a major defining feature of this locus with a strong silhouette or surface change where anatomically appropriate:"
		GeneExpressionScale.ASCENDED:
			return "Make this an unmistakable mature signature of the lineage at the strongest believable expression while preserving valid anatomy:"
		_:
			return ""


func _sort_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_score := float(
		a.get(
			"score",
			0.0
		)
	)
	var b_score := float(
		b.get(
			"score",
			0.0
		)
	)

	if not is_equal_approx(
		a_score,
		b_score
	):
		return a_score > b_score

	var a_def := a.get(
		"definition"
	) as GeneDefinition
	var b_def := b.get(
		"definition"
	) as GeneDefinition

	return String(
		a_def.id()
	) < String(
		b_def.id()
	)
