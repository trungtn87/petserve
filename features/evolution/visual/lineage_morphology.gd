extends RefCounted

# Deterministic individual morphology.
# V3 keeps the useful V1 idea (each life has a stable inherited frame), but
# does not expose hard numeric body ratios to the image model. Numeric values
# remain only as internal diagnostics/compatibility data.
const VERSION := 3

const SpeciesExpression = preload(
	"res://features/evolution/visual/species_gene_expression.gd"
)

const FRAMES := [
	[1.15, 0.88, 1.10, "compact grounded frame", "compact_grounded"],
	[1.35, 1.15, 0.90, "tall light frame", "tall_light"],
	[1.65, 0.98, 0.94, "long flexible frame", "long_flexible"],
	[1.42, 1.06, 1.06, "balanced athletic frame", "balanced_athletic"],
]

const HEAD_CHARACTERS := [
	"rounded youthful head impression",
	"refined tapered head impression",
	"broader calm facial planes",
	"narrow alert facial impression",
]

const SURFACE_FLOWS := [
	"soft separated surface masses",
	"smooth directional surface flow",
	"layered tapered surface flow",
	"soft flowing curved surface rhythm",
]

const APPENDAGE_CHARACTERS := [
	"compact and tidy",
	"long and flowing",
	"broad and soft",
	"clean and tapered",
]

const TEMPERAMENTS := [
	"curious",
	"alert",
	"proud",
	"calm",
	"playful",
]

const RESPONSE_BIASES := [
	"balanced_response",
	"length_before_bulk",
	"bulk_before_length",
	"flow_before_width",
	"surface_before_volume",
]

# Internal compatibility vectors. These are not sent to the image model.
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
	"Stage 1 — inherited juvenile form: keep the pet clearly young, simple and species-correct while letting its individual frame already read.",
	"Stage 2 — early development: natural maturation becomes visible and the strongest accumulated Gene direction begins to shape the body or feature.",
	"Stage 3 — differentiated adolescent form: the selected development direction is clearly readable, but the animal must still look anatomically natural for its species.",
	"Stage 4 — mature form: strengthen the established identity and the most important accumulated traits without redesigning every body region at once.",
	"Final — resolved individual form: finish the established lineage coherently; polish dominant traits instead of inventing new accessories or anatomy.",
]


func profile(
	identity: PetIdentity
) -> Dictionary:
	if identity == null or not identity.is_valid():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = (
		identity.lineage_seed()
		+ identity.generation() * 104729
	)

	var frame: Array = FRAMES[
		rng.randi_range(
			0,
			FRAMES.size() - 1
		)
	]

	var surface_flow := String(
		SURFACE_FLOWS[
			rng.randi_range(
				0,
				SURFACE_FLOWS.size() - 1
			)
		]
	)

	return {
		"version": VERSION,
		"frame": String(frame[3]),
		"frame_key": String(frame[4]),
		"torso": float(frame[0]) + rng.randf_range(-0.07, 0.07),
		"legs": float(frame[1]) + rng.randf_range(-0.06, 0.06),
		"chest": float(frame[2]) + rng.randf_range(-0.06, 0.06),
		"tail": rng.randf_range(0.80, 1.30),
		"ears": rng.randf_range(0.85, 1.20),
		"head_character": String(
			HEAD_CHARACTERS[
				rng.randi_range(
					0,
					HEAD_CHARACTERS.size() - 1
				)
			]
		),
		"face": String(
			HEAD_CHARACTERS[
				rng.randi_range(
					0,
					HEAD_CHARACTERS.size() - 1
				)
			]
		),
		"surface_flow": surface_flow,
		"surface_line": surface_flow,
		"fur_line": surface_flow,
		"appendage_character": String(
			APPENDAGE_CHARACTERS[
				rng.randi_range(
					0,
					APPENDAGE_CHARACTERS.size() - 1
				)
			]
		),
		"temperament": String(
			TEMPERAMENTS[
				rng.randi_range(
					0,
					TEMPERAMENTS.size() - 1
				)
			]
		),
		"expression_bias": String(
			RESPONSE_BIASES[
				rng.randi_range(
					0,
					RESPONSE_BIASES.size() - 1
				)
			]
		),
		"side": (
			"left"
			if rng.randi_range(0, 1) == 0
			else "right"
		),
		"response": rng.randf_range(0.88, 1.12),
		"ear_fan_width": rng.randf_range(0.88, 1.12),
		"ear_roundness": rng.randf_range(0.28, 0.72),
		"tail_width": rng.randf_range(0.20, 0.36),
		"mane_width": rng.randf_range(0.82, 1.12),
	}


