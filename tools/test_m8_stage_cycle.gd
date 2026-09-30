extends Node


var failures: int = 0


func _ready() -> void:
	call_deferred(
		"run"
	)


func check(
	ok: bool,
	label: String
) -> void:
	if ok:
		return

	failures += 1
	push_error(
		"M8: " + label
	)


func run() -> void:
	_test_stage_lifecycle()
	_test_stage_item_contract()
	_test_stage_resource_scaling()
	_test_evolution_two_and_three()

	print(
		"M8 STAGE CYCLE failures=",
		failures
	)
	get_tree().quit(
		1 if failures else 0
	)


func _test_stage_lifecycle() -> void:
	var policy := (
		StageLifecyclePolicy.load_default()
	)
	check(
		policy != null,
		"policy loads"
	)

	if policy == null:
		return

	check(
		int(
			policy.stage(2).get(
				"duration_seconds",
				0
			)
		) == 2 * 24 * 60 * 60,
		"stage 2 uses two-day design baseline"
	)
	check(
		int(
			policy.stage(3).get(
				"duration_seconds",
				0
			)
		) == 3 * 24 * 60 * 60,
		"stage 3 uses three-day design baseline"
	)

	var meta: Dictionary = {}
	var life := StageLifecycle.new()
	life.setup(
		meta,
		500,
		2
	)

	var stage_two := life.snapshot()
	check(
		int(
			stage_two.get(
				"stage_index",
				0
			)
		) == 2,
		"stage 2 starts"
	)
	check(
		int(
			stage_two.get(
				"growth_percent",
				-1
			)
		) == 0,
		"stage 2 growth resets"
	)

	var duration_two := int(
		stage_two.get(
			"duration_seconds",
			0
		)
	)

	check(
		life.apply_item({
			"item_type": "food",
			"display_name": "Test Food",
			"main_value_seconds": duration_two,
			"growth_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"stage 2 accepts food"
	)

	meta.life_state.last_update_unix = (
		int(
			Time.get_unix_time_from_system()
		) - 600
	)
	life.setup(
		meta,
		500,
		2
	)

	check(
		int(
			life.snapshot().get(
				"growth_remaining_seconds",
				0
			)
		) == duration_two - 600,
		"stage 2 offline growth applies"
	)

	life.tick(
		float(
			duration_two - 600
		)
	)
	check(
		bool(
			life.snapshot().get(
				"ready_to_evolve",
				false
			)
		),
		"stage 2 becomes ready"
	)

	var starved_meta: Dictionary = {}
	var starved := StageLifecycle.new()
	starved.setup(
		starved_meta,
		501,
		2
	)
	starved.tick(
		float(
			duration_two
		)
	)
	var starved_state := starved.snapshot()
	check(
		int(
			starved_state.get(
				"growth_percent",
				0
			)
		) == 75,
		"stage 2 starvation keeps growth at 75 percent"
	)
	check(
		bool(
			starved_state.get(
				"deadline_reached",
				false
			)
		)
		and bool(
			starved_state.get(
				"ready_to_evolve",
				false
			)
		),
		"stage 2 age deadline makes pet ready independently of growth"
	)

	life.advance_to_stage(
		3
	)
	var stage_three := life.snapshot()
	check(
		int(
			stage_three.get(
				"stage_index",
				0
			)
		) == 3,
		"stage 3 starts"
	)
	check(
		int(
			stage_three.get(
				"growth_percent",
				-1
			)
		) == 0,
		"stage 3 growth resets"
	)

	var duration_three := int(
		stage_three.get(
			"duration_seconds",
			0
		)
	)
	check(
		life.apply_item({
			"item_type": "food",
			"display_name": "Test Food",
			"main_value_seconds": duration_three,
			"growth_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"stage 3 accepts food"
	)
	life.tick(
		float(
			duration_three
		)
	)
	check(
		bool(
			life.snapshot().get(
				"ready_to_evolve",
				false
			)
		),
		"stage 3 becomes ready"
	)

	life.advance_to_stage(
		4
	)
	var final_state := life.snapshot()
	check(
		int(
			final_state.get(
				"stage_index",
				0
			)
		) == 4,
		"stage 4 starts"
	)
	check(
		bool(
			final_state.get(
				"final_form",
				false
			)
		),
		"stage 4 is final form"
	)
	check(
		not bool(
			final_state.get(
				"ready_to_evolve",
				true
			)
		),
		"final form does not request evolution"
	)
	check(
		not life.tick(
			3600.0
		),
		"final form has no M8 growth timer"
	)


func _test_stage_item_contract() -> void:
	SaveManager.delete_meta()

	var game := InfantGameFacade.new()
	check(
		game.setup(
			600,
			2
		),
		"stage 2 facade setup"
	)

	var dev_state := game.snapshot()
	check(
		bool(
			dev_state.get(
				"can_evolve",
				false
			)
		),
		"default TEST talent bypasses the stage timer"
	)
	check(
		not bool(
			dev_state.get(
				"ready_to_evolve",
				true
			)
		),
		"timer bypass does not fake natural growth completion"
	)
	check(
		(
			dev_state.get(
				"talents",
				[]
			) as Array
		).has(
			String(
				InfantGameFacade.DEV_INSTANT_EVOLUTION_TALENT
			)
		),
		"default TEST talent is assigned"
	)

	var rewards := game.open_next_chest()
	var growth_item: Dictionary = {}

	for item in rewards:
		var item_type := StringName(
			item.get(
				"item_type",
				""
			)
		)

		if (
			item_type == ItemGenerator.TYPE_FOOD
			or item_type == ItemGenerator.TYPE_GROWTH
		):
			growth_item = item
			break

	check(
		not growth_item.is_empty(),
		"stage item fixture exists"
	)

	if not growth_item.is_empty():
		check(
			game.can_use_item(
				growth_item
			),
			"growth item usable in stage 2"
		)

	game.advance_to_stage(
		4
	)

	if not growth_item.is_empty():
		check(
			not game.can_use_item(
				growth_item
			),
			"growth item locked in final form"
		)

	SaveManager.delete_meta()


func _test_stage_resource_scaling() -> void:
	var generator := ItemGenerator.new()
	var base_food := generator.generate(
		ItemGenerator.TYPE_FOOD,
		88001
	)
	var stage_two_food := generator.generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		88001,
		2
	)
	var base_growth := generator.generate(
		ItemGenerator.TYPE_GROWTH,
		88002
	)
	var stage_two_growth := generator.generate_for_stage(
		ItemGenerator.TYPE_GROWTH,
		88002,
		2
	)

	check(
		int(
			stage_two_food.get(
				"main_value_seconds",
				0
			)
		) == int(
			round(
				float(
					base_food.get(
						"main_value_seconds",
						0
					)
				) * 12.0
			)
		)
		and int(
			stage_two_food.get(
				"generated_for_stage",
				0
			)
		) == 2,
		"Stage 2 Food uses the 48-hour resource scale"
	)

	check(
		int(
			stage_two_growth.get(
				"main_value_seconds",
				0
			)
		) == int(
			round(
				float(
					base_growth.get(
						"main_value_seconds",
						0
					)
				) * 12.0
			)
		),
		"Stage 2 Growth uses the 48-hour resource scale"
	)


func _test_evolution_two_and_three() -> void:
	var save_path := (
		EvolutionSaveService.SAVE_PATH
	)
	var absolute := (
		ProjectSettings.globalize_path(
			save_path
		)
	)

	if FileAccess.file_exists(
		save_path
	):
		DirAccess.remove_absolute(
			absolute
		)

	var image := Image.create(
		32,
		48,
		false,
		Image.FORMAT_RGBA8
	)
	image.fill(
		Color("#20172d")
	)
	check(
		image.save_png(
			"user://m8_pet.png"
		) == OK,
		"create M8 source image"
	)

	var identity := (
		PetIdentityFactory.new()
		.create_initial(
			880,
			&"dark"
		)
	)
	check(
		identity != null,
		"identity"
	)

	if identity == null:
		return

	var scene := (
		PetSceneProfileFactory.new()
		.create_initial(
			identity
		)
	)
	check(
		scene != null,
		"scene profile"
	)

	var genome := PetGenome.new(
		2,
		0.0,
		{},
		[]
	)
	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.visual_index = 0
	visual.image_path = (
		"user://m8_pet.png"
	)
	visual.source_mode = (
		&"evolution_pethome_v5_image_edit"
	)
	visual.renderer_id = &"test"
	visual.model_id = &"test"

	check(
		EvolutionSaveService.new()
		.save_initial(
			identity,
			genome,
			visual,
			"Mèo M8",
			scene
		),
		"save stage 2 fixture"
	)

	var service := StageEvolutionService.new()
	var evolution_two := service.prepare({
		"stage_index": 2,
		"ready_to_evolve": false,
		"can_evolve": true,
	})
	check(
		bool(
			evolution_two.get(
				"ok",
				false
			)
		),
		"prepare Evolution II"
	)

	if not bool(
		evolution_two.get(
			"ok",
			false
		)
	):
		return

	var pending_two: Dictionary = (
		evolution_two.get(
			"data",
			{}
		).get(
			"pending_evolution",
			{}
		)
	)
	check(
		int(
			pending_two.get(
				"from_stage",
				0
			)
		) == 2
		and int(
			pending_two.get(
				"to_stage",
				0
			)
		) == 3,
		"Evolution II targets stage 3"
	)

	var request_two := (
		service.build_request(
			evolution_two.get(
				"data",
				{}
			)
		)
	)
	check(
		request_two != null
		and request_two.output_key.ends_with(
			"_pethome_v9_stage_3"
		)
		and request_two.positive_prompt.contains(
			"[PETHOME SCALE LOCK]"
		)
		and request_two.positive_prompt.contains(
			"35 percent"
		)
		and request_two.positive_prompt.contains(
			"10 percent"
		),
		"Evolution II request"
	)

	check(
		service.commit(
			PetRenderResult.ok(
				"user://m8_pet.png",
				&"test",
				&"test",
				{}
			)
		),
		"commit Evolution II"
	)

	var after_two := (
		EvolutionSaveService.new()
		.load_data()
	)
	check(
		int(
			after_two.get(
				"genome",
				{}
			).get(
				"stage",
				0
			)
		) == 3,
		"Evolution II commits stage 3"
	)

	var evolution_three := (
		StageEvolutionService.new()
		.prepare({
			"stage_index": 3,
			"ready_to_evolve": false,
			"can_evolve": true,
		})
	)
	check(
		bool(
			evolution_three.get(
				"ok",
				false
			)
		),
		"prepare Evolution III"
	)

	if not bool(
		evolution_three.get(
			"ok",
			false
		)
	):
		return

	var pending_three: Dictionary = (
		evolution_three.get(
			"data",
			{}
		).get(
			"pending_evolution",
			{}
		)
	)
	check(
		int(
			pending_three.get(
				"from_stage",
				0
			)
		) == 3
		and int(
			pending_three.get(
				"to_stage",
				0
			)
		) == 4,
		"Evolution III targets stage 4"
	)

	var request_three := (
		StageEvolutionService.new()
		.build_request(
			evolution_three.get(
				"data",
				{}
			)
		)
	)
	check(
		request_three != null
		and request_three.output_key.ends_with(
			"_pethome_v9_stage_4"
		)
		and request_three.positive_prompt.contains(
			"[PETHOME SCALE LOCK]"
		)
		and request_three.positive_prompt.contains(
			"35 percent"
		)
		and request_three.positive_prompt.contains(
			"10 percent"
		),
		"Evolution III request"
	)

	check(
		StageEvolutionService.new()
		.commit(
			PetRenderResult.ok(
				"user://m8_pet.png",
				&"test",
				&"test",
				{}
			)
		),
		"commit Evolution III"
	)

	var final_data := (
		EvolutionSaveService.new()
		.load_data()
	)
	check(
		int(
			final_data.get(
				"genome",
				{}
			).get(
				"stage",
				0
			)
		) == 4,
		"Evolution III commits final form"
	)
	check(
		int(
			final_data.get(
				"current_visual",
				{}
			).get(
				"visual_index",
				-1
			)
		) == 2,
		"visual history advances twice"
	)
	check(
		(
			final_data.get(
				"evolution_history",
				[]
			) as Array
		).size() == 2,
		"two evolution history entries"
	)

	var blocked := (
		StageEvolutionService.new()
		.prepare({
			"stage_index": 4,
			"ready_to_evolve": true,
		})
	)
	check(
		not bool(
			blocked.get(
				"ok",
				false
			)
		),
		"final form cannot evolve again in M8"
	)
