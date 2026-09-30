extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_test_natural_stage_one_plan()
	_test_gene_stage_one_plan()
	_test_gene_details_cannot_be_silently_dropped()
	_test_tampered_plan_is_rejected()
	_test_legacy_stage_one_pending_is_rebuilt()
	_test_stage_two_natural_plan()
	_test_stage_two_gene_plan()
	_test_stage_one_gene_visual_matrix()
	_test_element_stage_profiles()
	_cleanup()

	if _failures == 0:
		print(
			"M9.5 Stage 1 Evolution Service: PASS"
		)
		quit(0)
		return

	push_error(
		"M9.5 Stage 1 Evolution Service: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_natural_stage_one_plan() -> void:
	_cleanup()
	var fixture := _save_stage_one_fixture(
		9501
	)

	if not fixture:
		return

	var gene_state := GeneDevelopmentState.new(
		1
	)
	var service := StageEvolutionService.new()
	var prepared := service.prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			gene_state.to_dict()
		),
	})

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"Natural Stage 1 plan must prepare"
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
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)

	_expect(
		String(
			pending.get(
				"resolution_mode",
				""
			)
		) == "natural"
		and (
			pending.get(
				"delta",
				{}
			) as Dictionary
		).is_empty(),
		"Natural plan must store natural mode with no delta"
	)

	_expect(
		next != null
		and next.stage() == 2
		and next.get_trait(
			&"tail",
			&"missing"
		) == &"base"
		and next.get_trait(
			&"aura",
			&"missing"
		) == &"base",
		"Natural plan must preserve phenotype into Stage 2"
	)

	var request := service.build_request(
		data
	)

	_expect(
		request != null
		and request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		and request.source_image_path.is_empty()
		and request.output_key.ends_with(
			"_pethome_v12_stage_2"
		)
		and request.positive_prompt.contains(
			"Create one slightly older cat pet"
		)
		and request.positive_prompt.contains(
			"Premium fantasy game character art"
		)
		and request.positive_prompt.contains(
			"evolved chibi proportions"
		)
		and request.positive_prompt.contains(
			"juvenile-to-adolescent"
		)
		and request.positive_prompt.contains(
			"Make the pet slightly older than Stage 1 only"
		)
		and request.positive_prompt.contains(
			"No special fantasy mutation is active"
		)
		and request.positive_prompt.contains(
			"25 to 30 percent"
		)
		and request.negative_prompt.contains(
			"extra tail"
		)
		and request.seed > 0,
		"Natural Stage 1 -> 2 must full-regenerate a visibly older pet"
	)

	var first_request := (
		request.to_debug_dict()
		if request != null
		else {}
	)
	var retry := service.prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			gene_state.to_dict()
		),
	})
	var retry_request := service.build_request(
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
		and retry_request.to_debug_dict()
			== first_request,
		"Pending Natural plan must be byte-stable across retry"
	)

	if retry_request != null:
		var image_path := String(
			(
				data.get(
					"current_visual",
					{}
				) as Dictionary
			).get(
				"image_path",
				""
			)
		)
		_expect(
			service.commit(
				PetRenderResult.ok(
					image_path,
					&"test",
					&"test",
					{}
				)
			),
			"Natural Stage 1 result must commit"
		)

		var committed := EvolutionSaveService.new().load_data()
		var committed_genome := PetGenome.from_dict(
			committed.get(
				"genome",
				{}
			)
		)
		var current_visual: Dictionary = committed.get(
			"current_visual",
			{}
		)
		var history: Array = committed.get(
			"evolution_history",
			[]
		)

		_expect(
			committed_genome != null
			and committed_genome.stage() == 2
			and not committed.has(
				"pending_evolution"
			)
			and String(
				current_visual.get(
					"mutation_id",
					""
				)
			).is_empty()
			and String(
				current_visual.get(
					"source_mode",
					""
				)
			) == "evolution_pethome_v12_full_regenerate"
			and history.size() == 1
			and String(
				(
					history[0] as Dictionary
				).get(
					"resolution_mode",
					""
				)
			) == "natural",
			"Natural commit must advance stage without inventing mutation"
		)


