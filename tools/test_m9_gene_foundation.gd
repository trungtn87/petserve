extends SceneTree


const StageGenePolicyScript = preload(
	"res://features/evolution/gene/stage_gene_policy.gd"
)
const GeneDevelopmentStateScript = preload(
	"res://features/evolution/gene/gene_development_state.gd"
)
const PetGenomeFactoryScript = preload(
	"res://features/evolution/domain/pet_genome_factory.gd"
)
const PetGenomeSchemaScript = preload(
	"res://features/evolution/domain/pet_genome_schema.gd"
)


var _failures: int = 0


func _initialize() -> void:
	_test_stage_policy()
	_test_stage_one_limit()
	_test_stage_two_accumulation()
	_test_stage_four_lock()
	_test_round_trip()
	_test_gene_state_does_not_mutate_genome()

	if _failures == 0:
		print("M9.2 Stage Gene Foundation: PASS")
		quit(0)
		return

	push_error(
		"M9.2 Stage Gene Foundation: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_stage_policy() -> void:
	var policy = StageGenePolicyScript.load_default()

	_expect(
		policy != null
		and policy.is_valid(),
		"default stage gene policy must load"
	)

	if policy == null:
		return

	_expect(
		policy.max_gene_items(1) == 1
		and policy.allows_locus(
			1,
			&"eyes"
		)
		and policy.allows_locus(
			1,
			&"ears"
		)
		and policy.allows_locus(
			1,
			&"fur"
		)
		and policy.allows_locus(
			1,
			&"coat"
		)
		and policy.allows_locus(
			1,
			&"tail"
		)
		and not policy.allows_locus(
			1,
			&"body"
		),
		"stage 1 must expose exactly the basic five loci"
	)

	_expect(
		policy.max_gene_items(2) == 2
		and policy.allows_locus(
			2,
			&"body"
		)
		and policy.allows_locus(
			2,
			&"mark"
		)
		and not policy.allows_locus(
			2,
			&"structure"
		)
		and not policy.allows_locus(
			2,
			&"aura"
		),
		"stage 2 must open mid-development loci but not structure/aura"
	)

	_expect(
		policy.max_gene_items(3) == 3
		and policy.allowed_loci(
			3
		).size()
			== PetGenomeSchemaScript.VISUAL_LOCI.size(),
		"stage 3 must expose all 12 visual loci"
	)

	_expect(
		policy.max_gene_items(4) == 0
		and policy.allowed_loci(
			4
		).is_empty(),
		"stage 4 final form must reject new visual gene items"
	)


func _test_stage_one_limit() -> void:
	var policy = StageGenePolicyScript.load_default()
	var state = GeneDevelopmentStateScript.new(
		1
	)

	_expect(
		state.is_valid_for_policy(
			policy
		)
		and not state.has_gene_input()
		and state.remaining_slots(
			policy
		) == 1,
		"fresh stage 1 gene state must be empty with one slot"
	)

	_expect(
		state.record_gene_item(
			policy,
			"item_tail_001",
			&"gene_tail_long",
			&"tail",
			&"long",
			20.0
		),
		"stage 1 must accept one allowed gene item"
	)

	_expect(
		not state.record_gene_item(
			policy,
			"item_eye_001",
			&"gene_eye_luminous",
			&"eyes",
			&"luminous",
			20.0
		),
		"stage 1 must reject a second gene item"
	)

	_expect(
		state.used_gene_items() == 1
		and is_equal_approx(
			state.influence_for(
				&"tail",
				&"long"
			),
			20.0
		)
		and state.remaining_slots(
			policy
		) == 0,
		"stage 1 must persist exactly one influence application"
	)


func _test_stage_two_accumulation() -> void:
	var policy = StageGenePolicyScript.load_default()
	var state = GeneDevelopmentStateScript.new(
		2
	)

	_expect(
		not state.record_gene_item(
			policy,
			"item_structure_001",
			&"gene_horn",
			&"structure",
			&"horn",
			30.0
		),
		"stage 2 must reject structure gene input"
	)

	_expect(
		state.record_gene_item(
			policy,
			"item_tail_002",
			&"gene_tail_long",
			&"tail",
			&"long",
			20.0
		),
		"stage 2 must accept first allowed gene item"
	)

	_expect(
		state.record_gene_item(
			policy,
			"item_tail_003",
			&"gene_tail_long",
			&"tail",
			&"long",
			10.0
		),
		"stage 2 must allow reinforcement with a second item"
	)

	_expect(
		is_equal_approx(
			state.influence_for(
				&"tail",
				&"long"
			),
			30.0
		),
		"same gene direction must accumulate influence"
	)

	_expect(
		not state.record_gene_item(
			policy,
			"item_mark_001",
			&"gene_mark_moon",
			&"mark",
			&"moon",
			15.0
		),
		"stage 2 must enforce the two-item cap"
	)


func _test_stage_four_lock() -> void:
	var policy = StageGenePolicyScript.load_default()
	var state = GeneDevelopmentStateScript.new(
		4
	)

	_expect(
		state.is_valid_for_policy(
			policy
		)
		and not state.record_gene_item(
			policy,
			"item_aura_final",
			&"gene_aura_mist",
			&"aura",
			&"mist",
			50.0
		),
		"stage 4 must not accept new visual gene items"
	)


func _test_round_trip() -> void:
	var policy = StageGenePolicyScript.load_default()
	var original = GeneDevelopmentStateScript.new(
		3
	)

	_expect(
		original.record_gene_item(
			policy,
			"item_aura_001",
			&"gene_aura_mist",
			&"aura",
			&"mist",
			22.5
		),
		"stage 3 fixture gene item"
	)

	_expect(
		not original.record_gene_item(
			policy,
			"item_aura_001",
			&"gene_aura_mist",
			&"aura",
			&"mist",
			22.5
		),
		"same item uid must never be consumed twice"
	)

	var restored = GeneDevelopmentStateScript.from_dict(
		original.to_dict()
	)

	_expect(
		restored != null
		and restored.same_state(
			original
		)
		and restored.is_valid_for_policy(
			policy
		),
		"gene development state must survive serialize/deserialize"
	)


func _test_gene_state_does_not_mutate_genome() -> void:
	var policy = StageGenePolicyScript.load_default()
	var genome = PetGenomeFactoryScript.new().create_initial()
	var before := genome.visual_traits_snapshot()
	var state = GeneDevelopmentStateScript.new(
		1
	)

	state.record_gene_item(
		policy,
		"item_eye_002",
		&"gene_eye_luminous",
		&"eyes",
		&"luminous",
		20.0
	)

	_expect(
		genome.visual_traits_snapshot()
			== before
		and genome.get_trait(
			&"eyes"
		) == &"base",
		"gene influence must not mutate phenotype before evolution"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
