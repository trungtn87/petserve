class_name GenePromptResolver
extends RefCounted


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
	var rows: Array[Dictionary] = []

	for definition in definitions:
		if (
			definition == null
			or not definition.is_element_compatible(element)
		):
			continue

		var key := GeneDevelopmentState.score_key(
			definition.locus(),
			definition.direction()
		)
		var score := float(scores.get(key, 0.0))

		if score <= 0.0:
			continue

		rows.append({
			"definition": definition,
			"score": score,
		})

	rows.sort_custom(_sort_rows)

	if rows.is_empty():
		return ""

	var subject := String(species).strip_edges().to_lower()
	if subject.is_empty():
		subject = "pet"

	var lines: Array[String] = []

	for row in rows:
		var definition := row.get("definition") as GeneDefinition
		var score := float(row.get("score", 0.0))
		var tier := GeneExpressionScale.tier_for_score(score)
		var fragment := definition.prompt_stem()

		lines.append(
			"- " + _trait_sentence(
				tier,
				subject,
				fragment
			)
		)

	return (
		"[GENE TRAITS]\n"
		+ (
			"Apply every Gene trait below to the same %s at Stage %d. "
			+ "Each line is a direct visual hint, not an anatomy rule. "
			+ "Interpret unusual combinations freely as fantasy design. "
			+ "Higher-score traits should be more visually obvious than weaker traits.\n"
		) % [
			subject,
			target_stage,
		]
		+ "\n".join(lines)
		+ "\nKeep all requested Gene traits visible on the same pet. "
		+ "Do not omit any strongly expressed Gene trait."
	)


func _trait_sentence(
	tier: StringName,
	subject: String,
	fragment: String
) -> String:
	match tier:
		GeneExpressionScale.TRACE:
			return (
				"The %s shows only a subtle hint of this Gene trait: %s."
				% [subject, fragment]
			)
		GeneExpressionScale.DEVELOPING:
			return (
				"The %s visibly shows this Gene trait: %s."
				% [subject, fragment]
			)
		GeneExpressionScale.EXPRESSED:
			return (
				"The %s clearly develops this Gene trait: %s."
				% [subject, fragment]
			)
		GeneExpressionScale.DOMINANT:
			return (
				"The %s strongly displays this distinctive Gene trait: %s."
				% [subject, fragment]
			)
		GeneExpressionScale.ASCENDED:
			return (
				"The %s has an exceptional fantasy expression of this Gene trait: %s."
				% [subject, fragment]
			)
		_:
			return ""


func _sort_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_score := float(a.get("score", 0.0))
	var b_score := float(b.get("score", 0.0))

	if not is_equal_approx(a_score, b_score):
		return a_score > b_score

	var a_def := a.get("definition") as GeneDefinition
	var b_def := b.get("definition") as GeneDefinition

	return String(a_def.id()) < String(b_def.id())
