extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_test_catalog_and_item_contract()
	_test_stage_two_visual_contract()
	_test_gene_development_tags()
	_test_inventory_stage_gate()
	_test_stage_one_facade_consumption()

	if _failures == 0:
		print(
			"M9.3 Gene Items: PASS"
		)
		quit(0)
		return

	push_error(
		"M9.3 Gene Items: FAIL (%d)"
		% _failures
	)
	quit(1)


func _test_catalog_and_item_contract() -> void:
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()

	_expect(
		definitions.size() == 15,
		"Gene catalog must contain 15 definitions across the ten Stage 2 loci"
	)

	var stage_two_loci := StageGenePolicy.load_default().allowed_loci(
		2
	)
	_expect(
		stage_two_loci.size() == 10,
		"Stage 2 policy must expose exactly ten Gene loci"
	)

	for required_locus in [
		&"body",
		&"eyes",
		&"ears",
		&"whiskers",
		&"fur",
		&"coat",
		&"tail",
		&"paws",
		&"mane",
		&"mark",
	]:
		_expect(
			stage_two_loci.has(
				required_locus
			),
			"Stage 2 missing Gene locus: %s"
			% String(required_locus)
		)

	var seen: Dictionary = {}

	for definition in definitions:
		_expect(
			definition != null
			and definition.is_valid(),
			"every Gene definition must be valid"
		)

		if definition == null:
			continue

		_expect(
			not seen.has(
				definition.id()
			),
			"Gene definition ids must be unique"
		)
		seen[definition.id()] = true

	var tail := catalog.find_by_id(
		definitions,
		&"tail_long"
	)

	_expect(
		tail != null
		and tail.locus() == &"tail"
		and tail.direction() == &"long"
		and is_equal_approx(
			tail.primary_influence(),
			20.0
		)
		and tail.expression_chain() == [
			&"long",
			&"elongated",
			&"regal_long",
		],
		"tail_long definition and reinforcement chain contract"
	)

	if tail == null:
		return

	var item := ItemGenerator.new().generate_gene(
		tail,
		91001
	)

	_expect(
		StringName(
			item.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_GENE
		and StringName(
			item.get(
				"gene_locus",
				""
			)
		) == &"tail"
		and StringName(
			item.get(
				"gene_direction",
				""
			)
		) == &"long"
		and float(
			item.get(
				"gene_influence",
				0.0
			)
		) > 0.0,
		"generated Gene Item must carry canonical Gene fields"
	)


func _test_stage_two_visual_contract() -> void:
	var policy := StageGenePolicy.load_default()
	var gene_catalog := GeneCatalog.new()
	var definitions := gene_catalog.load_default()
	var visual_catalog := MutationVisualCatalog.new()
	var visuals := visual_catalog.load_default()

	for definition in definitions:
		if (
			definition == null
			or not policy.can_accept_gene(
				2,
				definition.locus()
			)
		):
			continue

		var stage_two_id := StringName(
			"gene_expr_%s_s2"
			% String(
				definition.id()
			)
		)
		var stage_two_visual := visual_catalog.find_by_id(
			visuals,
			stage_two_id
		)

		_expect(
			stage_two_visual != null
			and stage_two_visual.target_region()
				== definition.locus(),
			"Stage 2 Gene visual missing or wrong locus: %s"
			% String(stage_two_id)
		)

		var stage_three_id := StringName(
			"gene_expr_%s_s3"
			% String(
				definition.id()
			)
		)
		var stage_three_visual := visual_catalog.find_by_id(
			visuals,
			stage_three_id
		)

		_expect(
			stage_three_visual != null
			and stage_three_visual.target_region()
				== definition.locus(),
			"Stage 3 Gene visual missing or wrong locus: %s"
			% String(stage_three_id)
		)


func _test_gene_development_tags() -> void:
	var policy := StageGenePolicy.load_default()
	var state := GeneDevelopmentState.new(
		1
	)

	var result := state.record_gene_item(
		policy,
		"gene_test_tag",
		&"tail_long",
		&"tail",
		&"long",
		20.0,
		{
			"agile": 6.0,
			"lunar": 2.0,
		}
	)

	_expect(
		bool(
			result.get(
				"ok",
				false
			)
		)
		and is_equal_approx(
			float(
				state.tag_influences_snapshot().get(
					"agile",
					0.0
				)
			),
			6.0
		),
		"GeneDevelopmentState must retain hidden influence tags"
	)

	var restored := GeneDevelopmentState.from_dict(
		state.to_dict(),
		policy
	)

	_expect(
		restored != null
		and is_equal_approx(
			float(
				restored.tag_influences_snapshot().get(
					"lunar",
					0.0
				)
			),
			2.0
		),
		"Gene influence tags must survive serialization"
	)


func _test_inventory_stage_gate() -> void:
	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var tail := catalog.find_by_id(
		definitions,
		&"tail_long"
	)

	if tail == null:
		_expect(
			false,
			"tail fixture must exist"
		)
		return

	var item := ItemGenerator.new().generate_gene(
		tail,
		91002
	)
	var policy := StageGenePolicy.load_default()
	var meta := {
		"inventory": [
			item,
		],
	}
	var inventory := InventoryService.new()
	inventory.setup(
		meta
	)

	_expect(
		inventory.can_use_in_stage(
			item,
			1,
			policy
		),
		"Stage 1 inventory must expose an allowed Gene Item"
	)

	_expect(
		not inventory.can_use_in_stage(
			item,
			4,
			policy
		),
		"Stage 4 inventory must reject visual Gene Items"
	)


func _test_stage_one_facade_consumption() -> void:
	SaveManager.delete_meta()

	var catalog := GeneCatalog.new()
	var definitions := catalog.load_default()
	var tail := catalog.find_by_id(
		definitions,
		&"tail_long"
	)
	var eyes := catalog.find_by_id(
		definitions,
		&"eyes_luminous"
	)

	if tail == null or eyes == null:
		_expect(
			false,
			"facade Gene fixtures must exist"
		)
		return

	var generator := ItemGenerator.new()
	var first := generator.generate_gene(
		tail,
		92001
	)
	var second := generator.generate_gene(
		eyes,
		92002
	)

	_expect(
		SaveManager.save_meta({
			"schema": 3,
			"inventory": [
				first,
				second,
			],
			"chest_queue": [],
		}),
		"save M9.3 inventory fixture"
	)

	var game := InfantGameFacade.new()

	_expect(
		game.setup(
			920,
			1
		),
		"Stage 1 facade setup with Gene Items"
	)

	var before := game.snapshot()
	var before_growth := int(
		before.get(
			"growth_percent",
			-1
		)
	)

	_expect(
		game.can_use_item(
			first
		),
		"first Stage 1 Gene Item must be usable"
	)

	var used := game.use_item(
		String(
			first.get(
				"uid",
				""
			)
		)
	)

	var after := game.snapshot()

	_expect(
		bool(
			used.get(
				"ok",
				false
			)
		)
		and int(
			after.get(
				"gene_items_used",
				0
			)
		) == 1
		and int(
			after.get(
				"gene_slots_remaining",
				-1
			)
		) == 0,
		"using Gene Item must consume the Stage 1 Gene slot"
	)

	_expect(
		int(
			after.get(
				"growth_percent",
				-2
			)
		) == before_growth,
		"using Gene Item must not change Maturity"
	)

	_expect(
		is_equal_approx(
			float(
				after.get(
					"gene_influences",
					{}
				).get(
					"tail.long",
					0.0
				)
			),
			20.0
		)
		and is_equal_approx(
			float(
				after.get(
					"gene_tag_influences",
					{}
				).get(
					"agile",
					0.0
				)
			),
			6.0
		),
		"facade must expose primary and tag Gene influence"
	)

	_expect(
		not game.can_use_item(
			second
		),
		"Stage 1 second Gene Item must be blocked by cap"
	)

	_expect(
		game.advance_to_stage(
			2
		),
		"advance to Stage 2"
	)

	var stage_two := game.snapshot()

	_expect(
		int(
			stage_two.get(
				"gene_items_used",
				-1
			)
		) == 0
		and int(
			stage_two.get(
				"gene_item_limit",
				-1
			)
		) == 2,
		"new Stage must reset GeneDevelopmentState and use Stage 2 cap"
	)

	_expect(
		game.can_use_item(
			second
		),
		"unused Gene Item may be used again when Stage 2 policy allows it"
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
