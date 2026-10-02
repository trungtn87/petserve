extends Node


var _failures: int = 0


func _ready() -> void:
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
			bool(
				fifth.get(
					"rewarded",
					false
				)
			)
			and String(
				fifth.get(
					"reward_type",
					""
				)
			) == "fragment"
			and chests.fragment_count() == 1,
			"fifth Vượt chướng ngại/Snake reward must fall back to one chest fragment"
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
