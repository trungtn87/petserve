extends Node


var _failures: int = 0


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	_test_stage3_unlock_and_four_roll_contract()
	_test_recycled_chest_uses_stage3_tier()
	_test_tier3_roll_is_deterministic()
	_test_gene_fragment_and_mythic_component_contract()

	if _failures == 0:
		print("STAGE3 TIER III CHEST: PASS")
		get_tree().quit(0)
		return

	push_error(
		"STAGE3 TIER III CHEST: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_stage3_unlock_and_four_roll_contract() -> void:
	var meta := {
		"inventory": [],
		"chest_queue": [],
	}
	var chests := ChestService.new()
	chests.setup(
		meta,
		ItemGenerator.new()
	)

	_expect(
		chests.ensure_evolution_chest(
			3003,
			2,
			3
		),
		"Evolution II -> Stage 3 queues milestone chest"
	)

	var queued := chests.peek_next()
	_expect(
		int(
			queued.get(
				"stage_index",
				0
			)
		) == 3
		and int(
			queued.get(
				"chest_tier",
				0
			)
		) == ChestService.STAGE3_TIER,
		"Stage 3 milestone chest is marked Tier III"
	)

	var rewards := chests.open_next()
	_expect(
		rewards.size() >= 3
		and rewards.size() <= 4,
		"Tier III chest returns Survival + Wild + Evolution and optional Jackpot"
	)

	var rolls: Dictionary = {}

	for item in rewards:
		var roll_name := String(
			item.get(
				"chest_roll",
				""
			)
		)
		rolls[roll_name] = true

		_expect(
			int(
				item.get(
					"chest_tier",
					0
				)
			) == 3,
			"every Tier III reward keeps chest tier metadata"
		)

		_expect(
			not (
				StringName(
					item.get(
						"item_type",
						""
					)
				) == ItemGenerator.TYPE_GENE
				and String(
					item.get(
						"rarity",
						""
					)
				) == "mythic"
			),
			"Tier III never drops a complete Mythic Gene"
		)

	var survival := _find_roll(
		rewards,
		"survival"
	)
	var survival_defects: Variant = survival.get(
		"defects",
		[]
	)

	_expect(
		rolls.has("survival")
		and rolls.has("wild")
		and rolls.has("evolution"),
		"Tier III exposes all three guaranteed roll channels"
	)
	_expect(
		not survival.is_empty()
		and typeof(survival_defects) == TYPE_ARRAY
		and (survival_defects as Array).is_empty(),
		"Survival roll is always defect-free"
	)


func _test_recycled_chest_uses_stage3_tier() -> void:
	var meta := {
		"inventory": [],
		"chest_queue": [],
	}
	var chests := ChestService.new()
	chests.setup(
		meta,
		ItemGenerator.new()
	)

	_expect(
		chests.add_salvage_fragments(
			ChestService.FRAGMENTS_PER_RECYCLED_CHEST,
			91,
			3
		) == 1,
		"ten Stage 3 chest fragments craft one recycled chest"
	)

	var rewards := chests.open_next()
	_expect(
		rewards.size() >= 3,
		"Stage 3 recycled chest upgrades to Tier III loot"
	)

	for item in rewards:
		_expect(
			int(
				item.get(
					"chest_tier",
					0
				)
			) == 3,
			"recycled Stage 3 rewards are tagged Tier III"
		)


func _test_tier3_roll_is_deterministic() -> void:
	var first := _open_stage3_fixture(
		777
	)
	var second := _open_stage3_fixture(
		777
	)

	_expect(
		_reward_signature(first)
			== _reward_signature(second),
		"same chest uid must resolve to the same Tier III rewards"
	)


func _test_gene_fragment_and_mythic_component_contract() -> void:
	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		&"tail_long"
	)
	_expect(
		definition != null,
		"Gene fragment fixture exists"
	)
	if definition == null:
		return

	var generator := ItemGenerator.new()
	var rare_gene := generator.generate_gene_for_rarity(
		definition,
		44001,
		"rare"
	)
	var duplicate_fragment := generator.generate_gene_fragment(
		rare_gene,
		44002,
		generator.duplicate_gene_fragment_amount(
			"rare"
		)
	)

	_expect(
		StringName(
			duplicate_fragment.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_GENE_FRAGMENT
		and int(
			duplicate_fragment.get(
				"fragment_quantity",
				0
			)
		) == 2
		and String(
			duplicate_fragment.get(
				"target_gene_id",
				""
			)
		) == String(
			rare_gene.get(
				"gene_id",
				""
			)
		),
		"duplicate Rare Gene converts to two fragments for the same Gene"
	)

	_expect(
		generator.duplicate_gene_fragment_amount(
			"epic"
		) == 4
		and generator.duplicate_gene_fragment_amount(
			"legendary"
		) == 7,
		"duplicate fragment amounts follow Tier III v1 contract"
	)

	var mythic := generator.generate_mythic_component(
		55001
	)
	_expect(
		StringName(
			mythic.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_MYTHIC_COMPONENT
		and String(
			mythic.get(
				"rarity",
				""
			)
		) == "mythic"
		and bool(
			mythic.get(
				"mythic_component",
				false
			)
		),
		"Jackpot Mythic result is component-only"
	)


func _open_stage3_fixture(
	run_id: int
) -> Array[Dictionary]:
	var meta := {
		"inventory": [],
		"chest_queue": [],
	}
	var chests := ChestService.new()
	chests.setup(
		meta,
		ItemGenerator.new()
	)
	chests.ensure_evolution_chest(
		run_id,
		2,
		3
	)
	return chests.open_next()


func _find_roll(
	rewards: Array[Dictionary],
	roll_name: String
) -> Dictionary:
	for item in rewards:
		if String(
			item.get(
				"chest_roll",
				""
			)
		) == roll_name:
			return item

	return {}


func _reward_signature(
	rewards: Array[Dictionary]
) -> String:
	var parts: Array[String] = []

	for item in rewards:
		parts.append(
			"%s|%s|%s|%s"
			% [
				String(
					item.get(
						"chest_roll",
						""
					)
				),
				String(
					item.get(
						"item_type",
						""
					)
				),
				String(
					item.get(
						"definition_id",
						""
					)
				),
				String(
					item.get(
						"rarity",
						""
					)
				),
			]
		)

	return ";".join(
		parts
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
