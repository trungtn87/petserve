extends RefCounted

const Morphology = preload(
	"res://features/evolution/visual/lineage_morphology.gd"
)
const SpeciesExpression = preload(
	"res://features/evolution/visual/species_gene_expression.gd"
)

const PALETTES := {
	"wood": "cream and warm brown with fresh green organic accents",
	"water": "pearl white and aqua with turquoise organic accents",
	"fire": "cream and peach with orange and ember accents",
	"earth": "beige and warm brown with restrained mineral accents",
	"metal": "silver white with cool blue metallic highlights",
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

	var target_stage := clampi(
		stage,
		1,
		5
	)
	var morphology := Morphology.new()
	var form := morphology.resolve(
		identity,
		target_stage,
		scores
	)

	if form.is_empty():
		return ""

	var adapter := SpeciesExpression.new()
	var traits := resolve_traits(
		identity,
		target_stage,
		scores
	)
	var focus := "whole body"

	if not traits.is_empty():
		focus = String(
			traits[0].get(
				"locus",
				"whole body"
			)
		)

	var pose := adapter.pose_hint(
		identity.species(),
		focus,
		String(
			form.get(
				"temperament",
				"calm"
			)
		)
	)

	var lines: Array[String] = [
		(
			"TARGET: the same individual %s at Stage %d. %s."
			% [
				String(
					identity.species()
				),
				target_stage,
				pose,
			]
		),
		(
			"SUBJECT SCALE: the pet is the unmistakable main subject, shown as one complete full body at a medium-close environmental distance. Target visible pet height is about 50 to 56 percent of the 9:16 canvas, roughly 30 percent larger on screen than the old PetHome framing. Keep ears, feet, tail and authorized appendages inside frame. Do not shrink the pet to showcase the scenery."
		),
		(
			"SPECIES LOCK: %s. Keep the species immediately recognizable. A Gene may change emphasis inside this anatomy, but must never turn the pet into another species or add unrelated anatomy."
			% adapter.anatomy(
				identity.species()
			)
		),
		(
			"ELEMENT EMBODIMENT: %s The element must be clearly readable on the creature itself at first glance, even if the background is ignored. Express it through anatomy-safe surface materials, color zones, markings, coat/plumage/scale flow and small body-integrated magical accents; never rely on the environment alone."
			% _element_embodiment(
				identity.element()
			)
		),
		(
			"INHERITED INDIVIDUAL: %s"
			% adapter.birth_expression(
				identity.species(),
				form
			)
		),
		(
			"MATURATION: %s"
			% Morphology.STAGES[
				target_stage
			]
		),
		(
			"INDIVIDUAL RESPONSE: %s"
			% adapter.response_hint(
				form
			)
		),
	]

	if target_stage > 1:
		lines.append(
			"REFERENCE CONTINUITY: if a previous-stage image is supplied, preserve face identity, elemental palette and established lineage cues. Allow natural maturation and the selected development priorities to change pose and form; do not trace immature proportions exactly."
		)

	if not traits.is_empty():
		var priorities: Array[String] = []
		var limit := mini(
			3,
			traits.size()
		)

		for index in range(
			limit
		):
			priorities.append(
				"%d) %s"
				% [
					index + 1,
					String(
						traits[index].get(
							"text",
							""
						)
					),
				]
			)

		lines.append(
			"DEVELOPMENT PRIORITIES — only these are strong visual priorities in this render: "
			+ " ".join(
				priorities
			)
		)

		if traits.size() > limit:
			lines.append(
				"Other accumulated Gene scores remain supporting lineage information for later development; do not force every scored Gene into a large visible change at once."
			)
	else:
		lines.append(
			"No strong Gene-directed feature is required in this render. Show clear natural maturation of the inherited individual instead."
		)

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
			(
				"AUTHORIZED MYTHIC ANATOMY: %s %s This is the only permission for anatomy beyond the species lock."
				% [
					String(
						mythic.get(
							"prompt",
							""
						)
					),
					String(
						mythic.get(
							"preserve_hint",
							""
						)
					),
				]
			).strip_edges()
		)

	lines.append(
		(
			"STYLE: polished stylized 3D fantasy pet illustration with clean shading and species-appropriate fur, plumage, scales or coat surface. Palette: %s. Make the elemental identity clearly visible on the pet itself while keeping effects controlled, body-integrated and secondary to readable anatomy. Keep eyes and pupils readable."
			% PALETTES.get(
				String(
					identity.element()
				),
				"coherent elemental colors"
			)
		)
	)

	lines.append(
		(
			"SCENE: uncluttered natural %s-element environment, vertical 9:16, full body and authorized appendages inside frame, calm upper area for UI. The habitat supports the pet but stays visually secondary; the creature must dominate the composition and must already communicate its element without the scenery. Use pose and camera only to reveal the selected form. No text or watermark."
			% String(
				identity.element()
			)
		)
	)

	return "\n\n".join(
		lines
	)


