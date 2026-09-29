extends SceneTree


const SEED: int = 9404


var _failures: int = 0


func _initialize() -> void:
	_test_natural_growth()
	_test_stage_one_gene_expression()
	_test_later_stage_gene_waits_for_stage_policy()
	_test_stage_mismatch_is_rejected()
	_test_reinforcement_waits_for_expression_chain()

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
	_expect(
		genome.visual_traits_snapshot()
			== before_traits
		and genome.mutation_ids()
			== before_mutations,
		"resolver must not mutate the source Genome"
	)


func _test_stage_one_gene_expression() -> void:
	var identity := _identity()
	var genome := PetGenomeFactory.new().create_initial()
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		1
	)
	var recorded := state.record_gene_item(
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

	_expect(
		bool(
			recorded.get(
				"ok",
				false
			)
		),
		"Stage 1 Gene fixture must record"
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
		and StringName(
			resolved.get(
				"mode",
				""
			)
		) == StageEvolutionResolver.MODE_GENE,
		"Gene input must resolve to Gene Expression"
	)
	_expect(
		delta != null
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
		and next.visual_traits_snapshot().size()
			== 12,
		"Gene delta must produce a complete changed phenotype"
	)
	_expect(
		genome.get_trait(
			&"tail",
			&"base"
		) == &"base",
		"Gene resolution must not mutate the source Genome"
	)
	_expect(
		is_equal_approx(
			float(
				(
					resolved.get(
						"tag_influences",
						{}
					) as Dictionary
				).get(
					"agile",
					0.0
				)
			),
			6.0
		),
		"hidden Gene tags must remain attached to the resolution"
	)


func _test_later_stage_gene_waits_for_stage_policy() -> void:
	var identity := _identity()
	var initial := PetGenomeFactory.new().create_initial()
	var genome := PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		initial.traits_snapshot(),
		initial.mutation_ids()
	)
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		2
	)

	state.record_gene_item(
		policy,
		"gene_body_fixture",
		&"body_agile",
		&"body",
		&"agile",
		12.0,
		{}
	)

	var result := StageEvolutionResolver.new().resolve(
		identity,
		genome,
		state
	)

	_expect(
		not bool(
			result.get(
				"ok",
				false
			)
		)
		and bool(
			result.get(
				"requires_stage_expression_policy",
				false
			)
		),
		"Stage 2/3 Gene expression must wait for their own locked Stage policy"
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


func _test_reinforcement_waits_for_expression_chain() -> void:
	var identity := _identity()
	var genome := PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		{
			"body": "base",
			"eyes": "base",
			"ears": "base",
			"whiskers": "base",
			"fur": "base",
			"coat": "base",
			"tail": "long",
			"paws": "base",
			"mane": "base",
			"mark": "base",
			"structure": "base",
			"aura": "base",
		},
		[
			"gene_expr_tail_long_s1",
		]
	)
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
		identity,
		genome,
		state
	)

	_expect(
		not bool(
			result.get(
				"ok",
				false
			)
		)
		and bool(
			result.get(
				"requires_expression_chain",
				false
			)
		),
		"reinforcing an expressed direction must wait for an explicit Stage expression chain"
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
