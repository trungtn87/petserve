extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_test_gene_item_context_and_stage2_limit()
	_test_ready_stage2_keeps_remaining_activity_rewards()

	SaveManager.delete_meta()

	if _failures == 0:
		print(
			"Stage 2 PetHome feedback: PASS"
		)
		quit(0)
		return

	push_error(
		"Stage 2 PetHome feedback: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_gene_item_context_and_stage2_limit() -> void:
	SaveManager.delete_meta()

	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var eyes := catalog.find_by_id(
		definitions,
		&"eyes_moon"
	)
	var mark := catalog.find_by_id(
		definitions,
		&"mark_moon"
	)

	_expect(
		eyes != null
		and mark != null,
		"Gene fixtures must exist"
	)

	if eyes == null or mark == null:
		return

	var generator := ItemGenerator.new()
	var eye_item := generator.generate_gene(
		eyes,
		91001
	)
	var mark_item := generator.generate_gene(
		mark,
		91002
	)

	_expect(
		SaveManager.save_meta({
			"schema": InfantGameFacade.META_SCHEMA,
			"inventory": [
				eye_item,
				mark_item,
			],
			"chest_queue": [],
		}),
		"save Gene inventory fixture"
	)

	var game := InfantGameFacade.new()

	_expect(
		game.setup(
			9100,
			2
		),
		"setup Stage 2 facade"
	)

	var initial := game.gene_item_context(
		eye_item
	)
	var stages_value: Variant = initial.get(
		"allowed_stages",
		[]
	)

	_expect(
		int(
			initial.get(
				"current_stage",
				0
			)
		) == 2
		and int(
			initial.get(
				"used",
				-1
			)
		) == 0
		and int(
			initial.get(
				"limit",
				0
			)
		) == 2
		and int(
			initial.get(
				"remaining",
				-1
			)
		) == 2
		and not bool(
			initial.get(
				"exhausted",
				true
			)
		)
		and typeof(stages_value) == TYPE_ARRAY
		and (stages_value as Array).has(
			2
		),
		"Gene detail must expose target validity and 0/2 Stage 2 usage"
	)

	_expect(
		bool(
			game.use_item(
				String(
					eye_item.get(
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

	var after_one := game.gene_item_context(
		mark_item
	)

	_expect(
		int(
			after_one.get(
				"used",
				-1
			)
		) == 1
		and int(
			after_one.get(
				"remaining",
				-1
			)
		) == 1
		and bool(
			after_one.get(
				"usable_now",
				false
			)
		),
		"Gene detail must show one remaining Stage 2 use"
	)

	_expect(
		bool(
			game.use_item(
				String(
					mark_item.get(
						"uid",
						""
					)
				)
			).get(
				"ok",
				false
			)
		),
		"second Stage 2 Gene can be used"
	)

	var exhausted := game.gene_item_context(
		mark_item
	)

	_expect(
		int(
			exhausted.get(
				"used",
				-1
			)
		) == 2
		and int(
			exhausted.get(
				"remaining",
				-1
			)
		) == 0
		and bool(
			exhausted.get(
				"exhausted",
				false
			)
		)
		and not bool(
			exhausted.get(
				"usable_now",
				true
			)
		),
		"Gene detail must explicitly report exhausted 2/2 usage"
	)

	SaveManager.delete_meta()


func _test_ready_stage2_keeps_remaining_activity_rewards() -> void:
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
		bool(
			ready.get(
				"ready_to_evolve",
				false
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
				100
			)
		) < 100,
		"deadline can make Stage 2 READY independently of Growth"
	)

	var reward := game.claim_maze_hunt_reward(
		100,
		"ready_stage2_maze"
	)

	_expect(
		bool(
			reward.get(
				"rewarded",
				false
			)
		),
		"READY Stage 2 must still allow an unclaimed Maze/Snake reward"
	)

	var after_reward := game.snapshot()

	_expect(
		int(
			after_reward.get(
				"stage2_activity_rewards_claimed",
				-1
			)
		) == 1
		and int(
			after_reward.get(
				"stage2_activity_rewards_remaining",
				-1
			)
		) == 3,
		"shared Stage 2 activity counter must expose three chests remaining"
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