func _element_embodiment(
	element: StringName
) -> String:
	match element:
		&"water":
			return (
				"Use pearl-white, aqua and turquoise surface accents on the pet; flowing current-like contour rhythm in mane, fur, feathers or fins already allowed by the species; ripple-like markings, moist reflective highlights and a few translucent droplet accents close to the body. Keep it elegant and clearly Water, never merely a normal animal standing beside water."
			)
		&"fire":
			return (
				"Use cream, peach, orange and ember accents on the pet; swept flame-like surface flow, warm luminous markings and small controlled living-flame highlights on existing tips or contours. Keep the creature readable and natural, never an uncontrolled fire blob."
			)
		&"wood":
			return (
				"Use warm cream, brown and fresh green accents on the pet; leaf-like surface tufts, vine or vein markings and tiny living sprout cues integrated into existing coat, plumage or scales. Keep botanical growth light and body-integrated, never a pile of plants."
			)
		&"earth":
			return (
				"Use beige, warm brown and restrained mineral accents on the pet; grounded heavier surface rhythm, stone-grain markings and a few small polished crystal or mineral seams integrated into existing body surfaces. Never turn the creature into a statue or armor."
			)
		&"metal":
			return (
				"Use silver-white, cool gray and icy-blue accents on the pet; crisp reflective highlights, geometric surface separations and a few small polished metallic or crystal facets integrated into existing body surfaces. Keep it organic, never mechanical armor."
			)
		&"light":
			return (
				"Use ivory, pearl and soft gold accents on the pet; clean radiant markings, luminous edge highlights and a restrained halo-like glow hugging the existing silhouette. Keep it elegant and clearly Light without adding wings or angelic anatomy."
			)
		&"dark":
			return (
				"Use charcoal-indigo, muted violet and restrained cyan accents on the pet; shadow-gradient markings, faint astral or crescent motifs and soft mist close to existing contours. Keep it mysterious and clearly Umbral without random spikes, horns or galaxy texture."
			)
		_:
			return "Use a clear, body-integrated elemental signature on the creature."



func resolve_traits(
	identity: PetIdentity,
	stage: int,
	scores: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if identity == null or not identity.is_valid():
		return result

	var adapter := SpeciesExpression.new()
	var grouped: Dictionary = {}

	for gene in GeneCatalog.new().load_default():
		if (
			gene == null
			or not gene.is_element_compatible(
				identity.element()
			)
		):
			continue

		var key := "%s.%s" % [
			String(
				gene.locus()
			),
			String(
				gene.direction()
			),
		]
		var score := maxf(
			0.0,
			float(
				scores.get(
					key,
					0.0
				)
			)
		)

		if score <= 0.0:
			continue

		var translated := adapter.translate(
			identity.species(),
			gene.locus(),
			gene.direction()
		)

		if translated.is_empty():
			continue

		var locus := String(
			gene.locus()
		)

		if not grouped.has(
			locus
		):
			grouped[locus] = []

		(grouped[locus] as Array).append({
			"id": String(
				gene.id()
			),
			"direction": String(
				gene.direction()
			),
			"score": score,
			"text": translated,
		})

	for locus_value in grouped.keys():
		var locus := String(
			locus_value
		)
		var rows: Array = grouped[
			locus_value
		]
		rows.sort_custom(
			_sort_gene_rows
		)

		if rows.is_empty():
			continue

		var lead := rows[0] as Dictionary
		var lead_score := float(
			lead.get(
				"score",
				0.0
			)
		)
		var text := String(
			lead.get(
				"text",
				""
			)
		)

		if rows.size() > 1:
			var secondary := rows[1] as Dictionary
			var secondary_score := float(
				secondary.get(
					"score",
					0.0
				)
			)

			if (
				lead_score > 0.0
				and secondary_score
					>= lead_score * 0.35
			):
				text += (
					" Secondary nuance: "
					+ String(
						secondary.get(
							"text",
							""
						)
					)
				)

		text += " " + _strength_instruction(
			lead_score,
			stage,
			adapter.is_structural_locus(
				locus
			)
		)

		result.append({
			"locus": locus,
			"score": lead_score,
			"structural": adapter.is_structural_locus(
				locus
			),
			"text": text.strip_edges(),
		})

	result.sort_custom(
		_sort_trait_rows
	)

	return result


func _strength_instruction(
	score: float,
	stage: int,
	structural: bool
) -> String:
	var target_stage := clampi(
		stage,
		1,
		5
	)
	var stage_factor: float = [
		0.0,
		0.0,
		0.55,
		0.80,
		1.0,
		1.15,
	][target_stage]
	var amount := minf(
		1.5,
		maxf(
			0.0,
			score
		) / 100.0
	) * stage_factor

	if amount < 0.25:
		return "Keep this as a subtle early trace."

	if amount < 0.65:
		return (
			"Make this clearly readable in the species silhouette."
			if structural
			else "Make this clearly readable but localized."
		)

	return (
		"Make this the main physical development direction while preserving natural species anatomy."
		if structural
		else "Make this a strong localized signature without hiding anatomy."
	)


func _sort_gene_rows(
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

	return String(
		a.get(
			"id",
			""
		)
	) < String(
		b.get(
			"id",
			""
		)
	)


func _sort_trait_rows(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var a_structural := bool(
		a.get(
			"structural",
			false
		)
	)
	var b_structural := bool(
		b.get(
			"structural",
			false
		)
	)

	if a_structural != b_structural:
		return a_structural

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

	return String(
		a.get(
			"locus",
			""
		)
	) < String(
		b.get(
			"locus",
			""
		)
	)