func _test_gene_stage_one_plan() -> void:
	_cleanup()
	var fixture := _save_stage_one_fixture(
		9502
	)

	if not fixture:
		return

	var policy := StageGenePolicy.load_default()
	var gene_state := GeneDevelopmentState.new(
		1
	)
	var recorded := gene_state.record_gene_item(
		policy,
		"gene_tail_runtime",
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
		"Gene runtime fixture must record"
	)

	var service := StageEvolutionService.new()
	var prepared := service.prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 1,
		"gene_development": (
			gene_state.to_dict()
		),
	})

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"Gene Stage 1 plan must prepare"
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
	var delta: Dictionary = pending.get(
		"delta",
		{}
	)
	var next := PetGenome.from_dict(
		pending.get(
			"genome",
			{}
		)
	)

	_expect(
		String(
			pending.get(
				"resolution_mode",
				""
			)
		) == "gene"
		and String(
			delta.get(
				"mutation_id",
				""
			)
		) == "gene_expr_tail_long_s1"
		and String(
			delta.get(
				"target_trait",
				""
			)
		) == "tail",
		"Gene plan must persist the code-selected delta"
	)

	_expect(
		next != null
		and next.stage() == 2
		and next.get_trait(
			&"tail",
			&"base"
		) == &"long",
		"Gene plan must persist the selected phenotype into Stage 2 Genome"
	)

	var request := service.build_request(
		data
	)

	_expect(
		request != null
		and request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		and request.source_image_path.is_empty()
		and request.output_key.ends_with(
			"_pethome_v12_stage_2"
		)
		and request.positive_prompt.contains(
			"Create one slightly older cat pet"
		)
		and request.positive_prompt.contains(
			"Premium fantasy game character art"
		)
		and request.positive_prompt.contains(
			"evolved chibi proportions"
		)
		and request.positive_prompt.contains(
			"juvenile-to-adolescent"
		)
		and request.positive_prompt.contains(
			"Make the pet slightly older than Stage 1 only"
		)
		and request.positive_prompt.contains(
			"Apply only these Gene changes selected by code:"
		)
		and request.positive_prompt.contains(
			"25 to 30 percent"
		)
		and request.negative_prompt.contains(
			"extra tail"
		)
		and request.seed > 0,
		"Gene Stage 1 -> 2 must full-regenerate and apply only the selected Gene"
	)

	var gene_resolution: Dictionary = pending.get(
		"gene_resolution",
		{}
	)
	_expect(
		String(
			gene_resolution.get(
				"selected_gene_id",
				""
			)
		) == "tail_long"
		and is_equal_approx(
			float(
				(
					gene_resolution.get(
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
		"Pending plan must preserve Gene provenance and hidden influence"
	)

	if request != null:
		var image_path := String(
			(
				data.get(
					"current_visual",
					{}
				) as Dictionary
			).get(
				"image_path",
				""
			)
		)
		_expect(
			service.commit(
				PetRenderResult.ok(
					image_path,
					&"test",
					&"test",
					{}
				)
			),
			"Gene Stage 1 result must commit"
		)

		var committed := EvolutionSaveService.new().load_data()
		var committed_genome := PetGenome.from_dict(
			committed.get(
				"genome",
				{}
			)
		)
		var current_visual: Dictionary = committed.get(
			"current_visual",
			{}
		)
		var history: Array = committed.get(
			"evolution_history",
			[]
		)

		_expect(
			committed_genome != null
			and committed_genome.stage() == 2
			and committed_genome.get_trait(
				&"tail",
				&"base"
			) == &"long"
			and String(
				current_visual.get(
					"mutation_id",
					""
				)
			) == "gene_expr_tail_long_s1"
			and String(
				current_visual.get(
					"source_mode",
					""
				)
			) == "evolution_pethome_v12_full_regenerate"
			and history.size() == 1
			and String(
				(
					history[0] as Dictionary
				).get(
					"resolution_mode",
					""
				)
			) == "gene",
			"Gene commit must advance Stage 2 with the resolved phenotype"
		)


func _test_gene_details_cannot_be_silently_dropped() -> void:
	_cleanup()
	if not _save_stage_one_fixture(
		9503
	):
		return

	var result := StageEvolutionService.new().prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 1,
	})

	_expect(
		not bool(
			result.get(
				"ok",
				false
			)
		)
		and String(
			result.get(
				"error",
				""
			)
		).contains(
			"thiếu GeneDevelopmentState"
		),
		"used Gene input must never silently fall back to Natural Growth"
	)


func _test_tampered_plan_is_rejected() -> void:
	_cleanup()
	if not _save_stage_one_fixture(
		9504
	):
		return

	var gene_state := GeneDevelopmentState.new(
		1
	)
	var service := StageEvolutionService.new()
	var prepared := service.prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			gene_state.to_dict()
		),
	})

	if not bool(
		prepared.get(
			"ok",
			false
		)
	):
		_expect(
			false,
			"tamper fixture must prepare"
		)
		return

	var tampered: Dictionary = (
		prepared.get(
			"data",
			{}
		) as Dictionary
	).duplicate(true)
	var pending: Dictionary = tampered.get(
		"pending_evolution",
		{}
	)
	var target: Dictionary = pending.get(
		"target_phenotype",
		{}
	)
	target["tail"] = "hacked_tail"
	pending["target_phenotype"] = target
	tampered["pending_evolution"] = pending

	_expect(
		service.build_request(
			tampered
		) == null,
		"tampered phenotype must invalidate the persisted render plan"
	)

	var validator := StageEvolutionPlanValidator.new()
	_expect(
		not validator.validate(
			tampered
		).is_empty(),
		"plan validator must explain a tampered Stage 1 plan"
	)

	var prompt_tampered: Dictionary = (
		prepared.get(
			"data",
			{}
		) as Dictionary
	).duplicate(true)
	var prompt_pending: Dictionary = prompt_tampered.get(
		"pending_evolution",
		{}
	)
	var render_request: Dictionary = prompt_pending.get(
		"render_request",
		{}
	)
	render_request["positive_prompt"] = (
		String(
			render_request.get(
				"positive_prompt",
				""
			)
		)
		+ "\nINJECT AN UNPLANNED HORN."
	)
	prompt_pending["render_request"] = render_request
	prompt_tampered["pending_evolution"] = prompt_pending

	_expect(
		service.build_request(
			prompt_tampered
		) == null
		and not validator.validate(
			prompt_tampered
		).is_empty(),
		"tampered prompt must be rejected even when phenotype metadata is unchanged"
	)


