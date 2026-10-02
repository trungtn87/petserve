extends RefCounted

# Versioned deterministic visual genome. Never uses global random state.
const VERSION := 4
const SpeciesExpression = preload("res://features/evolution/visual/species_gene_expression.gd")
# V1 from 47d8688, calibrated per species. Baselines: torso/head width,
# leg/head height, chest/head width, tail/torso, ears/species baseline.
# Growth and Gene response are bounded relative to each species, never feline defaults.
const SPECIES := {
	"cat": {"base": [1.42, 1.02, 1.02, 0.95, 1.0], "growth": [0.14, 0.13, 0.09], "response": [1.0, 1.0, 1.0], "tail_max": 1.65, "ears_max": 1.55, "surface": "plush feline fur", "face": "short feline muzzle"},
	"dog": {"base": [1.55, 1.10, 1.08, 0.70, 1.0], "growth": [0.15, 0.14, 0.10], "response": [1.0, 1.0, 1.0], "tail_max": 1.25, "ears_max": 1.65, "surface": "layered canine coat", "face": "young canine muzzle"},
	"fox": {"base": [1.65, 1.14, 0.88, 1.05, 1.0], "growth": [0.16, 0.14, 0.07], "response": [1.1, 1.0, 0.7], "tail_max": 1.75, "ears_max": 1.50, "surface": "tapered fox fur", "face": "narrow fox muzzle"},
	"bear": {"base": [1.42, 0.70, 1.35, 0.12, 1.0], "growth": [0.12, 0.07, 0.13], "response": [0.65, 0.55, 1.1], "tail_max": 0.25, "ears_max": 1.25, "surface": "dense bear fur", "face": "broad bear muzzle and rounded ears"},
	"rabbit": {"base": [1.30, 0.65, 0.95, 0.15, 1.0], "growth": [0.10, 0.07, 0.07], "response": [0.65, 0.55, 0.7], "tail_max": 0.30, "ears_max": 1.80, "surface": "soft rabbit fur", "face": "rounded rabbit cheeks and two long ears"},
	"lizard": {"base": [2.00, 0.45, 0.78, 1.30, 0.0], "growth": [0.20, 0.04, 0.06], "response": [1.2, 0.25, 0.65], "tail_max": 2.0, "ears_max": 0.0, "surface": "smooth juvenile scales", "face": "reptilian jaw and brow without external ears"},
	"bird": {"base": [1.12, 0.65, 0.95, 0.55, 0.0], "growth": [0.08, 0.07, 0.07], "response": [0.45, 0.5, 0.65], "tail_max": 1.30, "ears_max": 0.0, "surface": "layered feathers", "face": "avian brow and short beak without external ears"},
	"dragon": {"base": [1.80, 0.85, 1.02, 1.20, 0.0], "growth": [0.19, 0.10, 0.11], "response": [1.1, 0.75, 1.0], "tail_max": 1.90, "ears_max": 0.0, "surface": "juvenile dragon scales", "face": "dragon jaw and brow ridges without mammalian ears"},
	"phoenix": {"base": [1.30, 0.85, 0.98, 0.95, 0.0], "growth": [0.12, 0.09, 0.08], "response": [0.7, 0.6, 0.7], "tail_max": 2.0, "ears_max": 0.0, "surface": "flowing phoenix plumage", "face": "noble beak and small crown crest without external ears"},
	"horse": {"base": [1.85, 1.70, 0.98, 0.75, 1.0], "growth": [0.16, 0.16, 0.10], "response": [0.85, 0.75, 0.8], "tail_max": 1.25, "ears_max": 1.35, "surface": "smooth equine coat and natural mane", "face": "elongated equine muzzle"},
	"qilin": {"base": [1.70, 1.50, 0.98, 0.90, 1.0], "growth": [0.15, 0.15, 0.10], "response": [0.85, 0.75, 0.8], "tail_max": 1.45, "ears_max": 1.35, "surface": "fine coat, cloud mane and sparse native scales", "face": "refined sacred-beast muzzle and inherited horn plan"},
	"deer": {"base": [1.62, 1.65, 0.82, 0.16, 1.0], "growth": [0.14, 0.17, 0.07], "response": [0.8, 0.8, 0.6], "tail_max": 0.32, "ears_max": 1.45, "surface": "short cervid coat", "face": "small cervid muzzle and soft ears"},
}
const FRAME_KEYS := ["compact_grounded", "tall_light", "long_flexible", "balanced_athletic"]
const FRAMES := [
	[1.15, 0.88, 1.10, "compact deep frame"],
	[1.35, 1.15, 0.90, "tall light frame"],
	[1.65, 0.98, 0.94, "long flexible frame"],
	[1.42, 1.06, 1.06, "balanced athletic frame"],
]
const FACES := ["rounded youthful forehead", "tapered cheek planes", "broad calm facial planes", "narrow cheek planes and a rounded brow"]
const SURFACE_LINES := ["rounded separate native surface masses", "smooth directional contours", "layered tapered contours", "soft flowing curved surface rhythm"]
const POSES := ["curious forward step", "calm planted stance", "alert poised step", "proud elevated chest"]
const EFFECTS := {
	"body.sturdy": [0.10, 0.02, 0.34],
	"body.agile": [0.22, 0.15, 0.04],
	"body.slender": [0.35, 0.17, -0.10],
	"body.compact": [-0.15, -0.12, 0.18],
	"body.regal": [0.12, 0.22, 0.12],
	"structure.guardian": [0.06, 0.02, 0.25],
	"structure.elegant": [0.20, 0.20, -0.06],
	"structure.feral": [0.18, 0.12, 0.08],
	"structure.ancient": [0.10, 0.12, 0.20],
	"structure.spirit": [0.15, 0.16, -0.04],
}
const STAGES := [
	"",
	"Infant: soft juvenile body; individual frame already visible; sparse details, small undeveloped ruff.",
	"Juvenile: clearly longer torso and legs relative to the head; first Gene-driven silhouette changes, distinct tail and chest outline.",
	"Adolescent: a visibly differentiated silhouette, developed chest and limbs; selected structural Genes must change outline, not merely add glow.",
	"Mature: full chest, confident weight-bearing limbs, developed neck and strongly organized fur masses; clearly beyond the adolescent body.",
	"Final: complete lineage form with fully resolved proportions and coherent signature structures; no new unearned appendages or generic accessory pile.",
]

