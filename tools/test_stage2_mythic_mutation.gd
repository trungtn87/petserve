extends Node

var _failures: int = 0

func _ready() -> void:
	_test_default_cat_catalog()
	_test_species_isolation()
	_test_normal_egg_has_no_mythic_destiny()
	_test_stage4_egg_locks_mythic_destiny()
	_test_locus_recipes_awaken_cat_branches()
	_test_existing_branch_continues_without_reroll()

	if _failures == 0:
		print("Stage 2 Mythic Mutation: PASS")
		get_tree().quit(0)
		return

	push_error("Stage 2 Mythic Mutation: FAIL (%d)" % _failures)
	get_tree().quit(1)


func _test_default_cat_catalog() -> void:
	var catalog := SpeciesMythicMutationCatalog.new()
	var cats := catalog.for_species(catalog.load_default(), &"cat")
	_expect(cats.size() == 2, "cat must expose exactly two Mythic branches")

	var horn := catalog.find_by_id(cats, &"cat_horned_spirit")
	var wing := catalog.find_by_id(cats, &"cat_winged_spirit")
	_expect(
		horn != null
		and horn.first_expression_stage() == 3
		and horn.required_loci() == [&"whiskers", &"mark", &"ears"],
		"cat horns must be a Stage 3 whiskers+mark+ears recipe"
	)
	_expect(
		wing != null
		and wing.first_expression_stage() == 3
		and wing.required_loci() == [&"fur", &"body", &"mane"],
		"cat wings must be a Stage 3 fur+body+mane recipe"
	)


func _test_species_isolation() -> void:
	var dog := PetIdentityFactory.new().create_initial(7201, &"dark", &"dog")
	var result := SpeciesMythicMutationResolver.new().resolve(
		dog,
		_stage_two_genome(),
		null,
		3,
		[_test_definition(10000)]
	)
	_expect(
		bool(result.get("ok", false))
		and StringName(result.get("mode", "")) == SpeciesMythicMutationResolver.MODE_NONE,
		"cat-only Mythic Mutation must never activate for another species"
	)


func _test_normal_egg_has_no_mythic_destiny() -> void:
	var identity := PetIdentityFactory.new().create_initial(7209, &"dark", &"cat")
	var service := SpeciesMythicDestinyService.new()
	_expect(
		service.from_stage4_egg(identity, 1).is_empty()
		and service.from_stage4_egg(identity, 2).is_empty()
		and service.from_stage4_egg(identity, 3).is_empty(),
		"normal Egg Stage 1-3 must never grant a fantasy mutation"
	)


func _test_stage4_egg_locks_mythic_destiny() -> void:
	var identity := PetIdentityFactory.new().create_initial(7210, &"dark", &"cat")
	var service := SpeciesMythicDestinyService.new()
	var destiny := service.from_stage4_egg(identity, 4)
	_expect(
		not destiny.is_empty()
		and StringName(destiny.get("source", "")) == SpeciesMythicDestinyService.SOURCE_EGG_STAGE4,
		"rare Stage 4 egg must lock one cat Mythic Destiny"
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
	var changed := result.get("genome") as PetGenome
	_expect(
		StringName(result.get("mode", "")) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and changed != null
		and changed.has_mutation(StringName(destiny.get("mutation_id", ""))),
		"Stage 4 egg destiny must awaken when Stage 3 is reached"
	)


func _test_locus_recipes_awaken_cat_branches() -> void:
	var identity := PetIdentityFactory.new().create_initial(7211, &"dark", &"cat")
	var service := SpeciesMythicDestinyService.new()

	var horn := service.from_gene_recipe(
		identity,
		[&"whiskers_starlight", &"mark_moon", &"ears_tufted"]
	)
	_expect(
		StringName(horn.get("mutation_id", "")) == &"cat_horned_spirit"
		and _string_array(horn.get("recipe_loci", [])) == ["ears", "mark", "whiskers"],
		"any valid whiskers+mark+ears Gene combination must lock cat horns"
	)

	var wing := service.from_gene_recipe(
		identity,
		[&"fur_sleek", &"body_sturdy", &"mane_astral"]
	)
	_expect(
		StringName(wing.get("mutation_id", "")) == &"cat_winged_spirit"
		and _string_array(wing.get("recipe_loci", [])) == ["body", "fur", "mane"],
		"any valid fur+body+mane Gene combination must lock cat wings"
	)

	var result := SpeciesMythicMutationResolver.new().resolve(
		identity,
		_stage_two_genome(),
		null,
		3,
		[],
		{},
		[&"whiskers_starlight", &"mark_moon", &"ears_long"]
	)
	_expect(
		StringName(result.get("mode", "")) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and StringName(result.get("mutation_id", "")) == &"cat_horned_spirit",
		"resolver must awaken Mythic branch from species locus recipe"
	)


func _test_existing_branch_continues_without_reroll() -> void:
	var identity := PetIdentityFactory.new().create_initial(7203, &"dark", &"cat")
	var definition := _test_definition(1)
	var stage_three := PetGenomeFactory.new().create_snapshot(
		3, 0.0, PetGenomeSchema.base_traits(), [&"cat_test_spirit"]
	)
	var result := SpeciesMythicMutationResolver.new().resolve(
		identity, stage_three, null, 4, [definition]
	)
	_expect(
		StringName(result.get("mode", "")) == SpeciesMythicMutationResolver.MODE_CONTINUE
		and int(result.get("roll_basis_points", 0)) == -1,
		"existing Mythic branch must continue at Stage 4 without reroll"
	)


func _test_definition(basis_points: int) -> SpeciesMythicMutationDefinition:
	return SpeciesMythicMutationDefinition.new(
		&"cat_test_spirit",
		"Test Spirit Cat",
		&"cat",
		3,
		4,
		basis_points,
		false,
		[],
		[&"structure", &"aura"],
		{},
		{"agile": 5.0},
		{3: "Stage 3 test mythic expression.", 4: "Stage 4 test mythic expression."},
		"Preserve the same cat identity and every non-target Gene trait."
	)


func _stage_two_genome() -> PetGenome:
	return PetGenomeFactory.new().create_snapshot(
		2, 0.0, PetGenomeSchema.base_traits(), []
	)


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value as Array:
		result.append(String(item))
	result.sort()
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
