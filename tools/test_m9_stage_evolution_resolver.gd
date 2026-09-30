extends SceneTree


const SEED: int = 9404


var _failures: int = 0


func _initialize() -> void:
	_test_natural_growth()
	_test_stage_one_gene_expression()
	_test_stage_two_new_gene_branch()
	_test_stage_two_two_loci_apply_both()
	_test_stage_two_reinforcement_chain()
	_test_stage_two_same_locus_resolves_once()
	_test_stage_mismatch_is_rejected()

	if _failures == 0:
		print(
			"M9.4 Stage Evolution Resolver: PASS"
		)
		quit(0)
		return

	push_error(
		"M9.4 Stage Evolution Resolver: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_natural_growth() -> void:
	var identity := _identity()
	var genome := PetGenomeFactory.new().create_initial()
	var state := GeneDevelopmentState.new(
		1
	)
	var before_traits := (
		genome.visual_traits_snapshot()
	)
	var before_mutations := (
		genome.mutation_ids()
	)
	var resolved := StageEvolutionResolver.new().resolve(
		identity,
		genome,
		state
	)
	var next := resolved.get(
		"genome"
	) as PetGenome

	_expect(
		bool(
			resolved.get(
				"ok",
				false
			)
		)
		and StringName(
			resolved.get(
				"mode",
				""
			)
		) == StageEvolutionResolver.MODE_NATURAL,
		"empty Gene state must resolve to Natural Growth"
	)
	_expect(
		resolved.get(
			"delta"
		) == null,
		"Natural Growth must not invent an EvolutionDelta"
	)
	_expect(
		next != null
		and next.visual_traits_snapshot()
			== before_traits
		and next.mutation_ids()
			== before_mutations,
		"Natural Growth must preserve the complete phenotype"
	)


func _test_stage_one_gene_expression() -> void:
	var identity := _identity()
	var genome := PetGenomeFactory.new().create_initial()
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		1
	)

	state.record_gene_item(
		policy,
		"gene_tail_fixture",
		&"tail_long",
		&"tail",
		&"long",
		20.0,
		{
			"agile": 6.0,
		}
	)

	var resolved := StageEvolutionResolver.new().resolve(
		identity,
		genome,
		state
	)
	var delta := resolved.get(
		"delta"
	) as EvolutionDelta
	var next := resolved.get(
		"genome"
	) as PetGenome

	_expect(
		bool(
			resolved.get(
				"ok",
				false
			)
		)
		and delta != null
		and delta.target_trait()
			== &"tail"
		and delta.from_trait()
			== &"base"
		and delta.to_trait()
			== &"long"
		and delta.mutation_id()
			== &"gene_expr_tail_long_s1",
		"Stage 1 Gene must become one explicit EvolutionDelta"
	)
	_expect(
		next != null
		and next.get_trait(
			&"tail",
			&"base"
		) == &"long"
		and StringName(
			resolved.get(
				"resolved_trait",
				""
			)
		) == &"long"
		and not bool(
			resolved.get(
				"reinforced",
				true
			)
		),
		"Stage 1 Gene must open its first expression"
	)


func _test_stage_two_new_gene_branch() -> void:
	var genome := _stage_two_genome({
		"tail": "long",
	})
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		2
	)

	var recorded := state.record_gene_item(
		policy,
		"gene_body_fixture",
		&"body_sturdy",
		&"body",
		&"sturdy",
		20.0,
		{
			"physical": 8.0,
		}
	)
	var result := StageEvolutionResolver.new().resolve(
		_identity(),
		genome,
		state
	)
	var delta := result.get(
		"delta"
	) as EvolutionDelta

	_expect(
		bool(
			recorded.get(
				"ok",
				false
			)
		)
		and bool(
			result.get(
				"ok",
				false
			)
		)
		and delta != null
		and delta.target_trait() == &"body"
		and delta.from_trait() == &"base"
		and delta.to_trait() == &"sturdy"
		and delta.mutation_id()
			== &"gene_expr_body_sturdy_s2",
		"Stage 2 must express newly unlocked body Gene"
	)


