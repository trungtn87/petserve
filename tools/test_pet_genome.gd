extends SceneTree


const PetGenomeScript = preload(
	"res://features/evolution/domain/pet_genome.gd"
)

const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
)


var _failures: int = 0


func _initialize() -> void:
	_test_initial_genome()
	_test_round_trip()
	_test_extensible_trait()
	_test_visual_schema()
	_test_sparse_snapshot_visual_completion()
	_test_custom_snapshot()
	_test_copy_safety()
	_test_invalid_input()
	_test_identity_not_embedded()

	if _failures == 0:
		print("M2 PetGenome: PASS")
		quit(0)
		return

	push_error(
		"M2 PetGenome: FAIL (%d)" % _failures
	)
	quit(1)


func _test_initial_genome() -> void:
	var factory = PetGenomeFactoryScript.new()
	var genome = factory.create_initial()

	_expect(
		genome != null and genome.is_valid(),
		"initial genome must be valid"
	)

	_expect(
		genome.stage() == 1,
		"initial stage must be 1"
	)

	_expect(
		is_equal_approx(
			genome.body_growth(),
			0.0
		),
		"initial body_growth must be 0"
	)

	for trait_id in PetGenomeSchema.VISUAL_LOCI:
		_expect(
			genome.get_trait(trait_id) == &"base",
			"initial trait must be base: %s"
			% String(trait_id)
		)


func _test_round_trip() -> void:
	var factory = PetGenomeFactoryScript.new()

	var original = factory.create_snapshot(
		2,
		0.35,
		{
			"fur": "base",
			"eyes": "galaxy_ring",
			"tail": "long_fluffy",
		},
		[
			"eye_glow",
			"tail_starlight",
		]
	)

	var restored = PetGenomeScript.from_dict(
		original.to_dict()
	)

	_expect(
		restored != null
		and original.same_genome(restored),
		"serialize/deserialize must preserve genome exactly"
	)


func _test_extensible_trait() -> void:
	var factory = PetGenomeFactoryScript.new()

	var genome = factory.create_initial({
		"horn": "tiny_crescent",
	})

	_expect(
		genome != null
		and genome.get_trait(
			&"horn",
			&"none"
		) == &"tiny_crescent",
		"new trait channel must not require PetGenome core edits"
	)


func _test_visual_schema() -> void:
	var factory = PetGenomeFactoryScript.new()
	var genome = factory.create_initial()

	_expect(
		PetGenomeSchema.render_field_count() == 16,
		"Genome V1 render contract must contain 16 fields"
	)

	_expect(
		PetGenomeSchema.VISUAL_LOCI.size() == 12,
		"Genome V1 must contain exactly 12 mutable visual loci"
	)

	var visual := genome.visual_traits_snapshot()

	_expect(
		visual.size() == 12,
		"initial visual phenotype must expose all 12 loci"
	)

	for locus in PetGenomeSchema.VISUAL_LOCI:
		_expect(
			visual.get(locus, &"") == &"base",
			"initial visual locus must be base: %s"
			% String(locus)
		)


func _test_sparse_snapshot_visual_completion() -> void:
	var genome = PetGenomeScript.new(
		2,
		0.4,
		{
			"eyes": "lunar_glow",
			"tail": "long",
		},
		[]
	)

	var visual := genome.visual_traits_snapshot()

	_expect(
		visual.size() == 12,
		"legacy sparse genome must expand to the full visual contract"
	)

	_expect(
		visual.get(&"eyes", &"") == &"lunar_glow"
		and visual.get(&"tail", &"") == &"long"
		and visual.get(&"body", &"") == &"base"
		and visual.get(&"aura", &"") == &"base",
		"visual completion must preserve known traits and fill missing loci with base"
	)


func _test_custom_snapshot() -> void:
	var factory = PetGenomeFactoryScript.new()

	var genome = factory.create_snapshot(
		3,
		0.72,
		{
			"fur": "nebula",
			"eyes": "violet_cyan",
			"tail": "split_tip",
		},
		[
			"ear_glow",
			"moon_mark",
		]
	)

	_expect(
		genome != null
		and genome.stage() == 3
		and is_equal_approx(
			genome.body_growth(),
			0.72
		)
		and genome.has_mutation(
			&"ear_glow"
		),
		"custom genome snapshot must preserve supplied state"
	)


func _test_copy_safety() -> void:
	var factory = PetGenomeFactoryScript.new()
	var genome = factory.create_initial()

	var traits := genome.traits_snapshot()
	traits["fur"] = "changed_outside"

	_expect(
		genome.get_trait(&"fur") == &"base",
		"traits_snapshot must not expose internal state"
	)

	var mutations := genome.mutation_ids()
	mutations.append(&"external_mutation")

	_expect(
		not genome.has_mutation(
			&"external_mutation"
		),
		"mutation_ids must not expose internal state"
	)


func _test_invalid_input() -> void:
	var factory = PetGenomeFactoryScript.new()

	_expect(
		factory.create_snapshot(
			0,
			0.0,
			{},
			[]
		) == null,
		"stage below 1 must be rejected"
	)

	_expect(
		factory.create_snapshot(
			1,
			1.1,
			{},
			[]
		) == null,
		"body_growth above 1 must be rejected"
	)

	_expect(
		factory.create_snapshot(
			1,
			0.2,
			{"": "base"},
			[]
		) == null,
		"empty trait id must be rejected"
	)

	_expect(
		factory.create_snapshot(
			1,
			0.2,
			{},
			[
				"ear_glow",
				"ear_glow",
			]
		) == null,
		"duplicate mutation must be rejected"
	)


func _test_identity_not_embedded() -> void:
	var factory = PetGenomeFactoryScript.new()
	var data := factory.create_initial().to_dict()

	for forbidden_key in [
		"pet_id",
		"species",
		"element",
		"lineage_seed",
		"generation",
	]:
		_expect(
			not data.has(forbidden_key),
			"genome must not embed identity field: %s"
			% forbidden_key
		)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
