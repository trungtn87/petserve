extends SceneTree


var _failures: int = 0
var _source_path: String = "user://stage2_to_stage3_acceptance.png"


func _initialize() -> void:
	_test_natural_zero_gene()
	_test_two_loci_and_retry_guards()
	_test_locked_stage4_egg_mythic()
	_cleanup()

	if _failures == 0:
		print(
			"Stage 2 -> 3 acceptance: PASS"
		)
		quit(0)
		return

	push_error(
		"Stage 2 -> 3 acceptance: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_natural_zero_gene() -> void:
	_cleanup()
	var fixture := _save_stage_two_fixture(
		8101,
		{},
		[],
		{}
	)

	if not fixture:
		_expect(
			false,
			"save natural Stage 2 fixture"
		)
		return

	var runtime_state := {
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			GeneDevelopmentState.new(
				2
			).to_dict()
		),
	}
	var service := StageEvolutionService.new()
	var prepared := service.prepare(
		runtime_state
	)

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"natural Stage 2 -> 3 prepare"
	)

	if not bool(
		prepared.get(
			"ok",
			false
		)
	):
		return

	var pending: Dictionary = (
		prepared.get(
			"data",
			{}
		).get(
			"pending_evolution",
			{}
		)
	)
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)
	var deltas_value: Variant = pending.get(
		"deltas",
		[]
	)
	var request := service.build_request(
		prepared.get(
			"data",
			{}
		)
	)

	_expect(
		StringName(
			pending.get(
				"resolution_mode",
				""
			)
		) == StageEvolutionResolver.MODE_NATURAL
		and typeof(deltas_value) == TYPE_ARRAY
		and (deltas_value as Array).is_empty()
		and next != null
		and next.stage() == 3
		and next.visual_traits_snapshot()
			== PetGenomeSchema.base_traits(),
		"zero Gene evolution preserves phenotype and targets Stage 3"
	)
	_expect(
		request != null
		and request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		and request.source_image_path
			== _source_path,
		"natural Stage 2 -> 3 uses source-image edit"
	)

	if request == null:
		return

	_expect(
		service.commit(
			PetRenderResult.fail(
				&"network",
				"simulated transport failure",
				&"test",
				&"test"
			)
		) == false,
		"failed render must not commit natural evolution"
	)

	var after_failure := EvolutionSaveService.new().load_data()

	_expect(
		int(
			after_failure.get(
				"genome",
				{}
			).get(
				"stage",
				0
			)
		) == 2
		and after_failure.has(
			"pending_evolution"
		),
		"failed render keeps Stage 2 and pending plan"
	)

	var retry := StageEvolutionService.new().prepare(
		runtime_state
	)
	var retry_request := StageEvolutionService.new().build_request(
		retry.get(
			"data",
			{}
		)
	)

	_expect(
		bool(
			retry.get(
				"ok",
				false
			)
		)
		and retry_request != null
		and retry_request.seed == request.seed,
		"natural retry reuses pending seed"
	)

	_expect(
		service.commit(
			PetRenderResult.ok(
				_source_path,
				&"test",
				&"test",
				{
					"seed": request.seed + 1,
				}
			)
		) == false,
		"wrong render seed must be rejected"
	)

	_expect(
		service.commit(
			PetRenderResult.ok(
				_source_path,
				&"test",
				&"test",
				{
					"seed": request.seed,
				}
			)
		),
		"matching natural render commits"
	)

	var committed := EvolutionSaveService.new().load_data()

	_expect(
		int(
			committed.get(
				"genome",
				{}
			).get(
				"stage",
				0
			)
		) == 3
		and not committed.has(
			"pending_evolution"
		),
		"natural success advances exactly to Stage 3"
	)
	_expect(
		not service.commit(
			PetRenderResult.ok(
				_source_path,
				&"test",
				&"test",
				{
					"seed": request.seed,
				}
			)
		),
		"same result cannot commit twice"
	)


