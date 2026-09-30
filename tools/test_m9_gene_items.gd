extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_test_catalog_and_visual_contract()
	_test_inventory_stage_gate()
	_test_stage_one_two_slot_facade()

	if _failures == 0:
		print("M9.3 Gene Items: PASS")
		quit(0)
		return
	push_error("M9.3 Gene Items: FAIL (%d)" % _failures)
	quit(1)


func _test_catalog_and_visual_contract() -> void:
	var policy := StageGenePolicy.load_default()
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var visual_catalog := MutationVisualCatalog.new()
	var visuals := visual_catalog.load_default()

	_expect(definitions.size() == 17, "Gene catalog must contain 17 definitions across all 12 loci")

	for stage_index in [1, 2, 3]:
		for definition in definitions:
			if definition == null or not policy.can_accept_gene(stage_index, definition.locus()):
				continue
			var mutation_id := StringName("gene_expr_%s_s%d" % [String(definition.id()), stage_index])
			var visual := visual_catalog.find_by_id(visuals, mutation_id)
			_expect(
				visual != null and visual.target_region() == definition.locus(),
				"Gene visual missing for %s" % String(mutation_id)
			)


func _test_inventory_stage_gate() -> void:
	var definitions := GeneCatalog.new().load_default()
	var whiskers := GeneCatalog.new().find_by_id(definitions, &"whiskers_starlight")
	var tail := GeneCatalog.new().find_by_id(definitions, &"tail_long")
	_expect(whiskers != null and tail != null, "inventory Gene fixtures exist")
	if whiskers == null or tail == null:
		return

	var generator := ItemGenerator.new()
	var whisker_item := generator.generate_gene(whiskers, 91001)
	var tail_item := generator.generate_gene(tail, 91002)
	var policy := StageGenePolicy.load_default()
	var inventory := InventoryService.new()
	inventory.setup({"inventory": [whisker_item, tail_item]})

	_expect(inventory.can_use_in_stage(whisker_item, 1, policy), "Stage 1 accepts whiskers")
	_expect(not inventory.can_use_in_stage(tail_item, 1, policy), "Stage 1 rejects tail")
	_expect(not inventory.can_use_in_stage(whisker_item, 2, policy), "Stage 2 rejects Stage 1 whiskers")
	_expect(inventory.can_use_in_stage(tail_item, 2, policy), "Stage 2 accepts tail")


func _test_stage_one_two_slot_facade() -> void:
	SaveManager.delete_meta()
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var whiskers := catalog.find_by_id(definitions, &"whiskers_starlight")
	var mark := catalog.find_by_id(definitions, &"mark_moon")
	var eyes := catalog.find_by_id(definitions, &"eyes_luminous")
	if whiskers == null or mark == null or eyes == null:
		_expect(false, "Stage 1 Gene fixtures must exist")
		return

	var generator := ItemGenerator.new()
	var first := generator.generate_gene(whiskers, 92001)
	var second := generator.generate_gene(mark, 92002)
	var third := generator.generate_gene(eyes, 92003)
	_expect(
		SaveManager.save_meta({
			"schema": 3,
			"inventory": [first, second, third],
			"chest_queue": []
		}),
		"save Stage 1 inventory fixture"
	)

	var game := InfantGameFacade.new()
	_expect(game.setup(920, 1), "Stage 1 facade setup")
	_expect(game.can_use_item(first), "first Stage 1 Gene is usable")
	_expect(bool(game.use_item(String(first.get("uid", ""))).get("ok", false)), "use first Stage 1 Gene")
	_expect(game.can_use_item(second), "second Stage 1 Gene is usable")
	_expect(bool(game.use_item(String(second.get("uid", ""))).get("ok", false)), "use second Stage 1 Gene")

	var state := game.snapshot()
	_expect(
		int(state.get("gene_items_used", -1)) == 2
		and int(state.get("gene_slots_remaining", -1)) == 0,
		"Stage 1 exposes and consumes exactly two Gene slots"
	)
	_expect(not game.can_use_item(third), "third Stage 1 Gene is blocked by cap")
	SaveManager.delete_meta()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
