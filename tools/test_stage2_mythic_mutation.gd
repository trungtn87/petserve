extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_test_default_cat_catalog()
	_test_species_isolation()
	_test_stage4_egg_locks_mythic_destiny()
	_test_three_fixed_genes_awaken_branch()
	_test_awaken_does_not_consume_gene_slots()
	_test_existing_branch_continues_without_reroll()

	if _failures == 0:
		print(
			"Stage 2 Mythic Mutation: PASS"
		)
		quit(0)
		return

	push_error(
		"Stage 2 Mythic Mutation: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_default_cat_catalog() -> void:
	var catalog := SpeciesMythicMutationCatalog.new()
	var definitions := catalog.load_default()
	var cats := catalog.for_species(
		definitions,
		&"cat"
	)

	_expect(
		cats.size() == 2,
		"cat must expose exactly two Mythic Mutation branches"
	)

	var ids: Array[String] = []

	for definition in cats:
		ids.append(
			String(
				definition.id()
			)
		)
		_expect(
			definition.first_expression_stage()
				== 2
			and definition.supports_stage(
				2
			)
			and definition.supports_stage(
				3
			)
			and definition.supports_stage(
				4
			),
			"cat Mythic Mutation must have Stage 3 and Stage 4 expressions"
		)
		_expect(
			not definition.is_activation_configured(),
			"default rarity must remain unconfigured until balance is approved"
		)

	_expect(
		ids.has(
			"cat_nekomata"
		)
		and ids.has(
			"cat_bakeneko"
		),
		"cat catalog must contain Nekomata and Bakeneko"
	)


func _test_species_isolation() -> void:
	var definition := _test_definition(
		10000
	)
	var dog := PetIdentityFactory.new().create_initial(
		7201,
		&"dark",
		&"dog"
	)
	var result := SpeciesMythicMutationResolver.new().resolve(
		dog,
		_stage_two_genome(),
		null,
		3,
		[
			definition,
		]
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and StringName(
			result.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_NONE
		and String(
			result.get(
				"mutation_id",
				""
			)
		).is_empty(),
		"cat-only Mythic Mutation must never activate for another species"
	)


func _test_stage4_egg_locks_mythic_destiny() -> void:
	var identity := PetIdentityFactory.new().create_initial(
		7210,
		&"dark",
		&"cat"
	)
	var destiny := SpeciesMythicDestinyService.new().from_stage4_egg(
		identity,
		4
	)

	_expect(
		not destiny.is_empty()
		and bool(
			destiny.get(
				"locked",
				false
			)
		)
		and StringName(
			destiny.get(
				"source",
				""
			)
		) == SpeciesMythicDestinyService.SOURCE_EGG_STAGE4,
		"rare Stage 4 egg must lock one cat Mythic Destiny immediately"
	)

	var result := SpeciesMythicMutationResolver.new().resolve(
		identity,
		_stage_two_genome(),
		null,
		3,
		[],
		destiny,
		[]
	)
	var changed := result.get(
		"genome"
	) as PetGenome
	var mutation_id := StringName(
		destiny.get(
			"mutation_id",
			""
		)
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and StringName(
			result.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and String(
			result.get(
				"trigger_source",
				""
			)
		) == "egg_stage4"
		and changed != null
		and changed.has_mutation(
			mutation_id
		),
		"Stage 4 egg destiny must awaken without another rarity roll"
	)


func _test_three_fixed_genes_awaken_branch() -> void:
	var identity := PetIdentityFactory.new().create_initial(
		7211,
		&"dark",
		&"cat"
	)
	var destiny := SpeciesMythicDestinyService.new().from_gene_recipe(
		identity,
		[
			&"tail_long",
			&"eyes_moon",
			&"mark_moon",
		]
	)

	_expect(
		StringName(
			destiny.get(
				"mutation_id",
				""
			)
		) == &"cat_nekomata"
		and StringName(
			destiny.get(
				"source",
				""
			)
		) == SpeciesMythicDestinyService.SOURCE_GENE_RECIPE,
		"three fixed Nekomata Gene ids must lock the Nekomata destiny"
	)

	var result := SpeciesMythicMutationResolver.new().resolve(
		identity,
		_stage_two_genome(),
		null,
		3,
		[],
		{},
		[
			&"tail_long",
			&"eyes_moon",
			&"mark_moon",
		]
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and StringName(
			result.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and StringName(
			result.get(
				"mutation_id",
				""
			)
		) == &"cat_nekomata"
		and String(
			result.get(
				"trigger_source",
				""
			)
		) == "gene_recipe",
		"three fixed Genes must deterministically awaken their Mythic branch at evolution"
	)


func _test_awaken_does_not_consume_gene_slots() -> void:
	var identity := PetIdentityFactory.new().create_initial(
		7202,
		&"dark",
		&"cat"
	)
	var genome := _stage_two_genome()
	var state := GeneDevelopmentState.new(
		2
	)
	var policy := StageGenePolicy.load_default()

	state.record_gene_item(
		policy,
		"mythic_test_gene",
		&"tail_long",
		&"tail",
		&"long",
		20.0,
		{
			"agile": 6.0,
		}
	)

	var before_count := state.item_count()
	var result := SpeciesMythicMutationResolver.new().resolve(
		identity,
		genome,
		state,
		3,
		[
			_test_definition(
				10000
			),
		]
	)
	var changed := result.get(
		"genome"
	) as PetGenome

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and StringName(
			result.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and StringName(
			result.get(
				"mutation_id",
				""
			)
		) == &"cat_test_spirit"
		and changed != null
		and changed.has_mutation(
			&"cat_test_spirit"
		),
		"configured cat Mythic Mutation must awaken deterministically"
	)

	_expect(
		state.item_count() == before_count,
		"Mythic Mutation must not consume a Gene Item slot"
	)

	_expect(
		changed != null
		and changed.traits_snapshot()
			== genome.traits_snapshot(),
		"Mythic Mutation branch id must not silently rewrite normal Gene traits"
	)


func _test_existing_branch_continues_without_reroll() -> void:
	var identity := PetIdentityFactory.new().create_initial(
		7203,
		&"dark",
		&"cat"
	)
	var definition := _test_definition(
		1
	)
	var stage_three := PetGenomeFactory.new().create_snapshot(
		3,
		0.0,
		PetGenomeSchema.base_traits(),
		[
			&"cat_test_spirit",
		]
	)
	var result := SpeciesMythicMutationResolver.new().resolve(
		identity,
		stage_three,
		null,
		4,
		[
			definition,
		]
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and StringName(
			result.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_CONTINUE
		and int(
			result.get(
				"roll_basis_points",
				0
			)
		) == -1
		and String(
			result.get(
				"prompt",
				""
			)
		).contains(
			"Stage 4"
		),
		"existing Mythic branch must continue at Stage 4 without a second rarity roll"
	)


func _test_definition(
	basis_points: int
) -> SpeciesMythicMutationDefinition:
	return SpeciesMythicMutationDefinition.new(
		&"cat_test_spirit",
		"Test Spirit Cat",
		&"cat",
		3,
		4,
		basis_points,
		false,
		[],
		[
			&"tail",
			&"aura",
		],
		{},
		{
			"agile": 5.0,
		},
		{
			3: "Stage 3 test mythic expression.",
			4: "Stage 4 test mythic expression.",
		},
		"Preserve the same cat identity and every non-target Gene trait."
	)


func _stage_two_genome() -> PetGenome:
	return PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		PetGenomeSchema.base_traits(),
		[]
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
