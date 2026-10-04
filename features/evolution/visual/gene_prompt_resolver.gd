class_name GenePromptResolver
extends RefCounted

func build(
	state: GeneDevelopmentState,
	element: StringName,
	target_stage: int
) -> String:
	if state == null:
		return ""
	return build_from_scores(
		state.gene_scores_snapshot(),
		element,
		target_stage
	)


func build_from_scores(
	scores: Dictionary,
	element: StringName,
	target_stage: int
) -> String:
	if scores.is_empty():
		return ""

	var definitions := GeneCatalog.new().load_default()
	var sections: Array[String] = []

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
					definition.prompt_stem(),
					definition.preserve_hint(),
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
		+ "the highest score is dominant. Do not invent directions that are not listed.\n%s"
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
			return "Make this direction clearly visible at first glance with moderate strength; do not hide it behind generic stage growth:"
		GeneExpressionScale.EXPRESSED:
			return "Make this direction prominent, immediately readable and visually coherent:"
		GeneExpressionScale.DOMINANT:
			return "Make this a major defining feature of this locus, with a strong silhouette or surface change where anatomically appropriate:"
		GeneExpressionScale.ASCENDED:
			return "Make this an unmistakable signature of the lineage at the strongest believable expression while preserving valid anatomy:"
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
