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
	_expect(rewards.claim_obstacle_run(4100, 100, "first").chests == 1, "first obstacle daily chest")
	_expect(rewards.claim_game(4100, 2, "tank", "first").chests == 1, "games have independent daily quotas")
	for i in 10:
		_expect(rewards.claim_obstacle_run(4101, 100, "extra_%d" % i).fragments == 1, "additional matches grant one fragment")
	meta = meta.duplicate(true)
	chests.setup(meta, ItemGenerator.new())
	rewards.setup(meta, chests, 4101)
	_expect(not rewards.claim_obstacle_run(4101, 100, "capped").rewarded, "quota survives reload and new life")


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