func _test_legacy_stage_one_pending_is_rebuilt() -> void:
	_cleanup()
	if not _save_stage_one_fixture(
		9505
	):
		return

	var save := EvolutionSaveService.new()
	var data := save.load_data()
	data["pending_evolution"] = {
		"schema": 5,
		"from_stage": 1,
		"to_stage": 2,
	}
	_expect(
		save.save_data(
			data
		),
		"save legacy Stage 1 pending fixture"
	)

	var gene_state := GeneDevelopmentState.new(
		1
	)
	var result := StageEvolutionService.new().prepare({
		"stage_index": 1,
		"ready_to_evolve": false,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": (
			gene_state.to_dict()
		),
	})

	var pending: Dictionary = (
		result.get(
			"data",
			{}
		) as Dictionary
	).get(
		"pending_evolution",
		{}
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and int(
			pending.get(
				"schema",
				0
			)
		) == StageEvolutionService.PENDING_SCHEMA
		and String(
			pending.get(
				"resolution_mode",
				""
			)
		) == "natural",
		"legacy Stage 1 pending must be discarded and rebuilt under M9.5 rules"
	)


func _test_stage_two_natural_plan() -> void:
	_cleanup()
	var image_path := _save_stage_two_fixture(
		9520,
		&"long"
	)

	if image_path.is_empty():
		return

	var gene_state := GeneDevelopmentState.new(
		2
	)
	var service := StageEvolutionService.new()
	var prepared := service.prepare({
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 0,
		"gene_development": gene_state.to_dict(),
	})

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"Natural Stage 2 plan must prepare"
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
		int(
			pending.get(
				"schema",
				0
			)
		) == StageEvolutionService.PENDING_SCHEMA
		and String(
			pending.get(
				"resolution_mode",
				""
			)
		) == "natural"
		and (
			pending.get(
				"delta",
				{}
			) as Dictionary
		).is_empty()
		and next != null
		and next.stage() == 3
		and next.get_trait(
			&"tail",
			&"base"
		) == &"long",
		"Stage 2 without Gene must advance naturally and preserve traits"
	)

	_expect(
		request != null
		and request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		and request.source_image_path.is_empty()
		and request.positive_prompt.contains(
			"Create a NEW image for evolution Stage 3"
		)
		and request.positive_prompt.contains(
			"visibly look older and more developed than Stage 2"
		),
		"Natural Stage 2 must full-regenerate Stage 3 without inventing a Gene"
	)


