extends Node


var _failures: int = 0


func _ready() -> void:
	_test_stage4_growth_lifecycle()
	_test_stage4_gene_gate()
	_test_stage4_resource_scaling()
	_test_stage4_entry_gene_reward()
	_test_mythic_reaches_final_form()

	if _failures == 0:
		print("Stage 4 Growth + Final Evolution Foundation: PASS")
		get_tree().quit(0)
		return

	push_error(
		"Stage 4 Growth + Final Evolution Foundation: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_stage4_growth_lifecycle() -> void:
	var meta: Dictionary = {}
	var lifecycle := StageLifecycle.new()
	lifecycle.setup(
		meta,
		4040,
		4
	)

	var start := lifecycle.snapshot()
	var duration := int(
		start.get(
			"duration_seconds",
			0
		)
	)

	_expect(
		int(
			start.get(
				"stage_index",
				0
			)
		) == 4,
		"Stage 4 lifecycle must start at stage 4"
	)
	_expect(
		duration == 172800,
		"Stage 4 must use the 48 hour Growth baseline"
	)
	_expect(
		not bool(
			start.get(
				"final_form",
				true
			)
		),
		"Stage 4 must not be Final Form"
	)
	_expect(
		int(
			start.get(
				"growth_percent",
				-1
			)
		) == 0,
		"Stage 4 Growth must start at 0 percent"
	)

	var food_result := lifecycle.apply_item({
		"item_type": String(ItemGenerator.TYPE_FOOD),
		"display_name": "Stage 4 test food",
		"main_value_seconds": duration,
		"growth_delta_seconds": 0,
	})
	_expect(
		bool(
			food_result.get(
				"ok",
				false
			)
		),
		"Stage 4 must accept Food"
	)

	var growth_result := lifecycle.apply_item({
		"item_type": String(ItemGenerator.TYPE_GROWTH),
		"display_name": "Stage 4 test Growth",
		"main_value_seconds": duration,
		"food_delta_seconds": 0,
	})
	_expect(
		bool(
			growth_result.get(
				"ok",
				false
			)
		),
		"Stage 4 must accept Growth items"
	)
	_expect(
		bool(
			lifecycle.snapshot().get(
				"ready_to_evolve",
				false
			)
		),
		"Stage 4 must become ready for Final Evolution at 100 percent Growth"
	)

	lifecycle.advance_to_stage(
		StageLifecycle.FINAL_STAGE
	)
	var final_state := lifecycle.snapshot()

	_expect(
		int(
			final_state.get(
				"stage_index",
				0
			)
		) == 5
		and bool(
			final_state.get(
				"final_form",
				false
			)
		),
		"Final Form must be the post-Stage-4 state"
	)
	_expect(
		not bool(
			final_state.get(
				"ready_to_evolve",
				true
			)
		)
		and not lifecycle.tick(
			3600.0
		),
		"Final Form must have no Growth or further evolution"
	)


func _test_stage4_gene_gate() -> void:
	var policy := StageGenePolicy.load_default()
	_expect(
		policy != null,
		"Stage Gene policy must load"
	)

	if policy == null:
		return

	_expect(
		policy.is_unlimited(
			4
		),
		"Stage 4 must keep unlimited Gene item use"
	)

	for locus in PetGenomeSchema.GENE_LOCI:
		_expect(
			policy.can_accept_gene(
				4,
				locus
			),
			"Stage 4 must accept Gene locus %s"
			% String(locus)
		)

	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		&"tail_long"
	)
	_expect(
		definition != null,
		"Stage 4 Gene fixture must exist"
	)

	if definition == null:
		return

	var item := ItemGenerator.new().generate_gene(
		definition,
		4041
	)
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
			4,
			policy
		),
		"Stage 4 must accept supplemental Gene items"
	)
	_expect(
		not inventory.can_use_in_stage(
			item,
			StageLifecycle.FINAL_STAGE,
			policy
		),
		"Final Form must lock Gene item use"
	)


func _test_stage4_resource_scaling() -> void:
	var generator := ItemGenerator.new()
	var food := generator.generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		4042,
		4
	)
	var growth := generator.generate_for_stage(
		ItemGenerator.TYPE_GROWTH,
		4043,
		4
	)

	for item in [
		food,
		growth,
	]:
		_expect(
			not item.is_empty(),
			"Stage 4 resource item must generate"
		)
		_expect(
			int(
				item.get(
					"generated_for_stage",
					0
				)
			) == 4,
			"Stage 4 resource must preserve stage identity"
		)
		_expect(
			is_equal_approx(
				float(
					item.get(
						"stage_value_multiplier",
						0.0
					)
				),
				12.0
			),
			"Stage 4 resource must use the 48 hour x12 value scale"
		)


func _test_stage4_entry_gene_reward() -> void:
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
			4044,
			3,
			4
		),
		"Evolution III must create the Stage 4 entry chest"
	)

	var rewards := chests.open_next()
	var has_gene := false

	for item in rewards:
		if StringName(
			item.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_GENE:
			has_gene = true
			break

	_expect(
		has_gene,
		"Stage 4 entry chest must provide a supplemental Gene item"
	)
	_expect(
		chests.ensure_evolution_chest(
			4044,
			4,
			StageLifecycle.FINAL_STAGE
		),
		"Final Evolution grants one chest"
	)


func _test_mythic_reaches_final_form() -> void:
	var catalog := SpeciesMythicMutationCatalog.new()
	var definitions := catalog.load_default()

	_expect(
		not definitions.is_empty(),
		"Mythic catalog must load"
	)

	for definition in definitions:
		_expect(
			definition.supports_stage(
				StageLifecycle.FINAL_STAGE
			),
			"Mythic branch %s must support Final Evolution"
			% String(
				definition.id()
			)
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
