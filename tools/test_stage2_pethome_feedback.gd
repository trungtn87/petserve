extends Node


var _failures: int = 0


func _ready() -> void:
	_test_gene_item_context_and_stage2_score()
	_test_hibernating_stage2_keeps_remaining_activity_rewards()

	SaveManager.delete_meta()

	if _failures == 0:
		print(
			"Stage 2 PetHome feedback: PASS"
		)
		get_tree().quit(0)
		return

	push_error(
		"Stage 2 PetHome feedback: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_gene_item_context_and_stage2_score() -> void:
	SaveManager.delete_meta()

	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var body := catalog.find_by_id(
		definitions,
		&"body_sturdy"
	)
	var tail := catalog.find_by_id(
		definitions,
		&"tail_long"
	)

	_expect(
		body != null
		and tail != null,
		"Gene fixtures must exist"
	)

	if body == null or tail == null:
		return

	var generator := ItemGenerator.new()
	var body_one := generator.generate_gene(
		body,
		91001
	)
	var body_two := generator.generate_gene(
		body,
		91002
	)
	var tail_item := generator.generate_gene(
		tail,
		91004
	)
	var food_item := generator.generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		91003,
		2
	)

	_expect(
		SaveManager.save_meta({
			"schema": InfantGameFacade.META_SCHEMA,
			"inventory": [
				food_item,
				body_one,
				body_two,
				tail_item,
			],
			"chest_queue": [],
		}),
		"save Gene score inventory fixture"
	)

	var game := InfantGameFacade.new()

	_expect(
		game.setup(
			9100,
			2,
			&"dark"
		),
		"setup Stage 2 facade"
	)

	_expect(
		bool(
			game.use_item(
				String(
					food_item.get(
						"uid",
						""
					)
				)
			).get(
				"ok",
				false
			)
		),
		"Stage 2 Gene fixture must feed the pet before Gene use"
	)

	var before_gene_growth := int(
		game.snapshot().get(
			"growth_percent",
			-1
		)
	)

	var initial := game.gene_item_context(
		body_one
	)
	var stages_value: Variant = initial.get(
		"allowed_stages",
		[]
	)
	var first_score := float(
		body_one.get(
			"gene_score",
			0.0
		)
	)

	_expect(
		int(
			initial.get(
				"current_stage",
				0
			)
		) == 2
		and is_equal_approx(
			float(
				initial.get(
					"current_score",
					-1.0
				)
			),
			0.0
		)
		and is_equal_approx(
			float(
				initial.get(
					"projected_score",
					-1.0
				)
			),
			first_score
		)
		and typeof(stages_value) == TYPE_ARRAY
		and (stages_value as Array).has(1)
		and (stages_value as Array).has(2)
		and (stages_value as Array).has(3),
		"Gene detail must expose score projection and unlimited growth-stage validity"
	)

	_expect(
		bool(
			game.use_item(
				String(
					body_one.get(
						"uid",
						""
					)
				)
			).get(
				"ok",
				false
			)
		),
		"first Stage 2 Gene can be used"
	)

	var after_first_gene_growth := int(
		game.snapshot().get(
			"growth_percent",
			-1
		)
	)
	var first_growth_bonus := int(
		round(
			float(
				body_one.get(
					"growth_bonus_percent",
					0.0
				)
			)
		)
	)

	_expect(
		after_first_gene_growth == mini(
			100,
			before_gene_growth + first_growth_bonus
		),
		"Stage 2 Gene Item must add rarity-specific Growth bonus"
	)

	var after_one := game.gene_item_context(
		body_two
	)
	var second_score := float(
		body_two.get(
			"gene_score",
			0.0
		)
	)

	_expect(
		is_equal_approx(
			float(
				after_one.get(
					"current_score",
					-1.0
				)
			),
			first_score
		)
		and is_equal_approx(
			float(
				after_one.get(
					"projected_score",
					-1.0
				)
			),
			first_score + second_score
		)
		and bool(
			after_one.get(
				"usable_now",
				false
			)
		),
		"same-direction Gene must preview cumulative score instead of remaining slots"
	)

	_expect(
		bool(
			game.use_item(
				String(
					body_two.get(
						"uid",
						""
					)
				)
			).get(
				"ok",
				false
			)
		),
		"second same-direction Gene can stack"
	)

	_expect(
		game.can_use_item(
			tail_item
		)
		and bool(
			game.use_item(
				String(
					tail_item.get(
						"uid",
						""
					)
				)
			).get(
				"ok",
				false
			)
		),
		"third Stage 2 Gene remains usable because slot cap is removed"
	)

	var state := game.snapshot()
	_expect(
		int(
			state.get(
				"gene_items_used",
				-1
			)
		) == 3
		and int(
			state.get(
				"gene_slots_remaining",
				0
			)
		) == -1
		and bool(
			state.get(
				"gene_unlimited",
				false
			)
		),
		"PetHome state must expose unlimited Stage 2 Gene use"
	)

	SaveManager.delete_meta()


func _test_hibernating_stage2_keeps_remaining_activity_rewards() -> void:
	SaveManager.delete_meta()

	var game := InfantGameFacade.new()

	_expect(
		game.setup(
			9200,
			2
		),
		"setup reward Stage 2 facade"
	)

	var start := game.snapshot()
	var duration := int(
		start.get(
			"duration_seconds",
			0
		)
	)

	_expect(
		duration == 48 * 60 * 60
		and int(
			start.get(
				"age_remaining_seconds",
				-1
			)
		) == duration,
		"PetHome deadline source must start from the independent 48-hour Stage age"
	)

	game.tick(
		float(
			duration
		)
	)

	var ready := game.snapshot()

	_expect(
		not bool(
			ready.get(
				"ready_to_evolve",
				true
			)
		)
		and bool(
			ready.get(
				"deadline_reached",
				false
			)
		)
		and int(
			ready.get(
				"age_remaining_seconds",
				-1
			)
		) == 0
		and int(
			ready.get(
				"growth_percent",
				-1
			)
		) == 0
		and bool(
			ready.get(
				"hibernating",
				false
			)
		),
		"deadline cannot bypass zero-food hibernation"
	)

	var reward := game.claim_obstacle_run_reward(
		100,
		"ready_stage2_obstacle"
	)

	_expect(
		bool(
			reward.get(
				"rewarded",
				false
			)
		),
		"hibernating Stage 2 must still allow an unclaimed Vượt chướng ngại/Snake reward"
	)

	var after_reward := game.snapshot()

	_expect(
		int(
			reward.get(
				"fragments",
				0
			)
		) == 1
		and int(
			after_reward.get(
				"chest_fragments",
				0
			)
		) == 1
		and int(
			after_reward.get(
				"stage2_activity_rewards_claimed",
				-1
			)
		) == 0,
		"Food Catch reward is score-based and does not consume the retired daily obstacle chest quota"
	)

	SaveManager.delete_meta()


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