func _test_stage_two_gene_plan() -> void:
	_cleanup()
	var image_path := _save_stage_two_fixture(
		9521,
		&"long"
	)

	if image_path.is_empty():
		return

	var policy := StageGenePolicy.load_default()
	var gene_state := GeneDevelopmentState.new(
		2
	)
	var recorded := gene_state.record_gene_item(
		policy,
		"stage2_tail_reinforce",
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
		"Stage 2 Gene fixture must record"
	)

	var service := StageEvolutionService.new()
	var prepared := service.prepare({
		"stage_index": 2,
		"ready_to_evolve": true,
		"can_evolve": true,
		"gene_items_used": 1,
		"gene_development": gene_state.to_dict(),
	})

	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		),
		"Gene Stage 2 plan must prepare"
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
	var delta: Dictionary = pending.get(
		"delta",
		{}
	)
	var provenance: Dictionary = pending.get(
		"gene_resolution",
		{}
	)
	var request := service.build_request(
		data
	)

	_expect(
		int(
			pending.get(
				"schema",
				0
			)
		) == StageEvolutionService.PENDING_SCHEMA
		and String(
			pending.get(
				"resolution_mode",
				""
			)
		) == "gene"
		and String(
			delta.get(
				"mutation_id",
				""
			)
		) == "gene_expr_tail_long_s2"
		and String(
			delta.get(
				"from_trait",
				""
			)
		) == "long"
		and String(
			delta.get(
				"to_trait",
				""
			)
		) == "elongated"
		and bool(
			provenance.get(
				"reinforced",
				false
			)
		)
		and String(
			provenance.get(
				"resolved_trait",
				""
			)
		) == "elongated",
		"Stage 2 plan must persist Gene reinforcement provenance"
	)

	_expect(
		request != null
		and request.mode
			== PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		and request.source_image_path.is_empty()
		and request.positive_prompt.contains(
			"elongated"
		),
		"Stage 2 Gene plan must full-regenerate using resolved phenotype"
	)

	if request != null:
		_expect(
			service.commit(
				PetRenderResult.ok(
					image_path,
					&"test",
					&"test",
					{
						"seed": request.seed,
					}
				)
			),
			"Stage 2 Gene result must commit"
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
				&"tail",
				&"base"
			) == &"elongated"
			and not committed.has(
				"pending_evolution"
			),
			"Stage 2 Gene commit must advance to Stage 3 with resolved trait"
		)


func _test_stage_one_gene_visual_matrix() -> void:
	var identity := PetIdentityFactory.new().create_initial(
		9510,
		&"dark"
	)
	var genome := PetGenomeFactory.new().create_initial()
	var policy := StageGenePolicy.load_default()
	var genes := GeneCatalog.new().load_default()
	var visuals := MutationVisualCatalog.new().load_default()
	var stage_one_genes: Array[GeneDefinition] = []

	for definition in genes:
		if policy.can_accept_gene(
			1,
			definition.locus()
		):
			stage_one_genes.append(
				definition
			)

	_expect(
		genes.size() == 15,
		"Gene catalog fixture must contain 15 definitions"
	)
	_expect(
		stage_one_genes.size() == 10,
		"Stage 1 policy must expose exactly 10 eligible Gene definitions"
	)

	for definition in stage_one_genes:
		var state := GeneDevelopmentState.new(
			1
		)
		var recorded := state.record_gene_item(
			policy,
			"matrix_%s"
			% String(
				definition.id()
			),
			definition.id(),
			definition.locus(),
			definition.direction(),
			definition.primary_influence(),
			definition.influence_tags()
		)
		var resolved := StageEvolutionResolver.new().resolve(
			identity,
			genome,
			state
		)
		var delta := resolved.get(
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
				resolved.get(
					"ok",
					false
				)
			)
			and delta != null,
			"every Stage 1 Gene must resolve: %s"
			% String(
				definition.id()
			)
		)

		if delta == null:
			continue

		var visual := MutationVisualCatalog.new().find_by_id(
			visuals,
			delta.mutation_id()
		)

		_expect(
			visual != null
			and visual.target_region()
				== definition.locus(),
			"every Stage 1 Gene delta must have a curated matching visual: %s"
			% String(
				definition.id()
			)
		)

	var phenotype_text := PhenotypePromptBuilder.new().describe(
		genome
	)

	for locus in PetGenomeSchema.VISUAL_LOCI:
		_expect(
			phenotype_text.contains(
				String(locus)
				+ "=base"
			),
			"full phenotype prompt must include locus: %s"
			% String(locus)
		)


