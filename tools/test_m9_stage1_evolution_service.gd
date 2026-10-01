extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_test_vietnamese_display_names()
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


func _test_vietnamese_display_names() -> void:
	_expect(
		ViDisplay.trait_value(
			&"guardian"
		) == "Hộ vệ",
		"Guardian internal trait must display as Hộ vệ"
	)
	_expect(
		ViDisplay.trait_value(
			&"guardian_mature"
		) == "Hộ vệ trưởng thành",
		"Developed trait IDs must stay Vietnamese"
	)
	_expect(
		ViDisplay.gene_name(
			"structure_guardian"
		) == "Gen Cấu Trúc Hộ Vệ",
		"Gene internal ID must resolve to Vietnamese display name"
	)
	_expect(
		ViDisplay.rarity_label(
			"legendary"
		) == "Huyền thoại",
		"Rarity IDs must display in Vietnamese"
	)


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
			"Make the pet clearly older and more developed than Stage 1"
		)
		and request.positive_prompt.contains(
			"fuller layered fur"
		)
		and request.positive_prompt.contains(
			"gentle elemental glow"
		)
		and request.positive_prompt.contains(
			"No special fantasy mutation is active"
		)
		and request.positive_prompt.contains(
			"30 to 34 percent"
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
		"gene_whiskers_runtime",
		&"whiskers_starlight",
		&"whiskers",
		&"starlight",
		20.0,
		{
			"mystic": 6.0,
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
	var used_gene_items_value: Variant = pending.get(
		"gene_items_used",
		[]
	)
	var used_gene_items: Array = (
		used_gene_items_value as Array
		if typeof(used_gene_items_value) == TYPE_ARRAY
		else []
	)

	_expect(
		used_gene_items.size() == 1
		and typeof(used_gene_items[0]) == TYPE_DICTIONARY
		and String(
			(used_gene_items[0] as Dictionary).get(
				"gene_id",
				""
			)
		) == "whiskers_starlight"
		and int(
			(used_gene_items[0] as Dictionary).get(
				"stage_used",
				0
			)
		) == 1,
		"Gene plan must persist exact Gene items for post-evolution history UI"
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
		) == "gene_expr_whiskers_starlight_s1"
		and String(
			delta.get(
				"target_trait",
				""
			)
		) == "whiskers",
		"Gene plan must persist the code-selected delta"
	)

	_expect(
		next != null
		and next.stage() == 2
		and next.get_trait(
			&"whiskers",
			&"base"
		) == &"starlight",
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
			"Make the pet clearly older and more developed than Stage 1"
		)
		and request.positive_prompt.contains(
			"fuller layered fur"
		)
		and request.positive_prompt.contains(
			"gentle elemental glow"
		)
		and request.positive_prompt.contains(
			"Apply only these Gene changes selected by code:"
		)
		and request.positive_prompt.contains(
			"30 to 34 percent"
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
		) == "whiskers_starlight"
		and is_equal_approx(
			float(
				(
					gene_resolution.get(
						"tag_influences",
						{}
					) as Dictionary
				).get(
					"mystic",
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
				&"whiskers",
				&"base"
			) == &"starlight"
			and String(
				current_visual.get(
					"mutation_id",
					""
				)
			) == "gene_expr_whiskers_starlight_s1"
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
			) == "gene"
			and (
				(
					(history[0] as Dictionary).get(
						"gene_items_used",
						[]
					) as Array
				).size() == 1
			),
			"Gene commit must advance Stage 2 and keep Gene history details"
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
			== PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		and request.source_image_path == image_path
		and request.positive_prompt.contains(
			"[REFERENCE EVOLUTION RULE]"
		)
		and request.positive_prompt.contains(
			"[GENE-ONLY PET CHANGE]"
		)
		and request.positive_prompt.contains(
			"No new structural Gene delta is selected"
		)
		and request.positive_prompt.contains(
			"background is NOT continuity-locked"
		),
		"Natural Stage 2 must use the Stage 2 image as reference without inventing a Gene"
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
			== PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT
		and request.source_image_path == image_path
		and request.positive_prompt.contains(
			"elongated"
		)
		and request.positive_prompt.contains(
			"[ACCUMULATED GENE SCORE PHENOTYPE]"
		)
		and request.positive_prompt.contains(
			"Only Gene loci listed below are authorized to differ"
		),
		"Stage 2 Gene plan must edit the reference image from the lifetime Gene score plan"
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
	var compatible_genes: Array[GeneDefinition] = []

	for definition in genes:
		if (
			policy.can_accept_gene(
				1,
				definition.locus()
			)
			and definition.is_element_compatible(
				identity.element()
			)
		):
			compatible_genes.append(
				definition
			)

	_expect(
		genes.size() == 64,
		"Gene catalog fixture must contain 64 definitions"
	)
	_expect(
		compatible_genes.size() == 52,
		"Dark pet must see 50 shared + Dark Mark/Aura definitions"
	)

	for definition in compatible_genes:
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
			20.0,
			definition.influence_tags(),
			"uncommon",
			definition.element_lock()
		)
		var resolved := StageEvolutionResolver.new().resolve(
			identity,
			genome,
			state
		)
		var delta := resolved.get(
			"delta"
		) as EvolutionDelta
		var score_prompt := GenePromptResolver.new().build(
			state,
			identity.element(),
			2
		)

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
			"every compatible Stage 1 Gene must resolve: %s"
			% String(
				definition.id()
			)
		)
		_expect(
			not definition.prompt_stem().is_empty()
			and score_prompt.contains(
				String(
					definition.direction()
				)
			),
			"every Gene must provide score-driven prompt metadata: %s"
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
