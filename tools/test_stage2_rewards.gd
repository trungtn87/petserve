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
	var meta: Dictionary = {}
	var chests := ChestService.new()
	chests.setup(meta, ItemGenerator.new())
	var rewards := MiniGameRewardService.new()
	rewards.setup(meta, chests, 4100)

	var food_catch := rewards.claim_obstacle_run(
		4100,
		100,
		"first"
	)
	_expect(
		int(food_catch.get("fragments", 0)) == 1
		and int(food_catch.get("chests", 0)) == 0,
		"Food Catch pays by score instead of the retired daily obstacle chest"
	)
	_expect(
		not bool(
			rewards.claim_obstacle_run(
				4100,
				100,
				"first"
			).get(
				"rewarded",
				true
			)
		),
		"Food Catch match ID cannot claim twice"
	)

	var tank := rewards.claim_game(
		4100,
		2,
		"tank",
		"tank_first"
	)
	_expect(
		int(tank.get("chests", 0)) == 1,
		"standard mini-games keep their independent daily chest quota"
	)

	var high_score := rewards.claim_obstacle_run(
		4100,
		2500,
		"high_score"
	)
	_expect(
		int(high_score.get("fragments", 0)) == 5,
		"Food Catch score tier converts every 500 points to one chest fragment"
	)

	meta = meta.duplicate(true)
	chests.setup(meta, ItemGenerator.new())
	rewards.setup(meta, chests, 4101)

	_expect(
		not bool(
			rewards.claim_game(
				4101,
				2,
				"tank",
				"tank_first"
			).get(
				"rewarded",
				true
			)
		),
		"standard game daily reward state survives reload and new life"
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
