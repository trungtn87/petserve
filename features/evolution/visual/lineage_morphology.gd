extends RefCounted

# Versioned deterministic visual genome. Never uses global random state.
const VERSION := 2
const FRAMES := [
	[1.15, 0.88, 1.10, "compact deep frame"],
	[1.35, 1.15, 0.90, "tall light frame"],
	[1.65, 0.98, 0.94, "long flexible frame"],
	[1.42, 1.06, 1.06, "balanced athletic frame"],
]
const FACES := ["rounded forehead and short muzzle", "tapered cheeks and a small distinct muzzle", "broad cheek planes and a soft jaw", "narrow cheek planes and a rounded brow"]
const FUR_LINES := ["rounded separate fur clumps", "smooth directional fur contours", "layered tapered fur contours", "soft flowing curved fur locks"]
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
	var rng := RandomNumberGenerator.new()
	rng.seed = identity.lineage_seed() + identity.generation() * 104729
	var frame: Array = FRAMES[rng.randi_range(0, FRAMES.size() - 1)]
	return {
		"version": VERSION,
		"frame": frame[3],
		"torso": float(frame[0]) + rng.randf_range(-0.07, 0.07),
		"legs": float(frame[1]) + rng.randf_range(-0.06, 0.06),
		"chest": float(frame[2]) + rng.randf_range(-0.06, 0.06),
		"tail": rng.randf_range(0.80, 1.30),
		"ears": rng.randf_range(0.85, 1.20),
		"face": FACES[rng.randi_range(0, FACES.size() - 1)],
		"fur_line": FUR_LINES[rng.randi_range(0, FUR_LINES.size() - 1)],
		"pose": POSES[rng.randi_range(0, POSES.size() - 1)],
		"side": "left" if rng.randi_range(0, 1) == 0 else "right",
		"response": rng.randf_range(0.88, 1.12),
	}

func resolve(identity: PetIdentity, stage: int, scores: Dictionary) -> Dictionary:
	var result := profile(identity)
	var age := clampi(stage, 1, 5) - 1
	result["torso"] = float(result.torso) + age * 0.14
	result["legs"] = float(result.legs) + age * 0.13
	result["chest"] = float(result.chest) + age * 0.09
	var allowance: float = [0.0, 0.0, 0.55, 0.80, 1.0, 1.15][clampi(stage, 1, 5)]
	var keys: Array = scores.keys()
	keys.sort()
	for key in keys:
		if not EFFECTS.has(String(key)):
			continue
		var effect: Array = EFFECTS[String(key)]
		var strength := minf(1.5, maxf(0.0, float(scores[key])) / 100.0) * float(allowance) * float(result.response)
		result["torso"] = float(result.torso) + float(effect[0]) * strength
		result["legs"] = float(result.legs) + float(effect[1]) * strength
		result["chest"] = float(result.chest) + float(effect[2]) * strength
	result["torso"] = clampf(float(result.torso), 0.95, 3.0)
	result["legs"] = clampf(float(result.legs), 0.70, 2.5)
	result["chest"] = clampf(float(result.chest), 0.70, 2.2)
	result["tail"] = clampf(float(result.tail) + minf(1.0, float(scores.get("tail.long", 0.0)) / 160.0) * float(allowance), 0.7, 2.3)
	result["ears"] = clampf(float(result.ears) + minf(0.7, float(scores.get("ears.long", 0.0)) / 200.0) * float(allowance), 0.7, 1.9)
	result["tail_width"] = 0.18 + minf(1.0, float(scores.get("tail.fluffy", 0.0)) / 160.0) * allowance * 0.65
	result["ear_roundness"] = minf(1.0, float(scores.get("ears.rounded", 0.0)) / 80.0) * minf(1.0, allowance)
	result["ear_fan_width"] = 1.0 + minf(1.0, float(scores.get("ears.softfan", 0.0)) / 100.0) * allowance * 0.70
	var mane_score := 0.0
	for key in keys:
		if String(key).begins_with("mane."):
			mane_score = maxf(mane_score, float(scores[key]))
	result["mane_width"] = 1.0 + minf(1.3, mane_score / 100.0) * allowance * 0.70
	result["stage"] = clampi(stage, 1, 5)
	return result

func build(identity: PetIdentity, stage: int, scores: Dictionary = {}) -> String:
	var p := resolve(identity, stage, scores)
	var focus := "whole-body silhouette"
	var best := 0.0
	var keys: Array = scores.keys()
	keys.sort()
	for key in keys:
		var locus := String(key).get_slice(".", 0)
		if locus not in ["body", "structure", "tail", "mane", "paws", "ears", "fur"]:
			continue
		var score := float(scores[key])
		if score > best:
			best = score
			focus = locus
	var pose := String(p.pose)
	match focus:
		"tail":
			pose = "side three-quarter standing view, entire tail sweeping outside the torso outline"
		"paws":
			pose = "three-quarter walking step, one front paw advanced and readable, no crossed legs"
		"mane":
			pose = "three-quarter upright quadruped stance, chest raised and ruff separated from the face"
		"body", "structure":
			pose = "three-quarter standing stance, clear shoulder, ribcage, waist and hindquarter contours"
		_:
			pose += ", three-quarter full-body view with head turned toward the viewer"
	return (
		"\n\n[INDIVIDUAL MORPHOLOGY V1]\n"
		+ "Inherited frame: %s; face: %s; fur contour language: %s. These are stable ancestry cues, not a frozen infant body.\n"
		+ "Target Stage %d: %s\n"
		+ "Use approximate design ratios, not text labels: torso length/head width %.2f; standing leg length/head height %.2f; chest width/head width %.2f; tail length/torso length %.2f; ear length relative to species baseline %.2f.\n"
		+ "Gene emphasis: %s. Present from the %s: %s. Separate limbs, ears and authorized tail from the body outline; never hide the focal feature behind the torso.\n"
		+ "Preserve individual facial recognition and elemental palette, not exact previous proportions or pose. Natural maturation is authorized even without new Genes. Apply scored Genes to this inherited frame, rather than replacing it with a generic breed template. Structural traits must read in silhouette without glow. Keep pupils readable. Do not substitute bloom, recoloring or camera zoom for bodily development. Species and code-authorized mythical anatomy take precedence over baseline ratios."
	) % [p.frame, p.face, p.fur_line, p.stage, STAGES[int(p.stage)], p.torso, p.legs, p.chest, p.tail, p.ears, focus, p.side, pose]
