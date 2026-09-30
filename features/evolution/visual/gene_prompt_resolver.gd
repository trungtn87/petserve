class_name GenePromptResolver
extends RefCounted

func build(state: GeneDevelopmentState, element: StringName, target_stage: int) -> String:
	if state == null or not state.has_lifetime_scores():
		return ""
	var definitions := GeneCatalog.new().load_default()
	var scores := state.gene_scores_snapshot()
	var sections: Array[String] = []
	for locus in PetGenomeSchema.VISUAL_LOCI:
		var rows: Array[Dictionary] = []
		for definition in definitions:
			if definition == null or definition.locus() != locus or not definition.is_element_compatible(element):
				continue
			var key := GeneDevelopmentState.score_key(definition.locus(), definition.direction())
			var score := float(scores.get(key, 0.0))
			if score <= 0.0:
				continue
			rows.append({"definition": definition, "score": score})
		rows.sort_custom(_sort_rows)
		if rows.is_empty():
			continue
		var lines: Array[String] = []
		for index in range(rows.size()):
			var row := rows[index]
			var definition := row.get("definition") as GeneDefinition
			var score := float(row.get("score", 0.0))
			var tier := GeneExpressionScale.tier_for_score(score)
			var role := "DOMINANT" if index == 0 else "SECONDARY BLEND"
			lines.append(
				"- %s / %s / %.0f pts / %s: %s %s %s"
				% [
					role,
					String(tier).to_upper(),
					score,
					String(definition.direction()),
					_tier_instruction(tier),
					definition.prompt_stem(),
					definition.preserve_hint(),
				]
			)
		sections.append(
			"Locus %s:
%s"
			% [String(locus), "
".join(lines)]
		)
	if sections.is_empty():
		return ""
	return (
		"Accumulated Gene Score phenotype for evolution Stage %d. "
		+ "Scores persist across stages. Multiple directions in one locus may blend; the highest score is dominant. "
		+ "Do not invent directions that are not listed.
%s"
	) % [target_stage, "
".join(sections)]

func _tier_instruction(tier: StringName) -> String:
	match tier:
		GeneExpressionScale.TRACE:
			return "Express only a faint early trace of this direction:"
		GeneExpressionScale.DEVELOPING:
			return "Make this direction noticeable but still restrained:"
		GeneExpressionScale.EXPRESSED:
			return "Express this direction clearly and coherently:"
		GeneExpressionScale.DOMINANT:
			return "Make this a strong defining feature of this locus:"
		GeneExpressionScale.ASCENDED:
			return "Express this as an exceptional mature signature of the lineage while preserving believable anatomy:"
		_:
			return ""

func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_score := float(a.get("score", 0.0))
	var b_score := float(b.get("score", 0.0))
	if not is_equal_approx(a_score, b_score):
		return a_score > b_score
	var a_def := a.get("definition") as GeneDefinition
	var b_def := b.get("definition") as GeneDefinition
	return String(a_def.id()) < String(b_def.id())
