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

	var target_stage := clampi(stage, 1, 5)
	var morphology := Morphology.new()
	var form := morphology.resolve(identity, target_stage, scores)
	if form.is_empty():
		return ""

	var adapter := SpeciesExpression.new()
	var traits := resolve_traits(identity, target_stage, scores)
	var focus := "whole body"
	if not traits.is_empty():
		focus = String(traits[0].get("locus", "whole body"))

	var pose := adapter.pose_hint(
		identity.species(),
		focus,
		String(form.get("temperament", "calm"))
	)

	var lines: Array[String] = [
		"TARGET IMAGE: one %s, Stage %d. %s. View from the %s. Avoid a symmetrical frontal portrait." % [
			String(identity.species()),
			target_stage,
			pose,
			String(form.get("side", "left")),
		],
		"AGE AND BODY: " + Morphology.STAGES[target_stage],
	]

	if target_stage > 1:
		lines.append(
			"Draw the complete target form described below. If a previous-stage reference is supplied, use it for face, markings and color recognition; allow the new stage to change pose and immature proportions. Visible natural maturation is required."
		)

	var features: Array[String] = []
	for feature in traits:
		features.append(String(feature.get("text", "")))
	if not features.is_empty():
		lines.append("PRIORITY FEATURES: " + " | ".join(features.slice(0, mini(3, features.size()))))

	lines.append(
		"INDIVIDUAL FRAME: %s; %s; %s. Approximate silhouette ratios: torso/head-width %.2f, legs/head-height %.2f, chest/head-width %.2f, tail/torso %.2f, ears/species-baseline %.2f. Keep this inherited frame rather than substituting a generic breed template." % [
			String(form.get("frame", "balanced frame")),
			String(form.get("face", "recognizable face")),
			String(form.get("fur_line", "clean surface contours")),
			float(form.get("torso", 1.0)),
			float(form.get("legs", 1.0)),
			float(form.get("chest", 1.0)),
			float(form.get("tail", 1.0)),
			float(form.get("ears", 1.0)),
		]
	)

	if features.size() > 3:
		lines.append("SUPPORTING FEATURES: " + " | ".join(features.slice(3)))

	var mythic_active := String(mythic.get("mode", "none")) in ["awaken", "continue"]
	if mythic_active:
		lines.append(
			"AUTHORIZED MYTHIC ANATOMY: "
			+ String(mythic.get("prompt", ""))
			+ " "
			+ String(mythic.get("preserve_hint", ""))
		)
	else:
		lines.append(
			"ANATOMY: "
			+ adapter.anatomy(identity.species())
			+ " Preserve species identity and existing authorized appendage count."
		)

	lines.append(
		"STYLE: polished stylized 3D fantasy pet illustration, clean shading and readable species-appropriate surface masses. Palette: %s. Keep elemental cues organic and controlled. Keep pupils readable." % PALETTES.get(String(identity.element()), "coherent elemental colors")
	)
	lines.append(
		"SCENE: simple uncluttered natural %s-element fantasy background. Vertical 9:16 mobile scene. The pet is the clear main subject, about 45 to 52 percent of image height in the lower-middle. Full body and authorized appendages visible. Keep the upper area calm for UI. No text or watermark. Differences between stages must read in body shape and selected Gene features, not camera zoom or bloom." % String(identity.element())
	)
	return "\n\n".join(lines)


func _element_embodiment(
	element: StringName
) -> String:
	match element:
		&"water":
			return (
				"Use clear pearl-white, aqua and turquoise body zones; flowing current-like contour rhythm in existing mane, coat, plumage or scales; readable ripple markings, moist reflective highlights and a few translucent droplet accents close to the body. The pet must look intrinsically Water, never like a normal animal merely standing beside water."
			)
		&"fire":
			return (
				"Use clear cream, peach, orange and ember body zones; swept flame-like surface flow, readable warm luminous markings and small controlled living-flame highlights on existing tips or contours. The pet must look intrinsically Fire while remaining species-safe, never an uncontrolled fire blob."
			)
		&"wood":
			return (
				"Use clear warm cream, brown and fresh-green body zones; leaf-like surface tufts, readable vine or vein markings and small living sprout cues integrated into existing coat, plumage or scales. The pet must look intrinsically Wood, never like a normal animal with loose leaves attached."
			)
		&"earth":
			return (
				"Use clear beige, warm-brown and mineral body zones; grounded heavier surface rhythm, readable stone-grain markings and a few polished crystal or mineral seams integrated into existing body surfaces. The pet must look intrinsically Earth without becoming a statue or armor."
			)
		&"metal":
			return (
				"Use clear silver-white, cool-gray and icy-blue body zones; crisp reflective highlights, readable geometric surface separations and a few polished metallic or crystal facets integrated into existing body surfaces. The pet must look intrinsically Metal while staying organic, never mechanical armor."
			)
		&"light":
			return (
				"Use clear ivory, pearl and soft-gold body zones; readable radiant markings, luminous edge highlights and a controlled halo-like glow hugging the existing silhouette. The pet must look intrinsically Light without adding wings or angelic anatomy."
			)
		&"dark":
			return (
				"Use clearly visible charcoal-indigo, smoky blue-black and muted-violet body zones with cyan-violet highlights; a readable crescent or astral sigil, shadow-gradient markings, luminous eye accents and controlled dark mist close to existing mane or ruff, tail and lower legs where anatomy allows. The pet must look intrinsically Umbral, never like a normal animal placed in a dark scene. Do not add random spikes, horns or galaxy texture."
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
