extends RefCounted

const Morphology = preload(
	"res://features/evolution/visual/lineage_morphology.gd"
)

const PALETTES := {
	"wood": "cream and warm brown with fresh green accents",
	"water": "pearl white and aqua with turquoise accents",
	"fire": "cream and peach with orange and ember accents",
	"earth": "beige and warm brown with mineral accents",
	"metal": "silver white with cool blue metallic accents",
	"light": "ivory with soft gold accents",
	"dark": "charcoal indigo with muted violet and cyan accents",
}


func build(
	identity: PetIdentity,
	stage: int,
	scores: Dictionary,
	mythic: Dictionary = {}
) -> String:
	if identity == null or not identity.is_valid():
		return ""

	var target_stage := clampi(stage, 1, 5)
	var morphology := Morphology.new()
	var form := morphology.resolve(
		identity,
		target_stage,
		scores
	)

	if form.is_empty():
		return ""

	var species := String(identity.species())
	var element_name := PetElementCatalog.prompt_name(
		identity.element()
	)
	var lines: Array[String] = []

	lines.append(
		(
			"PRIMARY IMAGE: Create one full-body fantasy %s pet inside a complete %s fantasy habitat. "
			+ "Show the complete pet and the surrounding environment together in one coherent vertical 9:16 image."
		) % [
			species,
			element_name,
		]
	)

	lines.append(
		(
			"IDENTITY: This is the same individual %s across its life stages. "
			+ "Keep its recognizable lineage, base color family and visual personality. "
			+ "Gene traits are allowed to transform or extend fantasy anatomy when requested."
		) % species
	)

	lines.append(
		(
			"ELEMENT: The %s clearly belongs to the %s element. "
			+ "Its elemental characteristics are naturally integrated into its appearance. "
			+ "The surrounding environment also clearly reflects the same element."
		) % [
			species,
			element_name,
		]
	)

	lines.append(
		(
			"STAGE: Stage %d. %s "
			+ "Make natural growth from the previous stage visibly readable in the body, not only through glow or camera zoom."
		) % [
			target_stage,
			Morphology.STAGES[target_stage],
		]
	)

	lines.append(
		(
			"INDIVIDUAL FRAME: inherited tendency: %s; %s; %s. "
			+ "Use this only as a loose identity cue. Do not treat it as a rigid anatomical measurement."
		) % [
			String(form.get("frame", "balanced frame")),
			String(form.get("face", "recognizable face")),
			String(form.get("fur_line", "clean surface flow")),
		]
	)

	var gene_prompt := GenePromptResolver.new().build_from_scores(
		scores,
		identity.element(),
		target_stage,
		identity.species()
	)

	if not gene_prompt.is_empty():
		lines.append(gene_prompt)

	var mythic_active := String(
		mythic.get(
			"mode",
			"none"
		)
	) in [
		"awaken",
		"continue",
	]

	if mythic_active:
		lines.append(
			"AUTHORIZED MYTHIC ANATOMY: "
			+ String(
				mythic.get(
					"prompt",
					""
				)
			)
			+ " "
			+ String(
				mythic.get(
					"preserve_hint",
					""
				)
			)
		)

	lines.append(
		(
			"STYLE: polished stylized 3D fantasy pet illustration, premium mobile-game character art, "
			+ "clean readable silhouette, expressive face, controlled lighting. Palette: %s."
		) % PALETTES.get(
			String(identity.element()),
			"coherent elemental colors"
		)
	)

	lines.append(
		(
			"FINAL COMPOSITION: Keep the pet as the clear main subject but leave substantial habitat visible around it. "
			+ "Keep the upper area calm for game UI. Keep all requested Gene traits visible on the same pet. "
			+ "Show the complete pet and the elemental habitat together. "
			+ "Do not omit the environment or any strongly expressed Gene trait. No text, UI, logo or watermark."
		)
	)

	return "\n\n".join(lines)


func resolve_traits(
	identity: PetIdentity,
	stage: int,
	scores: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if identity == null or not identity.is_valid():
		return result

	for gene in GeneCatalog.new().load_default():
		if (
			gene == null
			or not gene.is_element_compatible(
				identity.element()
			)
		):
			continue

		var key := GeneDevelopmentState.score_key(
			gene.locus(),
			gene.direction()
		)
		var score := float(
			scores.get(
				key,
				0.0
			)
		)

		if score <= 0.0:
			continue

		result.append({
			"id": String(gene.id()),
			"locus": String(gene.locus()),
			"score": score,
			"text": gene.prompt_stem(),
			"tier": String(
				GeneExpressionScale.tier_for_score(
					score
				)
			),
		})

	result.sort_custom(_sort_trait_rows)
	return result


func _sort_trait_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_score := float(a.get("score", 0.0))
	var b_score := float(b.get("score", 0.0))

	if not is_equal_approx(a_score, b_score):
		return a_score > b_score

	return String(a.get("id", "")) < String(b.get("id", ""))