func _test_two_loci_and_retry_guards() -> void:
	_cleanup()
	var fixture := _save_stage_two_fixture(
		8102,
		{
			"tail": "long",
		},
		[
			&"gene_expr_tail_long_s1",
		],
		{}
	)

	if not fixture:
		_expect(
			false,
			"save multi-Gene Stage 2 fixture"
		)
		return

	var policy := StageGenePolicy.load_default()
	var gene_state := GeneDevelopmentState.new(
		2
	)

	_expect(
		bool(
			gene_state.record_gene_item(
				policy,
				"accept_eyes",
				&"eyes_moon",
				&"eyes",
				&"moon",
				20.0,
				{}
			).get(
				"ok",
				false
			)
		),
		"record eyes Gene"
	)
	_expect(
		bool(
			gene_state.record_gene_item(
				policy,
				"accept_mark",
				&"mark_moon",
				&"mark",
				&"moon",
				20.0,
				{}
			).get(
				"ok",
				false
			)
		),
		"record mark Gene"
	)

	var state := {
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 2,
		"gene_development": (
			gene_state.to_dict()
		),
	}
	var service := StageEvolutionService.new()
	var prepared := service.prepare(
		state
	)

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"two-locus Stage 2 -> 3 prepare"
	)

	if not bool(
		prepared.get(
			"ok",
			false
		)
	):
		return

	var data: Dictionary = prepared.get(
		"data",
		{}
	)
	var pending: Dictionary = data.get(
		"pending_evolution",
		{}
	)
	var deltas_value: Variant = pending.get(
		"deltas",
		[]
	)
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)
	var request := service.build_request(
		data
	)

	_expect(
		typeof(deltas_value) == TYPE_ARRAY
		and (deltas_value as Array).size() == 2
		and next != null
		and next.get_trait(
			&"eyes",
			&"base"
		) == &"moon"
		and next.get_trait(
			&"mark",
			&"base"
		) == &"moon",
		"two Stage 2 loci both survive into target Genome"
	)
	_expect(
		request != null
		and request.target_region
			== EvolutionEditCoordinator.COMPOSITE_GENE_TARGET_REGION
		and request.positive_prompt.contains(
			"[CODE-LOCKED GENE CHANGES]"
		),
		"two-locus evolution uses composite render request"
	)

	if request == null:
		return

	var tampered := data.duplicate(
		true
	)
	var tampered_pending: Dictionary = tampered.get(
		"pending_evolution",
		{}
	)
	tampered_pending["render_request"]["seed"] = (
		int(
			tampered_pending.get(
				"render_request",
				{}
			).get(
				"seed",
				0
			)
		) + 99
	)
	tampered["pending_evolution"] = (
		tampered_pending
	)

	_expect(
		not StageEvolutionPlanValidator.new()
			.validate(
				tampered
			).is_empty(),
		"validator rejects render-plan seed drift"
	)

	_expect(
		service.commit(
			PetRenderResult.ok(
				_source_path,
				&"test",
				&"test",
				{
					"seed": request.seed,
				}
			)
		),
		"two-locus render commits"
	)

	var committed := EvolutionSaveService.new().load_data()
	var committed_genome := PetGenome.from_dict(
		committed.get(
			"genome",
			{}
		)
	)

	_expect(
		committed_genome != null
		and committed_genome.stage() == 3
		and committed_genome.get_trait(
			&"eyes",
			&"base"
		) == &"moon"
		and committed_genome.get_trait(
			&"mark",
			&"base"
		) == &"moon",
		"two-locus commit preserves both selected Gene expressions"
	)


func _test_locked_stage4_egg_mythic() -> void:
	_cleanup()
	var identity := PetIdentityFactory.new().create_initial(
		8103,
		&"dark",
		&"cat"
	)
	var destiny := SpeciesMythicDestinyService.new().from_stage4_egg(
		identity,
		4
	)

	_expect(
		not destiny.is_empty(),
		"rare Stage 4 egg locks Mythic Destiny"
	)

	if destiny.is_empty():
		return

	var fixture := _save_stage_two_fixture(
		8103,
		{},
		[],
		destiny
	)

	if not fixture:
		_expect(
			false,
			"save Stage 4 egg Mythic fixture"
		)
		return

	var state := {
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			GeneDevelopmentState.new(
				2
			).to_dict()
		),
	}
	var service := StageEvolutionService.new()
	var prepared := service.prepare(
		state
	)

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"Stage 4 egg destiny prepares Mythic Stage 2 -> 3"
	)

	if not bool(
		prepared.get(
			"ok",
			false
		)
	):
		return

	var data: Dictionary = prepared.get(
		"data",
		{}
	)
	var pending: Dictionary = data.get(
		"pending_evolution",
		{}
	)
	var mythic: Dictionary = pending.get(
		"mythic_resolution",
		{}
	)
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)
	var request := service.build_request(
		data
	)
	var destiny_id := StringName(
		destiny.get(
			"mutation_id",
			""
		)
	)

	_expect(
		StringName(
			mythic.get(
				"mode",
				""
			)
		) == SpeciesMythicMutationResolver.MODE_AWAKEN
		and String(
			mythic.get(
				"trigger_source",
				""
			)
		) == "egg_stage4"
		and next != null
		and next.has_mutation(
			destiny_id
		),
		"Stage 4 egg branch awakens without another rarity roll"
	)
	_expect(
		request != null
		and request.target_region
			== EvolutionEditCoordinator.COMPOSITE_MYTHIC_TARGET_REGION
		and request.positive_prompt.contains(
			"[CODE-LOCKED MYTHIC DESTINY]"
		)
		and request.positive_prompt.contains(
			String(
				destiny.get(
					"display_name",
					""
				)
			)
		),
		"Mythic renderer receives locked beast name and branch"
	)

	if request == null:
		return

	var retry := StageEvolutionService.new().prepare(
		state
	)
	var retry_pending: Dictionary = (
		retry.get(
			"data",
			{}
		).get(
			"pending_evolution",
			{}
		)
	)

	_expect(
		_same_destiny(
			retry_pending.get(
				"mythic_destiny",
				{}
			),
			destiny
		)
		and _same_mythic_resolution(
			retry_pending.get(
				"mythic_resolution",
				{}
			),
			mythic
		),
		"Mythic retry cannot reroll destiny or branch"
	)

	_expect(
		service.commit(
			PetRenderResult.ok(
				_source_path,
				&"test",
				&"test",
				{
					"seed": request.seed,
				}
			)
		),
		"Mythic Stage 2 -> 3 commit"
	)

	var committed := EvolutionSaveService.new().load_data()
	var committed_destiny: Dictionary = committed.get(
		"mythic_destiny",
		{}
	)
	var committed_genome := PetGenome.from_dict(
		committed.get(
			"genome",
			{}
		)
	)

	_expect(
		committed_genome != null
		and committed_genome.stage() == 3
		and committed_genome.has_mutation(
			destiny_id
		)
		and committed_destiny == destiny,
		"Mythic commit preserves locked name and branch into Stage 3"
	)


