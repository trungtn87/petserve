extends Node

var _failures: int = 0

func _ready() -> void:
	_test_catalog_contract()
	_test_rarity_score_contract()
	_test_inventory_stage_gate()
	_test_unlimited_facade()
	_test_element_effect_gate()

	if _failures == 0:
		print("M9.3 Gene Items: PASS")
		get_tree().quit(0)
		return
	push_error("M9.3 Gene Items: FAIL (%d)" % _failures)
	get_tree().quit(1)


func _test_catalog_contract() -> void:
	var definitions := GeneCatalog.new().load_default()
	var shared_count := 0
	var effect_count := 0
	var loci: Dictionary = {}

	_expect(definitions.size() == 64, "Gene catalog must contain 64 base definitions")

	for definition in definitions:
		if definition == null:
			continue
		loci[String(definition.locus())] = true
		_expect(
			not definition.prompt_stem().is_empty(),
			"every Gene must define score-prompt metadata: %s" % String(definition.id())
		)
		if definition.locus() in [&"mark", &"aura"]:
			effect_count += 1
			_expect(
				not String(definition.element_lock()).is_empty(),
				"mark/aura Gene must be element locked: %s" % String(definition.id())
			)
		else:
			shared_count += 1
			_expect(
				String(definition.element_lock()).is_empty(),
				"physical Gene must be shared: %s" % String(definition.id())
			)

	_expect(shared_count == 50, "Gene catalog must contain 50 shared physical Genes")
	_expect(effect_count == 14, "Gene catalog must contain 14 element effect Genes")
	_expect(loci.size() == 12, "all 12 visual loci must have Gene content")


func _test_rarity_score_contract() -> void:
	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		&"fur_sleek"
	)
	_expect(definition != null, "rarity fixture exists")
	if definition == null:
		return

	var generator := ItemGenerator.new()
	var expected_scores := {
		"common": 25.0,
		"uncommon": 60.0,
		"rare": 120.0,
		"epic": 200.0,
		"legendary": 320.0,
	}

	for rarity_value in expected_scores.keys():
		var rarity_key := String(rarity_value)
		var score := generator.gene_score_for_rarity(
			rarity_key
		)
		_expect(
			is_equal_approx(
				score,
				float(expected_scores[rarity_key])
			)
			and GeneExpressionScale.tier_for_score(score)
				!= GeneExpressionScale.TRACE,
			"every new Gene rarity must be visually meaningful on first use: %s"
			% rarity_key
		)

	var legacy_gene := ItemGenerator.normalize_item({
		"uid": "legacy_gene_common",
		"item_type": "gene",
		"item_schema_version": 2,
		"rarity": "common",
		"quality": "standard",
		"gene_score": 10.0,
		"gene_influence": 10.0,
		"growth_bonus_percent": 2.0,
		"influence_tags": {
			"mystic": 3.0,
		},
		"properties": [],
		"defects": [],
	})
	_expect(
		int(legacy_gene.get("item_schema_version", 0))
			== ItemGenerator.ITEM_SCHEMA_VERSION
		and is_equal_approx(
			float(legacy_gene.get("gene_score", 0.0)),
			25.0
		)
		and String(
			legacy_gene.get(
				"gene_expression_tier",
				""
			)
		) == "developing",
		"legacy Gene items in inventory must migrate to the visible-impact score table"
	)

	for seed_value in range(93000, 93120):
		var item := generator.generate_gene(definition, seed_value)
		var rarity := String(item.get("rarity", ""))
		_expect(
			is_equal_approx(
				float(item.get("gene_score", 0.0)),
				generator.gene_score_for_rarity(rarity)
			)
			and is_equal_approx(
				float(item.get("growth_bonus_percent", 0.0)),
				generator.gene_growth_for_rarity(rarity)
			),
			"Gene rarity must map to score and Growth without creating another definition"
		)


func _test_inventory_stage_gate() -> void:
	var definitions := GeneCatalog.new().load_default()
	var tail := GeneCatalog.new().find_by_id(definitions, &"tail_long")
	_expect(tail != null, "inventory Gene fixture exists")
	if tail == null:
		return

	var item := ItemGenerator.new().generate_gene(tail, 91002)
	var policy := StageGenePolicy.load_default()
	var inventory := InventoryService.new()
	inventory.setup({"inventory": [item]})

	for stage_index in [1, 2, 3]:
		_expect(
			inventory.can_use_in_stage(item, stage_index, policy),
			"shared Gene must be usable in growth Stage %d" % stage_index
		)
	_expect(
		not inventory.can_use_in_stage(item, 4, policy),
		"Final Form must block new Gene use"
	)


func _test_unlimited_facade() -> void:
	SaveManager.delete_meta()
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var generator := ItemGenerator.new()
	var first := generator.generate_gene(
		catalog.find_by_id(definitions, &"whiskers_starlight"),
		92001
	)
	var second := generator.generate_gene(
		catalog.find_by_id(definitions, &"tail_long"),
		92002
	)
	var third := generator.generate_gene(
		catalog.find_by_id(definitions, &"eyes_luminous"),
		92003
	)

	_expect(
		SaveManager.save_meta({
			"schema": InfantGameFacade.META_SCHEMA,
			"inventory": [first, second, third],
			"chest_queue": []
		}),
		"save unlimited Gene fixture"
	)

	var game := InfantGameFacade.new()
	_expect(game.setup(920, 1, &"dark"), "Stage 1 facade setup")

	for item in [first, second, third]:
		_expect(game.can_use_item(item), "Gene remains usable without stage slot cap")
		_expect(
			bool(game.use_item(String(item.get("uid", ""))).get("ok", false)),
			"consume Gene without stage slot cap"
		)

	var state := game.snapshot()
	_expect(
		int(state.get("gene_items_used", -1)) == 3
		and bool(state.get("gene_unlimited", false))
		and int(state.get("gene_slots_remaining", 0)) == -1
		and int(state.get("gene_items_used_lifetime", -1)) == 3,
		"Stage snapshot exposes unlimited Gene use and lifetime count"
	)
	SaveManager.delete_meta()


func _test_element_effect_gate() -> void:
	SaveManager.delete_meta()
	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		&"aura_water"
	)
	_expect(definition != null, "element effect fixture exists")
	if definition == null:
		return

	var item := ItemGenerator.new().generate_gene(definition, 94001)
	_expect(
		SaveManager.save_meta({
			"schema": InfantGameFacade.META_SCHEMA,
			"inventory": [item],
			"chest_queue": []
		}),
		"save wrong-element Gene fixture"
	)

	var fire_game := InfantGameFacade.new()
	_expect(fire_game.setup(940, 1, &"fire"), "fire facade setup")
	_expect(
		not fire_game.can_use_item(item)
		and fire_game.inventory().size() >= 1,
		"wrong-element effect Gene stays in inventory instead of becoming junk"
	)
	var context := fire_game.gene_item_context(item)
	_expect(
		String(context.get("element_lock", "")) == "water"
		and not bool(context.get("element_compatible", true)),
		"item detail exposes future-use element requirement"
	)
	SaveManager.delete_meta()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