func profile(identity: PetIdentity) -> Dictionary:
	if identity == null or not identity.is_valid():
		return {}
	var config: Dictionary = SPECIES.get(String(identity.species()), SPECIES.cat)
	var base: Array = config.base
	var rng := RandomNumberGenerator.new()
	rng.seed = identity.lineage_seed() + identity.generation() * 104729
	var frame_index := rng.randi_range(0, FRAMES.size() - 1)
	var frame: Array = FRAMES[frame_index]
	var face: String = String(config.face) + "; " + FACES[rng.randi_range(0, FACES.size() - 1)]
	if float(base[4]) == 0.0:
		face = String(config.face) + "; " + ["rounded youthful brow", "tapered cheek planes", "broad calm brow", "narrow alert brow"][rng.randi_range(0, 3)]
	var surface: String = String(config.surface) + "; " + String(SURFACE_LINES[rng.randi_range(0, SURFACE_LINES.size() - 1)])
	var pose := String(POSES[rng.randi_range(0, POSES.size() - 1)])
	return {
		"version": VERSION, "species": String(identity.species()),
		"frame": frame[3], "frame_key": FRAME_KEYS[frame_index],
		"torso": float(base[0]) * float(frame[0]) / 1.42 * rng.randf_range(0.95, 1.05),
		"legs": float(base[1]) * float(frame[1]) / 1.06 * rng.randf_range(0.95, 1.05),
		"chest": float(base[2]) * float(frame[2]) / 1.06 * rng.randf_range(0.95, 1.05),
		"tail": float(base[3]) * rng.randf_range(0.85, 1.15),
		"ears": float(base[4]) * rng.randf_range(0.85, 1.20),
		"face": face, "head_character": face,
		"fur_line": surface, "surface_flow": surface,
		"appendage_character": ["compact and tidy", "long and flowing", "broad and soft", "clean and tapered"][rng.randi_range(0, 3)],
		"temperament": ["curious", "calm", "alert", "proud"][rng.randi_range(0, 3)],
		"expression_bias": ["balanced_response", "length_before_bulk", "bulk_before_length", "flow_before_width"][rng.randi_range(0, 3)],
		"pose": pose,
		"side": "left" if rng.randi_range(0, 1) == 0 else "right",
		"response": rng.randf_range(0.88, 1.12),
	}