func resolve(
	identity: PetIdentity,
	stage: int,
	scores: Dictionary
) -> Dictionary:
	var result := profile(
		identity
	)

	if result.is_empty():
		return {}

	var target_stage := clampi(
		stage,
		1,
		5
	)
	var age := target_stage - 1

	# Internal progression only. The prompt layer intentionally does not expose
	# these ratios as hard image-generation constraints.
	result["torso"] = (
		float(result.get("torso", 1.0))
		+ age * 0.14
	)
	result["legs"] = (
		float(result.get("legs", 1.0))
		+ age * 0.13
	)
	result["chest"] = (
		float(result.get("chest", 1.0))
		+ age * 0.09
	)

	var allowance: float = [
		0.0,
		0.0,
		0.55,
		0.80,
		1.0,
		1.15,
	][target_stage]

	var keys: Array = scores.keys()
	keys.sort()

	for key in keys:
		var token := String(
			key
		)

		if not EFFECTS.has(
			token
		):
			continue

		var effect: Array = EFFECTS[
			token
		]
		var strength := (
			minf(
				1.5,
				maxf(
					0.0,
					float(
						scores[key]
					)
				) / 100.0
			)
			* allowance
			* float(
				result.get(
					"response",
					1.0
				)
			)
		)

		result["torso"] = (
			float(
				result.get(
					"torso",
					1.0
				)
			)
			+ float(effect[0]) * strength
		)
		result["legs"] = (
			float(
				result.get(
					"legs",
					1.0
				)
			)
			+ float(effect[1]) * strength
		)
		result["chest"] = (
			float(
				result.get(
					"chest",
					1.0
				)
			)
			+ float(effect[2]) * strength
		)

	result["torso"] = clampf(
		float(result.get("torso", 1.0)),
		0.95,
		3.0
	)
	result["legs"] = clampf(
		float(result.get("legs", 1.0)),
		0.70,
		2.5
	)
	result["chest"] = clampf(
		float(result.get("chest", 1.0)),
		0.70,
		2.2
	)
	result["tail"] = clampf(
		float(result.get("tail", 1.0))
		+ minf(
			1.0,
			float(
				scores.get(
					"tail.long",
					0.0
				)
			) / 160.0
		) * allowance,
		0.7,
		2.3
	)
	result["ears"] = clampf(
		float(result.get("ears", 1.0))
		+ minf(
			0.7,
			float(
				scores.get(
					"ears.long",
					0.0
				)
			) / 200.0
		) * allowance,
		0.7,
		1.9
	)
	result["stage"] = target_stage

	return result


func build(
	identity: PetIdentity,
	stage: int,
	scores: Dictionary = {}
) -> String:
	if identity == null or not identity.is_valid():
		return ""

	var p := resolve(
		identity,
		stage,
		scores
	)

	if p.is_empty():
		return ""

	var adapter := SpeciesExpression.new()
	var focus := _dominant_focus(
		scores
	)
	var pose := adapter.pose_hint(
		identity.species(),
		focus,
		String(
			p.get(
				"temperament",
				"calm"
			)
		)
	)

	return (
		"\n\n[INDIVIDUAL MORPHOLOGY V3]\n"
		+ "Inherited individual: %s\n"
		+ "Maturation target: %s\n"
		+ "Individual response: %s\n"
		+ "Presentation: %s. This pose only reveals the form; it must not reshape anatomy.\n"
		+ "Keep the individual recognizable across stages. Do not convert this qualitative design direction into rigid numeric body ratios. Do not enlarge or shrink unrelated anatomy just to satisfy a Gene."
	) % [
		adapter.birth_expression(
			identity.species(),
			p
		),
		STAGES[
			int(
				p.get(
					"stage",
					clampi(
						stage,
						1,
						5
					)
				)
			)
		],
		adapter.response_hint(
			p
		),
		pose,
	]


func _dominant_focus(
	scores: Dictionary
) -> String:
	var focus := "whole body"
	var best := 0.0
	var keys: Array = scores.keys()
	keys.sort()

	for key in keys:
		var token := String(
			key
		)
		var locus := token.get_slice(
			".",
			0
		)

		if locus not in [
			"body",
			"structure",
			"tail",
			"mane",
			"paws",
			"ears",
			"fur",
		]:
			continue

		var score := float(
			scores[key]
		)

		if score > best:
			best = score
			focus = locus

	return focus