func _same_destiny(
	a_value: Variant,
	b_value: Variant
) -> bool:
	if (
		typeof(a_value) != TYPE_DICTIONARY
		or typeof(b_value) != TYPE_DICTIONARY
	):
		return false

	var a := a_value as Dictionary
	var b := b_value as Dictionary

	for key in [
		"schema",
		"locked",
		"source",
		"species",
		"mutation_id",
		"display_name",
	]:
		if a.get(key) != b.get(key):
			return false

	return _string_array(
		a.get(
			"recipe_gene_ids",
			[]
		)
	) == _string_array(
		b.get(
			"recipe_gene_ids",
			[]
		)
	)


func _same_mythic_resolution(
	a_value: Variant,
	b_value: Variant
) -> bool:
	if (
		typeof(a_value) != TYPE_DICTIONARY
		or typeof(b_value) != TYPE_DICTIONARY
	):
		return false

	var a := a_value as Dictionary
	var b := b_value as Dictionary

	for key in [
		"mode",
		"trigger_source",
		"mutation_id",
		"display_name",
		"prompt",
		"preserve_hint",
	]:
		if String(
			a.get(
				key,
				""
			)
		) != String(
			b.get(
				key,
				""
			)
		):
			return false

	return _string_array(
		a.get(
			"target_regions",
			[]
		)
	) == _string_array(
		b.get(
			"target_regions",
			[]
		)
	)


func _string_array(
	value: Variant
) -> Array[String]:
	var result: Array[String] = []

	if typeof(value) != TYPE_ARRAY:
		return result

	for item in value as Array:
		result.append(
			String(item)
		)

	return result


func _save_stage_two_fixture(
	seed: int,
	extra_traits: Dictionary,
	mutations: Array,
	mythic_destiny: Dictionary
) -> bool:
	if not _write_source_image():
		return false

	var identity := PetIdentityFactory.new().create_initial(
		seed,
		&"dark",
		&"cat"
	)

	if identity == null:
		return false

	var traits := PetGenomeSchema.base_traits()

	for key_value in extra_traits.keys():
		traits[key_value] = (
			extra_traits[
				key_value
			]
		)

	var genome := PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		traits,
		mutations
	)
	var scene := PetSceneProfileFactory.new().create_initial(
		identity
	)

	if (
		genome == null
		or scene == null
	):
		return false

	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.visual_index = 1
	visual.image_path = _source_path
	visual.source_mode = (
		&"evolution_pethome_v8_full_regenerate"
	)
	visual.renderer_id = &"acceptance"
	visual.model_id = &"acceptance"

	return EvolutionSaveService.new().save_initial(
		identity,
		genome,
		visual,
		"Acceptance Cat",
		scene,
		mythic_destiny
	)


func _write_source_image() -> bool:
	var image := Image.create(
		48,
		72,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(
		Color(
			0.12,
			0.08,
			0.18,
			1.0
		)
	)

	return image.save_png(
		_source_path
	) == OK


func _cleanup() -> void:
	if FileAccess.file_exists(
		EvolutionSaveService.SAVE_PATH
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				EvolutionSaveService.SAVE_PATH
			)
		)

	if FileAccess.file_exists(
		_source_path
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				_source_path
			)
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