func resolve(identity: PetIdentity, stage: int, scores: Dictionary) -> Dictionary:
	var result := profile(identity)
	if result.is_empty():
		return {}
	var config: Dictionary = SPECIES.get(String(identity.species()), SPECIES.cat)
	var base: Array = config.base
	var growth: Array = config.growth
	var response: Array = config.response
	var age := clampi(stage, 1, 5) - 1
	result["torso"] = float(result.torso) + age * float(growth[0])
	result["legs"] = float(result.legs) + age * float(growth[1])
	result["chest"] = float(result.chest) + age * float(growth[2])
	var allowance: float = [0.0, 0.0, 0.55, 0.80, 1.0, 1.15][clampi(stage, 1, 5)]
	var keys: Array = scores.keys()
	keys.sort()
	for key in keys:
		if not EFFECTS.has(String(key)):
			continue
		var effect: Array = EFFECTS[String(key)]
		var strength := minf(1.5, maxf(0.0, float(scores[key])) / 100.0) * float(allowance) * float(result.response)
		result["torso"] = float(result.torso) + float(effect[0]) * strength * float(response[0])
		result["legs"] = float(result.legs) + float(effect[1]) * strength * float(response[1])
		result["chest"] = float(result.chest) + float(effect[2]) * strength * float(response[2])
	result["torso"] = clampf(float(result.torso), float(base[0]) * 0.65, float(base[0]) * 2.1)
	result["legs"] = clampf(float(result.legs), float(base[1]) * 0.65, float(base[1]) * 2.1)
	result["chest"] = clampf(float(result.chest), float(base[2]) * 0.65, float(base[2]) * 2.1)
	result["tail"] = clampf(float(result.tail) + float(base[3]) * minf(0.65, maxf(0.0, float(scores.get("tail.long", 0.0))) / 160.0) * float(allowance), float(base[3]) * 0.65, float(config.tail_max))
	result["ears"] = clampf(float(result.ears) + float(base[4]) * minf(0.7, maxf(0.0, float(scores.get("ears.long", 0.0))) / 200.0) * float(allowance), float(base[4]) * 0.7, float(config.ears_max))
	result["stage"] = clampi(stage, 1, 5)
	return result

func stage_description(identity: PetIdentity, stage: int) -> String:
	var family := SpeciesExpression.new().family_for(identity.species())
	var milestones: Array
	match family:
		SpeciesExpression.FAMILY_AVIAN:
			milestones = ["downy chick with compact breast and tucked juvenile wings", "juvenile with longer neck, stronger legs and emerging flight-feather outline", "adolescent with developed breast, layered wing feathers and distinct tail assembly", "mature bird with confident carriage, resolved wing contour and organized plumage", "complete lineage with refined species-native crest, wing and tail plumage"]
		SpeciesExpression.FAMILY_REPTILE:
			milestones = ["small hatchling with soft juvenile scales and low limbs", "juvenile with longer torso and tail, firmer limbs and clearer scale contours", "adolescent with developed shoulders, neck and distinct dorsal contour", "mature reptile with confident support and organized native scale masses", "complete lineage with coherent scale contours and only authorized mythical structures"]
		SpeciesExpression.FAMILY_HOOFED:
			milestones = ["young foal or fawn with fine legs and small youthful chest", "juvenile with developed neck, longer limbs and growing chest", "adolescent with defined shoulder, flank and stronger hoof support", "mature hoofed beast with confident weight-bearing legs and developed neck", "complete lineage with graceful resolved hoofed proportions and only authorized horn or antler plan"]
		_:
			milestones = ["soft infant with small body, youthful head and undeveloped coat", "juvenile with longer torso and legs, less oversized head and first distinct chest and tail outline", "adolescent with differentiated shoulders, limbs, chest and species-native coat contours", "mature animal with full chest, confident limbs and organized coat masses", "complete lineage with resolved proportions and coherent signature contours"]
	return "Stage %d: %s. Structural Genes change outline; glow and camera zoom cannot replace maturation." % [clampi(stage, 1, 5), milestones[clampi(stage, 1, 5) - 1]]

func build(identity: PetIdentity, stage: int, scores: Dictionary = {}) -> String:
	var p := resolve(identity, stage, scores)
	if p.is_empty():
		return ""
	var focus := "whole-body silhouette"
	var best := 0.0
	var keys: Array = scores.keys()
	keys.sort()
	for key in keys:
		var locus := String(key).get_slice(".", 0)
		if locus not in ["body", "structure", "tail", "mane", "paws", "ears", "fur"]:
			continue
		if float(scores[key]) > best:
			best = float(scores[key])
			focus = locus
	var adapter := SpeciesExpression.new()
	var pose := adapter.pose_hint(identity.species(), focus, String(p.temperament))
	var proportions := "Approximate design ratios, never text labels: torso/head width %.2f; supporting leg/head height %.2f; chest/head width %.2f; native tail assembly/torso %.2f." % [p.torso, p.legs, p.chest, p.tail]
	if float(p.ears) > 0.0:
		proportions += " Ear length relative to this species baseline %.2f." % p.ears
	return (
		"\n\n[INDIVIDUAL MORPHOLOGY V4 — 47d8688 species adaptation]\n"
		+ "Inherited frame: %s; face: %s; native surface: %s. Stable ancestry cues, never a frozen infant body.\n"
		+ "%s\n%s\n"
		+ "Gene emphasis: %s. Present from the %s: %s. Keep the focal feature clear outside the torso outline.\n"
		+ "Preserve face recognition and elemental palette while changing proportions and pose through maturation. "
		+ "Apply scored Genes to the inherited frame. Species anatomy and code-authorized mutations take precedence over approximate ratios: %s."
	) % [p.frame, p.face, p.fur_line, stage_description(identity, stage), proportions, focus, p.side, pose, adapter.anatomy(identity.species())]
