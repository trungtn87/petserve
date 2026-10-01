extends RefCounted

const Morphology = preload("res://features/evolution/visual/lineage_morphology.gd")
const PALETTES := {
	"wood": "cream and warm brown fur, fresh green organic accents",
	"water": "pearl white and aqua fur, turquoise organic accents",
	"fire": "cream and peach fur, orange and ember accents",
	"earth": "beige and warm brown fur, mineral accents",
	"metal": "silver white fur, cool blue metallic highlights",
	"light": "ivory fur, soft gold accents",
	"dark": "charcoal indigo fur, muted violet and cyan accents",
}
const STRUCTURAL := ["body", "structure", "ears", "tail", "mane", "fur", "paws"]

func build(identity: PetIdentity, stage: int, scores: Dictionary, mythic: Dictionary = {}) -> String:
	var morphology := Morphology.new()
	var form: Dictionary = morphology.resolve(identity, stage, scores)
	var traits := resolve_traits(identity, stage, scores)
	var pose := "three-quarter standing view, body turned 45 degrees, head gently facing the viewer"
	var focus := "whole body"
	if not traits.is_empty():
		focus = String(traits[0].locus)
	match focus:
		"tail":
			pose = "near-side profile at 60 degrees, head turned toward viewer, entire tail extended sideways clear of the torso"
		"mane", "body", "structure":
			pose = "three-quarter standing view at 45 degrees, visible chest depth, flank and separated front and rear legs"
		"paws":
			pose = "three-quarter walking step, nearer front paw advanced, all four limbs anatomically distinct"
		"ears":
			pose = "body turned 45 degrees and face turned slightly toward viewer, both ear outlines unobscured"
	var lines: Array[String] = [
		"TARGET IMAGE: one %s, Stage %d. %s. View from the %s. Inherited posture character: %s. Avoid a symmetrical frontal portrait." % [identity.species(), stage, pose, form.side, form.pose],
		"AGE AND BODY: " + Morphology.STAGES[clampi(stage, 1, 5)],
	]
	if stage > 1:
		lines.append("Draw the complete target form described below. If a reference is supplied, use it for face and color recognition; replace its pose and immature proportions with this target. Visible bodily maturation is required even without new Genes.")
	var features: Array[String] = []
	for feature in traits:
		features.append(String(feature.text))
	if not features.is_empty():
		lines.append("PRIORITY FEATURES: " + " | ".join(features.slice(0, mini(3, features.size()))))
	lines.append("INDIVIDUAL FRAME: %s; %s; %s. Approximate silhouette ratios: torso/head-width %.2f, legs/head-height %.2f, chest/head-width %.2f. Keep this inherited long or compact frame rather than substituting a generic breed." % [form.frame, form.face, form.fur_line, form.torso, form.legs, form.chest])
	if features.size() > 3:
		lines.append("SUPPORTING FEATURES: " + " | ".join(features.slice(3)))
	var mythic_active := String(mythic.get("mode", "none")) in ["awaken", "continue"]
	if mythic_active:
		lines.append("AUTHORIZED MYTHIC ANATOMY: " + String(mythic.get("prompt", "")) + " " + String(mythic.get("preserve_hint", "")))
	else:
		lines.append(
			"Anatomy: "
			+ _species_anatomy(
				identity.species()
			)
			+ " Facial recognition and element remain stable while age, proportions and authorized Gene shapes develop."
		)
	lines.append("STYLE: polished stylized 3D fantasy pet illustration, clean shading and readable fur masses. Palette: %s. Use sparse organic elemental cues; do not pre-build a large decorative collar or replace Gene anatomy with leaves, armor or glow. Keep pupils visible." % PALETTES.get(String(identity.element()), "coherent elemental colors"))
	lines.append("SCENE: uncluttered natural %s-element environment, vertical 9:16, full body and tail within frame, calm upper area for UI. Separate the important contours from the background. No text or watermark. Differences must read in body shape, not camera zoom or bloom." % identity.element())
	return "\n\n".join(lines)

