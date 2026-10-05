extends Node


var _failures: int = 0


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	_test_unified_mystery_contract()
	_test_source_does_not_fix_quality()
	_test_stage_odds_only_improve()
	_test_each_rarity_contract()
	_test_gene_fragment_and_mythic_component_contract()

	if _failures == 0:
		print("CHEST SYSTEM V2: PASS")
		get_tree().quit(0)
		return

	push_error(
		"CHEST SYSTEM V2: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_unified_mystery_contract() -> void:
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
		"Evolution reward queues one chest"
	)

	var queued := chests.peek_next()
	_expect(
		StringName(
			queued.get(
				"chest_type",
				""
			)
		) == ChestService.CHEST_MYSTERY,
		"all new rewards use the shared mystery chest type"
	)
	_expect(
		String(
			queued.get(
				"source",
				""
			)
		) == String(
			ChestService.CHEST_EVOLUTION
		),
		"reward source is retained only as metadata"
	)
	_expect(
		int(
			queued.get(
				"stage_granted",
				0
			)
		) == 3,
		"chest freezes the stage at acquisition"
	)
	_expect(
		not queued.has(
			"chest_rarity"
		),
		"chest rarity is not fixed before opening"
	)

	var rewards := chests.open_next()
	_expect(
		rewards.size() >= 2
		and rewards.size() <= 5,
		"Chest v2 returns two to five items"
	)

	if rewards.is_empty():
		return

	var rarity := String(
		rewards[0].get(
			"chest_rarity",
			""
		)
	)
	_expect(
		rewards.size() == _expected_item_count(
			rarity
		),
		"item count is determined by revealed chest rarity"
	)
	_expect(
		_has_minimum_reward(
			rewards,
			rarity
		),
		"chest rarity guarantee survives junk rolls"
	)

	for item in rewards:
		_expect(
			String(
				item.get(
					"chest_rarity",
					""
				)
			) == rarity
			and int(
				item.get(
					"chest_stage",
					0
				)
			) == 3,
			"all rewards carry the same chest rarity and acquisition stage"
		)

	_expect(
		is_equal_approx(
			ChestService.ITEM_JUNK_CHANCE,
			0.10
		),
		"every reward slot starts with a 10 percent junk roll"
	)


func _test_source_does_not_fix_quality() -> void:
	var daily := _open_manual_chest(
		"same_seed_source_test",
		3,
		"daily"
	)
	var evolution := _open_manual_chest(
		"same_seed_source_test",
		3,
		"evolution"
	)

	_expect(
		_reward_signature(daily)
			== _reward_signature(evolution),
		"source must not alter chest rarity or loot"
	)


func _test_stage_odds_only_improve() -> void:
	for sample in range(64):
		var uid := "stage_curve_%d" % sample
		var previous_rank := 0

		for stage in range(
			1,
			StageLifecycle.FINAL_STAGE + 1
		):
			var rewards := _open_manual_chest(
				uid,
				stage,
				"test"
			)
			if rewards.is_empty():
				_expect(
					false,
					"stage curve chest must open"
				)
				continue

			var rank := _chest_rarity_rank(
				String(
					rewards[0].get(
						"chest_rarity",
						""
					)
				)
			)
			_expect(
				rank >= previous_rank,
				"later stages never worsen the same chest rarity roll"
			)
			previous_rank = rank


func _test_each_rarity_contract() -> void:
	var found: Dictionary = {}

	for sample in range(800):
		if found.size() >= 4:
			break

		var rewards := _open_manual_chest(
			"rarity_contract_%d" % sample,
			5,
			"test"
		)
		if rewards.is_empty():
			continue

		var rarity := String(
			rewards[0].get(
				"chest_rarity",
				""
			)
		)
		if found.has(rarity):
			continue

		found[rarity] = true
		_expect(
			rewards.size()
				== _expected_item_count(
					rarity
				),
			"%s chest item count matches v2 contract"
			% rarity
		)
		_expect(
			_has_minimum_reward(
				rewards,
				rarity
			),
			"%s chest meets its minimum rarity guarantee"
			% rarity
		)

	for rarity in [
		"common",
		"rare",
		"epic",
		"legendary",
	]:
		_expect(
			found.has(rarity),
			"fixture finds %s chest" % rarity
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
		) == 2,
		"duplicate Rare Gene still converts to two fragments"
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
		) == "mythic",
		"Mythic reward remains component-only"
	)


func _open_manual_chest(
	uid: String,
	stage: int,
	source: String
) -> Array[Dictionary]:
	var meta := {
		"inventory": [],
		"chest_queue": [
			{
				"uid": uid,
				"chest_type": String(
					ChestService.CHEST_MYSTERY
				),
				"source": source,
				"stage_index": stage,
				"stage_granted": stage,
				"opened": false,
			},
		],
	}
	var chests := ChestService.new()
	chests.setup(
		meta,
		ItemGenerator.new()
	)
	return chests.open_next()


func _expected_item_count(
	rarity: String
) -> int:
	match rarity:
		"rare":
			return 3
		"epic":
			return 4
		"legendary":
			return 5
		_:
			return 2


func _minimum_item_rank(
	chest_rarity: String
) -> int:
	match chest_rarity:
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		_:
			return 1


func _item_rarity_rank(
	rarity: String
) -> int:
	match rarity:
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		"legendary":
			return 5
		"mythic":
			return 6
		_:
			return 0


func _chest_rarity_rank(
	rarity: String
) -> int:
	match rarity:
		"common":
			return 1
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		_:
			return 0


func _has_minimum_reward(
	rewards: Array[Dictionary],
	chest_rarity: String
) -> bool:
	var minimum_rank := _minimum_item_rank(
		chest_rarity
	)

	for item in rewards:
		if bool(
			item.get(
				"is_junk",
				false
			)
		):
			continue
		if _item_rarity_rank(
			String(
				item.get(
					"rarity",
					""
				)
			)
		) >= minimum_rank:
			return true

	return false


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
				str(
					bool(
						item.get(
							"is_junk",
							false
						)
					)
				),
			]
		)

	return ";".join(parts)


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
