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

	if target_stage in [2, 3, 4]:
		return _build_reference_stage_prompt(
			identity,
			target_stage,
			scores,
			mythic
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


func _build_reference_stage_prompt(
	identity: PetIdentity,
	target_stage: int,
	scores: Dictionary,
	mythic: Dictionary
) -> String:
	var species := String(identity.species())
	var element_name := PetElementCatalog.prompt_name(
		identity.element()
	)
	var previous_stage := target_stage - 1
	var lines: Array[String] = []

	lines.append(
		"[REFERENCE IMAGE]\n"
		+ (
			"Use the supplied Stage %d image as the canonical visual reference for this exact pet. "
			+ "Evolve that same individual into Stage %d. "
			+ "Do not recreate or reinterpret the previous stage from a written description. "
			+ "Take the pet's face, species identity, colors, markings, elemental appearance and overall design directly from the reference image."
		) % [
			previous_stage,
			target_stage,
		]
	)

	lines.append(
		"[STAGE %d GROWTH]\n%s"
		% [
			target_stage,
			_growth_prompt(target_stage),
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
			"[MYTHIC]\n"
			+ String(
				mythic.get(
					"prompt",
					""
				)
			)
		)

	lines.append(
		"[BACKGROUND]\n"
		+ "Keep the same general habitat identity shown in the reference image. "
		+ "The background must remain clearly visible and naturally match the "
		+ element_name
		+ " element. Do not replace it with a plain white, gray or empty studio background."
	)

	lines.append(
		"[FINAL]\n"
		+ "Keep the same overall art style and individual identity as the reference image. "
		+ "Show one complete full-body "
		+ species
		+ " with all requested Gene traits visible on the same pet. "
		+ "Keep substantial environment visible around the pet. "
		+ "Do not fake growth by zooming the camera closer. No text, UI, logo or watermark."
	)

	return "\n\n".join(lines)


func _growth_prompt(
	target_stage: int
) -> String:
	match target_stage:
		2:
			return (
				"Grow the same pet into a clearly older juvenile form. "
				+ "Physical growth must be obvious: a more developed torso and chest, more mature limb proportions where natural, "
				+ "and a less baby-like overall body while still remaining youthful and cute. "
				+ "Allow a new natural pose. Make the change read as body growth, not camera zoom, extra glow or added decoration."
			)
		3:
			return (
				"Grow the same pet into a clearly more mature adolescent form. "
				+ "Develop the body further from the reference: longer and more confident proportions, a fuller torso and chest, "
				+ "more mature limbs and a face that reads older while still belonging to the same individual. "
				+ "Allow a new natural pose. The Stage 3 change must be visible in the physical form, not only in effects, glow or decoration."
			)
		4:
			return (
				"Grow the same pet into its mature Stage 4 form. "
				+ "Complete the natural development of its body proportions, torso, chest, limbs, head-to-body balance and overall silhouette. "
				+ "Make this the most developed physical form of the same individual while preserving its recognizable identity. "
				+ "Do not add unrelated anatomy just to make it look more evolved. "
				+ "Allow a new natural pose. The final development must read through the body and accumulated Gene traits, not camera zoom or extra effects."
			)
		_:
			return ""

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
