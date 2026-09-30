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
	_test_hunger_thresholds()
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

	var early_meta: Dictionary = {}
	var early := StageLifecycle.new()
	early.setup(
		early_meta,
		502,
		2
	)
	check(
		early.apply_item({
			"item_type": "food",
			"display_name": "Early Food",
			"main_value_seconds": duration_two,
			"growth_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"Stage 2 must be fed before Growth acceleration"
	)
	check(
		early.apply_item({
			"item_type": "growth",
			"display_name": "Good Growth",
			"main_value_seconds": duration_two,
			"food_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"good Growth item can accelerate Stage 2"
	)
	var early_state := early.snapshot()
	check(
		bool(
			early_state.get(
				"ready_to_evolve",
				false
			)
		)
		and not bool(
			early_state.get(
				"deadline_reached",
				true
			)
		),
		"Stage 2 may become READY before the 48-hour age deadline"
	)

	var trash_meta: Dictionary = {}
	var trash := StageLifecycle.new()
	trash.setup(
		trash_meta,
		503,
		2
	)
	check(
		trash.apply_item({
			"item_type": "food",
			"display_name": "Trash Test Food",
			"main_value_seconds": duration_two,
			"growth_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"Stage 2 trash test starts fully fed"
	)
	check(
		trash.apply_item({
			"item_type": "growth",
			"display_name": "Growth Setup",
			"main_value_seconds": int(duration_two / 4),
			"food_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"Stage 2 growth setup item applies"
	)
	var age_before_trash := int(
		trash.snapshot().get(
			"age_elapsed_seconds",
			-1
		)
	)
	check(
		trash.apply_item({
			"item_type": "growth",
			"display_name": "Trash Growth",
			"main_value_seconds": -int(duration_two / 4),
			"food_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"trash Growth item is allowed to reduce Growth"
	)
	var after_trash := trash.snapshot()
	check(
		int(
			after_trash.get(
				"growth_percent",
				-1
			)
		) == 0
		and int(
			after_trash.get(
				"age_elapsed_seconds",
				-2
			)
		) == age_before_trash,
		"trash item reduces Growth without reducing Stage age"
	)
	trash.tick(
		float(
			duration_two
		)
	)
	var deadline_state := trash.snapshot()
	check(
		int(
			deadline_state.get(
				"growth_percent",
				0
			)
		) == 20
		and bool(
			deadline_state.get(
				"deadline_reached",
				false
			)
		)
		and not bool(
			deadline_state.get(
				"ready_to_evolve",
				true
			)
		)
		and bool(
			deadline_state.get(
				"hibernating",
				false
			)
		),
		"one fixed food tank slows to hibernation and deadline no longer forces READY"
	)
	var locked_growth := int(
		deadline_state.get(
			"growth_percent",
			-1
		)
	)
	check(
		not bool(
			trash.apply_item({
				"item_type": "growth",
				"display_name": "Late Trash",
				"main_value_seconds": -duration_two,
				"food_delta_seconds": 0,
			}).get(
				"ok",
				true
			)
		)
		and int(
			trash.snapshot().get(
				"growth_percent",
				-2
			)
		) == locked_growth,
		"hibernation blocks Growth items after food reaches zero"
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
	var first_food_cycle := life.snapshot()
	check(
		not bool(
			first_food_cycle.get(
				"ready_to_evolve",
				true
			)
		)
		and bool(
			first_food_cycle.get(
				"hibernating",
				false
			)
		),
		"one full food cycle does not bypass hunger penalties"
	)
	check(
		life.apply_item({
			"item_type": "food",
			"display_name": "Second Test Food",
			"main_value_seconds": duration_two,
			"growth_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"stage 2 can wake from hibernation"
	)
	check(
		life.apply_item({
			"item_type": "growth",
			"display_name": "Fed Growth Finish",
			"main_value_seconds": duration_two,
			"food_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"fed pet accepts Growth item after waking"
	)
	check(
		bool(
			life.snapshot().get(
				"ready_to_evolve",
				false
			)
		),
		"stage 2 becomes ready only after real Growth reaches 100 percent"
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
				-1
			)
		) == 0
		and int(
			starved_state.get(
				"growth_speed_percent",
				-1
			)
		) == 0
		and bool(
			starved_state.get(
				"hibernating",
				false
			)
		),
		"zero fullness hibernates and produces no Growth"
	)
	check(
		bool(
			starved_state.get(
				"deadline_reached",
				false
			)
		)
		and not bool(
			starved_state.get(
				"ready_to_evolve",
				true
			)
		),
		"age deadline cannot evolve a hibernating pet"
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
	check(
		life.apply_item({
			"item_type": "growth",
			"display_name": "Stage 3 Growth Finish",
			"main_value_seconds": duration_three,
			"food_delta_seconds": 0,
		}).get(
			"ok",
			false
		),
		"fed Stage 3 accepts Growth item"
	)
	check(
		bool(
			life.snapshot().get(
				"ready_to_evolve",
				false
			)
		),
		"stage 3 becomes ready after Growth reaches 100 percent"
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


func _test_hunger_thresholds() -> void:
	var meta: Dictionary = {}
	var life := StageLifecycle.new()
	life.setup(
		meta,
		550,
		2
	)

	check(
		bool(
			life.snapshot().get(
				"hibernating",
				false
			)
		),
		"fresh Stage 2 with zero food starts hibernating"
	)
	check(
		not bool(
			life.apply_item({
				"item_type": "growth",
				"display_name": "Blocked Growth",
				"main_value_seconds": 600,
				"food_delta_seconds": 0,
			}).get(
				"ok",
				true
			)
		),
		"Growth item cannot develop a hibernating pet"
	)

	var food_capacity := int(
		life.snapshot().get(
			"food_capacity_seconds",
			0
		)
	)
	check(
		food_capacity > 0,
		"Stage 2 exposes fixed food capacity"
	)
	check(
		bool(
			life.apply_item({
				"item_type": "food",
				"display_name": "Threshold Food",
				"main_value_seconds": food_capacity,
				"growth_delta_seconds": 0,
			}).get(
				"ok",
				false
			)
		),
		"food wakes pet"
	)
	var full := life.snapshot()
	check(
		int(
			full.get(
				"food_percent",
				-1
			)
		) == 100
		and int(
			full.get(
				"growth_speed_percent",
				-1
			)
		) == 100
		and not bool(
			full.get(
				"hibernating",
				true
			)
		),
		"above 50 percent fullness grows at 100 percent speed"
	)

	life.tick(
		float(food_capacity) * 0.5
	)
	var half := life.snapshot()
	check(
		int(
			half.get(
				"food_percent",
				-1
			)
		) == 50
		and int(
			half.get(
				"growth_speed_percent",
				-1
			)
		) == 75
		and int(
			meta.life_state.get(
				"growth_elapsed_seconds",
				-1
			)
		) == int(
			float(food_capacity) * 0.5
		),
		"50 percent fullness switches to 75 percent speed"
	)

	life.tick(
		float(food_capacity) * 0.25
	)
	var quarter := life.snapshot()
	check(
		int(
			quarter.get(
				"food_percent",
				-1
			)
		) == 25
		and int(
			quarter.get(
				"growth_speed_percent",
				-1
			)
		) == 50
		and int(
			round(
				float(
					meta.life_state.get(
						"growth_elapsed_seconds",
						-1.0
					)
				)
			)
		) == int(
			round(
				float(food_capacity) * 0.6875
			)
		),
		"25 percent fullness switches to 50 percent speed"
	)

	life.tick(
		float(food_capacity) * 0.25
	)
	var empty := life.snapshot()
	var frozen_growth := float(
		meta.life_state.get(
			"growth_elapsed_seconds",
			-1.0
		)
	)
	check(
		int(
			empty.get(
				"food_percent",
				-1
			)
		) == 0
		and int(
			empty.get(
				"growth_speed_percent",
				-1
			)
		) == 0
		and bool(
			empty.get(
				"hibernating",
				false
			)
		)
		and int(
			round(
				frozen_growth
			)
		) == int(
			round(
				float(food_capacity) * 0.8125
			)
		),
		"zero fullness enters hibernation after piecewise growth"
	)

	life.tick(
		600.0
	)
	check(
		is_equal_approx(
			float(
				meta.life_state.get(
					"growth_elapsed_seconds",
					-2.0
				)
			),
			frozen_growth
		),
		"hibernation freezes Growth until food returns"
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
		) == OS.is_debug_build(),
		"debug build exposes the reopened instant evolution talent"
	)
	check(
		not bool(
			dev_state.get(
				"ready_to_evolve",
				true
			)
		),
		"fresh Stage 2 is not naturally READY"
	)
	check(
		bool(
			dev_state.get(
				"instant_evolution_talent",
				false
			)
		) == OS.is_debug_build(),
		"instant evolution talent is auto-granted only in debug builds"
	)

	if OS.is_debug_build():
		check(
			game.set_dev_instant_evolution_enabled(
				true
			),
			"debug build can explicitly enable instant evolution"
		)
		var override_state := game.snapshot()
		check(
			bool(
				override_state.get(
					"can_evolve",
					false
				)
			)
			and not bool(
				override_state.get(
					"ready_to_evolve",
					true
				)
			)
			and bool(
				override_state.get(
					"instant_evolution_talent",
					false
				)
			),
			"debug override bypasses only can_evolve, not natural READY"
		)
		check(
			game.set_dev_instant_evolution_enabled(
				false
			),
			"debug instant evolution can be disabled again"
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
			"_pethome_v11_stage_3"
		)
		and request_two.positive_prompt.contains(
			"[PETHOME SCALE LOCK]"
		)
		and request_two.positive_prompt.contains(
			"28 to 32 percent"
		)
		and request_two.positive_prompt.contains(
			"65 to 70 percent"
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
			"_pethome_v11_stage_4"
		)
		and request_three.positive_prompt.contains(
			"[PETHOME SCALE LOCK]"
		)
		and request_three.positive_prompt.contains(
			"28 to 32 percent"
		)
		and request_three.positive_prompt.contains(
			"65 to 70 percent"
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
