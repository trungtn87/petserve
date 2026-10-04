extends Node


var _failures: int = 0


func _ready() -> void:
	_test_standardized_consumables()
	_test_evolution_one_guarantees_stage2_gene()
	_test_stage2_activity_shared_pool_and_gene_guarantee()

	if _failures == 0:
		print("Stage 2 rewards: PASS")
		get_tree().quit(0)
		return

	push_error(
		"Stage 2 rewards: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_standardized_consumables() -> void:
	var generator := ItemGenerator.new()

	for rarity_value in ItemGenerator.RARITY_WEIGHTS.keys():
		var rarity := String(rarity_value)
		var food := ItemGenerator.normalize_item({
			"uid": "legacy_food_" + rarity,
			"item_type": "food",
			"rarity": rarity,
			"quality": "normal",
			"properties": ["dense"],
			"defects": [],
		})
		var growth := ItemGenerator.normalize_item({
			"uid": "legacy_growth_" + rarity,
			"item_type": "growth",
			"rarity": rarity,
			"quality": "good",
			"properties": ["rapid"],
			"defects": [],
		})

		_expect(
			String(food.get("display_name", "")) == "Khẩu phần dinh dưỡng"
			and String(food.get("rarity", "")) == rarity
			and String(food.get("quality", "")) == "standard"
			and not bool(food.get("is_junk", true))
			and int(food.get("main_value_seconds", 0))
				== int(ItemGenerator.FOOD_VALUE_SECONDS[rarity])
			and (food.get("properties", []) as Array).is_empty()
			and (food.get("defects", []) as Array).is_empty(),
			"Food must use one fixed catalog name/value per rarity"
		)

		_expect(
			String(growth.get("display_name", "")) == "Tinh chất tăng trưởng"
			and String(growth.get("rarity", "")) == rarity
			and String(growth.get("quality", "")) == "standard"
			and not bool(growth.get("is_junk", true))
			and int(growth.get("main_value_seconds", 0))
				== int(ItemGenerator.GROWTH_VALUE_SECONDS[rarity])
			and (growth.get("properties", []) as Array).is_empty()
			and (growth.get("defects", []) as Array).is_empty(),
			"Growth must use one fixed catalog name/value per rarity"
		)

	var stage2_food := generator.scale_for_stage(
		ItemGenerator.normalize_item({
			"uid": "legacy_food_stage2",
			"item_type": "food",
			"rarity": "rare",
			"quality": "normal",
			"properties": [],
			"defects": [],
		}),
		2
	)
	_expect(
		int(stage2_food.get("main_value_seconds", 0))
			== int(ItemGenerator.FOOD_VALUE_SECONDS["rare"]) * 12,
		"Stage 2 standardized food must retain the locked x12 scale"
	)

	var junk := ItemGenerator.normalize_item({
		"uid": "legacy_junk",
		"item_type": "food",
		"rarity": "legendary",
		"quality": "broken",
		"properties": [],
		"defects": ["rotten"],
	})
	_expect(
		bool(junk.get("is_junk", false))
		and String(junk.get("rarity", "not-empty")).is_empty()
		and String(junk.get("quality", "")) == "junk"
		and String(junk.get("display_name", "")) == "Thức ăn hỏng",
		"Junk must have no rarity and one fixed junk identity"
	)

	var meta := {
		"inventory": [junk],
	}
	var inventory := InventoryService.new()
	inventory.setup(meta)
	var stored := inventory.list_items()
	_expect(
		stored.size() == 1
		and not inventory.can_use_in_stage(
			stored[0],
			2
		),
		"Junk must be salvage-only instead of a usable Common item"
	)

	var found_junk := false
	var found_normal := false
	for seed_value in range(1, 500):
		var rolled := generator.generate(
			ItemGenerator.TYPE_FOOD,
			seed_value
		)
		if bool(rolled.get("is_junk", false)):
			found_junk = true
			_expect(
				String(rolled.get("rarity", "x")).is_empty(),
				"Rolled junk must not receive rarity"
			)
		else:
			found_normal = true
			_expect(
				ItemGenerator.RARITY_WEIGHTS.has(
					String(rolled.get("rarity", ""))
				),
				"Normal rolled food must receive a valid rarity"
			)

		if found_junk and found_normal:
			break

	_expect(
		found_junk and found_normal,
		"Consumable generator must be able to roll both normal and junk items"
	)


func _test_evolution_one_guarantees_stage2_gene() -> void:
	var meta := {
		"chest_queue": [],
	}
	var chests := ChestService.new()
	chests.setup(
		meta,
		ItemGenerator.new()
	)

	_expect(
		chests.ensure_evolution_chest(
			2001,
			1,
			2
		),
		"Evolution I chest must be queued"
	)

	var rewards := chests.open_next()
	var gene_count := 0

	for item in rewards:
		if StringName(
			item.get(
				"item_type",
				""
			)
		) != ItemGenerator.TYPE_GENE:
			continue

		gene_count += 1
		_expect(
			_is_valid_stage2_gene(
				item
			),
			"Evolution I Gene must be valid for Stage 2"
		)

	_expect(
		gene_count >= 1,
		"Evolution I must guarantee at least one Stage 2 Gene"
	)


func _test_stage2_activity_shared_pool_and_gene_guarantee() -> void:
	var seen_gene_positions: Dictionary = {}

	for run_id in range(
		4100,
		4104
	):
		var meta := {
			"chest_queue": [],
		}
		var chests := ChestService.new()
		chests.setup(
			meta,
			ItemGenerator.new()
		)
		var rewards := MiniGameRewardService.new()
		rewards.setup(
			meta,
			chests,
			run_id
		)

		var total_genes := 0
		var gene_reward_index := 0

		for reward_index in range(
			1,
			MiniGameRewardService.MAX_STAGE2_ACTIVITY_REWARDS + 1
		):
			var claim := (
				rewards.claim_obstacle_run(
					run_id,
					100,
					"obstacle_%s_%s"
					% [
						run_id,
						reward_index,
					]
				)
				if reward_index % 2 == 1
				else rewards.claim_snake_hunt(
					run_id,
					100,
					"snake_%s_%s"
					% [
						run_id,
						reward_index,
					]
				)
			)

			_expect(
				bool(
					claim.get(
						"rewarded",
						false
					)
				),
				"Vượt chướng ngại/Snake must share four Stage 2 reward claims"
			)

			var opened := chests.open_next()

			for item in opened:
				if StringName(
					item.get(
						"item_type",
						""
					)
				) != ItemGenerator.TYPE_GENE:
					continue

				total_genes += 1
				gene_reward_index = reward_index
				_expect(
					_is_valid_stage2_gene(
						item
					),
					"activity guaranteed Gene must be valid for Stage 2"
				)

			if reward_index == 2:
				# Simulate leaving/reloading the app. Reward counters must
				# continue from the same life instead of resetting daily.
				meta = meta.duplicate(
					true
				)
				chests = ChestService.new()
				chests.setup(
					meta,
					ItemGenerator.new()
				)
				rewards = MiniGameRewardService.new()
				rewards.setup(
					meta,
					chests,
					run_id
				)

		var snapshot := rewards.snapshot(
			run_id
		)
		_expect(
			int(
				snapshot.get(
					"stage2_activity_rewards_claimed",
					-1
				)
			) == 4
			and int(
				snapshot.get(
					"stage2_activity_rewards_remaining",
					-1
				)
			) == 0,
			"Stage 2 reward count must survive reload and stop at four"
		)

		var fifth := rewards.claim_obstacle_run(
			run_id,
			3000,
			"obstacle_%s_fifth"
			% run_id
		)
		_expect(
			not bool(
				fifth.get(
					"rewarded",
					true
				)
			),
			"fifth Vượt chướng ngại/Snake reward must be blocked by the shared cap"
		)

		_expect(
			total_genes == 1,
			"the four Stage 2 activity chests must guarantee exactly one Gene before optional Gene rates are designed"
		)

		if gene_reward_index > 0:
			seen_gene_positions[
				gene_reward_index
			] = true

	_expect(
		seen_gene_positions.size() == 4,
		"guaranteed Gene chest position must vary by life instead of being fixed"
	)


func _is_valid_stage2_gene(
	item: Dictionary
) -> bool:
	var policy := StageGenePolicy.load_default()

	if policy == null:
		return false

	var locus := StringName(
		item.get(
			"gene_locus",
			""
		)
	)

	if not policy.can_accept_gene(
		2,
		locus
	):
		return false

	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		StringName(
			item.get(
				"definition_id",
				""
			)
		)
	)

	return (
		definition != null
		and definition.locus() == locus
		and StringName(
			item.get(
				"gene_direction",
				""
			)
		) == definition.direction()
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