func resolve_traits(identity: PetIdentity, stage: int, scores: Dictionary) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for gene in GeneCatalog.new().load_default():
		if not gene.is_element_compatible(identity.element()):
			continue
		var score := maxf(0.0, float(scores.get("%s.%s" % [gene.locus(), gene.direction()], 0.0)))
		if score == 0.0:
			continue
		var locus := String(gene.locus())
		if not grouped.has(locus):
			grouped[locus] = []
		grouped[locus].append({"id": String(gene.id()), "direction": String(gene.direction()), "score": score, "stem": gene.prompt_stem()})
	var dimensions: Dictionary = Morphology.new().resolve(identity, stage, scores)
	var result: Array[Dictionary] = []
	for locus in grouped:
		var rows: Array = grouped[locus]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score) if not is_equal_approx(float(a.score), float(b.score)) else String(a.id) < String(b.id))
		var lead: Dictionary = rows[0]
		var directions: Array[String] = []
		for row in rows:
			directions.append(String(row.direction))
		var detail := String(lead.stem)
		if locus == "ears":
			# Resolve competing outline instructions to a single concrete target.
			var outline := "tapered" if lead.direction != "rounded" else "broad with smoothly rounded tips"
			if lead.direction == "softfan":
				outline = "broad fan-shaped"
			detail = "Ears: %s outline" % outline
			if directions.has("softfan"):
				detail += ", three separated fan tufts on each outer rim"
			if directions.has("tufted"):
				detail += ", swept terminal fur tufts"
			if directions.has("long"):
				detail += ", elongated ear blades"
		elif locus == "tail":
			detail = "Tail: " + String(lead.stem)
			if directions.has("fluffy") and lead.direction != "fluffy":
				detail += ", with a broad plume envelope"
			if directions.has("curved") and lead.direction != "curved":
				detail += ", following a continuous S-curve"
			if directions.has("tipped") and lead.direction != "tipped":
				detail += ", with a distinct terminal brush and color block"
			if directions.has("long") and lead.direction != "long":
				detail += ", with an elongated sweep"
		else:
			# Describe a single primary shape; secondary directions are subordinate accents.
			for index in range(1, rows.size()):
				detail += "; subordinate detail at %.0f%% of primary emphasis: %s" % [minf(75.0, float(rows[index].score) / float(lead.score) * 75.0), rows[index].stem]
		if locus == "ears":
			detail += "; ear fan width %.2fx baseline; tip roundness %.2f on a 0-pointed to 1-rounded scale" % [dimensions.ear_fan_width, dimensions.ear_roundness]
		elif locus == "tail":
			detail += "; plume width approximately %.2f of torso length" % dimensions.tail_width
		elif locus == "mane":
			detail += "; ruff width %.2fx chest width, visibly separate pointed locks rather than a flat glowing collar" % dimensions.mane_width
		var amount: float = minf(1.5, float(lead.score) / 100.0) * [0.0, 0.0, 0.55, 0.80, 1.0, 1.15][clampi(stage, 1, 5)]
		var strength := "small but readable" if amount < 0.25 else "clearly developed"
		if amount >= 0.65:
			strength = "large defining silhouette feature" if STRUCTURAL.has(locus) else "clear localized visual feature"
		result.append({"locus": locus, "score": float(lead.score), "text": "%s (%s)." % [detail, strength]})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if STRUCTURAL.has(a.locus) != STRUCTURAL.has(b.locus):
			return STRUCTURAL.has(a.locus)
		return float(a.score) > float(b.score) if not is_equal_approx(float(a.score), float(b.score)) else String(a.locus) < String(b.locus))
	return result


func _species_anatomy(
	species: StringName
) -> String:
	match species:
		&"bird":
			return "one bird head, two legs, exactly one pair of wings and one tail-feather assembly; no horns or extra wings."
		&"phoenix":
			return "one phoenix head, two legs, exactly one pair of wings and one decorative tail-feather assembly."
		&"lizard":
			return "one reptilian head, four legs and exactly one tail; no wings unless explicitly authorized."
		&"dragon":
			return "one dragon head, four legs and exactly one tail; one wing pair is allowed only when already established by code-selected anatomy."
		&"horse":
			return "one horse head, two ears, four hoofed legs and exactly one tail; no horns, antlers or wings unless explicitly authorized."
		&"qilin":
			return "one qilin head, two ears, four hoofed legs, one tail and one coherent sacred horn plan."
		&"deer":
			return "one deer head, two ears, four fine legs, one short tail and at most one symmetrical antler pair."
		&"cat", &"dog", &"fox", &"bear", &"rabbit":
			return "one head, four natural legs, two species-appropriate ears and exactly one tail; no horns or wings."
		_:
			return "one head, species-appropriate limbs and authorized appendages only; no unrelated anatomy."