func _test_element_stage_profiles() -> void:
	var catalog := ElementStageVisualCatalog.new()
	var profiles := catalog.load_default()
	var elements := [
		&"metal",
		&"wood",
		&"water",
		&"fire",
		&"earth",
		&"dark",
		&"light",
	]

	_expect(
		profiles.size() == elements.size(),
		"Element Stage profile catalog must contain exactly seven elements"
	)

	for element in elements:
		var profile := catalog.find_by_element(
			profiles,
			element
		)

		_expect(
			not profile.is_empty()
			and not catalog.prompt_for_stage(
				profile,
				1
			).is_empty()
			and not catalog.prompt_for_stage(
				profile,
				2
			).is_empty()
			and not catalog.prompt_for_stage(
				profile,
				3
			).is_empty()
			and not catalog.prompt_for_stage(
				profile,
				4
			).is_empty(),
			"Element must define Stage 1 face, Stage 2 morphology and Stage 3/4 detail: %s"
			% String(element)
		)


func _save_stage_two_fixture(
	seed_value: int,
	tail_trait: StringName
) -> String:
	var image := Image.create(
		32,
		48,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(
		Color(
			0.09,
			0.11,
			0.2,
			1.0
		)
	)
	var image_path := (
		"user://m9_5_stage2_source_%d.png"
		% seed_value
	)

	_expect(
		image.save_png(
			image_path
		) == OK,
		"create Stage 2 source PNG"
	)

	var identity := PetIdentityFactory.new().create_initial(
		seed_value,
		&"dark"
	)
	var traits := PetGenomeSchema.base_traits()
	traits[&"tail"] = tail_trait
	var genome := PetGenomeFactory.new().create_snapshot(
		2,
		0.0,
		traits,
		[
			&"gene_expr_tail_long_s1",
		]
	)
	var scene := PetSceneProfileFactory.new().create_initial(
		identity
	)
	var visual := PetVisualRecord.new()

	if (
		identity == null
		or genome == null
		or scene == null
	):
		_expect(
			false,
			"create Stage 2 evolution fixture"
		)
		return ""

	visual.pet_id = identity.pet_id()
	visual.visual_index = 1
	visual.image_path = image_path
	visual.source_mode = (
		&"evolution_pethome_v12_full_regenerate"
	)
	visual.mutation_id = &"gene_expr_tail_long_s1"
	visual.renderer_id = &"test"
	visual.model_id = &"test"

	var saved := EvolutionSaveService.new().save_initial(
		identity,
		genome,
		visual,
		"M9.5 Stage 2 Test",
		scene
	)

	_expect(
		saved,
		"save Stage 2 evolution fixture"
	)

	return (
		image_path
		if saved
		else ""
	)


func _save_stage_one_fixture(
	seed_value: int
) -> bool:
	var image := Image.create(
		32,
		48,
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
	var image_path := (
		"user://m9_5_source_%d.png"
		% seed_value
	)

	_expect(
		image.save_png(
			image_path
		) == OK,
		"create Stage 1 source PNG"
	)

	var identity := PetIdentityFactory.new().create_initial(
		seed_value,
		&"dark"
	)
	var genome := PetGenomeFactory.new().create_initial()
	var scene := PetSceneProfileFactory.new().create_initial(
		identity
	)
	var visual := PetVisualRecord.new()

	if (
		identity == null
		or genome == null
		or scene == null
	):
		_expect(
			false,
			"create Stage 1 evolution fixture"
		)
		return false

	visual.pet_id = identity.pet_id()
	visual.visual_index = 0
	visual.image_path = image_path
	visual.source_mode = (
		&"initial_pethome_v6_text_to_image"
	)
	visual.renderer_id = &"test"
	visual.model_id = &"test"

	var saved := EvolutionSaveService.new().save_initial(
		identity,
		genome,
		visual,
		"M9.5 Test",
		scene
	)

	_expect(
		saved,
		"save Stage 1 evolution fixture"
	)
	return saved


func _cleanup() -> void:
	var save_path := EvolutionSaveService.SAVE_PATH

	if FileAccess.file_exists(
		save_path
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				save_path
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