func _test_stage_two_two_loci_apply_both() -> void:
	var genome := _stage_two_genome({
		"tail": "long",
	})
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		2
	)

	state.record_gene_item(
		policy,
		"gene_eyes_fixture",
		&"eyes_moon",
		&"eyes",
		&"moon",
		20.0,
		{}
	)
	state.record_gene_item(
		policy,
		"gene_mark_fixture",
		&"mark_moon",
		&"mark",
		&"moon",
		20.0,
		{}
	)

	var result := StageEvolutionResolver.new().resolve(
		_identity(),
		genome,
		state
	)
	var next := result.get(
		"genome"
	) as PetGenome
	var deltas_value: Variant = result.get(
		"deltas",
		[]
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and next != null
		and next.get_trait(
			&"eyes",
			&"base"
		) == &"moon"
		and next.get_trait(
			&"mark",
			&"base"
		) == &"moon"
		and typeof(deltas_value) == TYPE_ARRAY
		and (deltas_value as Array).size() == 2
		and int(
			result.get(
				"resolved_locus_count",
				0
			)
		) == 2,
		"two Stage 2 Genes in different loci must both express in one evolution"
	)


func _test_stage_two_reinforcement_chain() -> void:
	var genome := _stage_two_genome({
		"tail": "long",
	})
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		2
	)

	state.record_gene_item(
		policy,
		"gene_tail_reinforce",
		&"tail_long",
		&"tail",
		&"long",
		20.0,
		{}
	)

	var result := StageEvolutionResolver.new().resolve(
		_identity(),
		genome,
		state
	)
	var delta := result.get(
		"delta"
	) as EvolutionDelta

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and bool(
			result.get(
				"reinforced",
				false
			)
		)
		and StringName(
			result.get(
				"resolved_trait",
				""
			)
		) == &"elongated"
		and delta != null
		and delta.from_trait() == &"long"
		and delta.to_trait() == &"elongated"
		and delta.mutation_id()
			== &"gene_expr_tail_long_s2",
		"same-direction Stage 2 Gene must advance the predefined expression chain"
	)


func _test_stage_two_same_locus_resolves_once() -> void:
	var genome := _stage_two_genome({})
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		2
	)

	state.record_gene_item(
		policy,
		"tail_option_long",
		&"tail_long",
		&"tail",
		&"long",
		20.0,
		{}
	)
	state.record_gene_item(
		policy,
		"tail_option_fluffy",
		&"tail_fluffy",
		&"tail",
		&"fluffy",
		20.0,
		{}
	)

	var result := StageEvolutionResolver.new().resolve(
		_identity(),
		genome,
		state
	)
	var next := result.get(
		"genome"
	) as PetGenome
	var delta := result.get(
		"delta"
	) as EvolutionDelta
	var changed_count := 0

	if next != null:
		for locus in PetGenomeSchema.VISUAL_LOCI:
			if genome.get_trait(
				locus,
				&"base"
			) != next.get_trait(
				locus,
				&"base"
			):
				changed_count += 1

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and int(
			result.get(
				"candidate_count",
				0
			)
		) == 2
		and delta != null
		and delta.target_trait() == &"tail"
		and (
			delta.to_trait() == &"long"
			or delta.to_trait() == &"fluffy"
		)
		and changed_count == 1,
		"two Stage 2 Genes in one locus must resolve to exactly one weighted result"
	)


func _test_stage_mismatch_is_rejected() -> void:
	var result := StageEvolutionResolver.new().resolve(
		_identity(),
		PetGenomeFactory.new().create_initial(),
		GeneDevelopmentState.new(
			2
		)
	)
	_expect(
		not bool(
			result.get(
				"ok",
				false
			)
		),
		"GeneDevelopmentState from another Stage must be rejected"
	)


func _stage_two_genome(
	overrides: Dictionary
) -> PetGenome:
	var traits := PetGenomeSchema.base_traits()

	for key_value in overrides.keys():
		traits[StringName(
			str(key_value)
		)] = StringName(
			str(overrides[key_value])
		)

	return PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		traits,
		[]
	)


func _identity() -> PetIdentity:
	return PetIdentityFactory.new().create_initial(
		SEED,
		&"dark"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(
		message
	)
