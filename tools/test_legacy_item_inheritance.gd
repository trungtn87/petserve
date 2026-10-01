extends Node


var _failures: int = 0


func _ready() -> void:
	_cleanup()
	_test_service_idempotency()
	_cleanup()
	_test_generation_bootstrap_and_inventory_claim()
	_cleanup()

	if _failures == 0:
		print("Legacy Full Inventory Inheritance: PASS")
		get_tree().quit(0)
		return

	push_error(
		"Legacy Full Inventory Inheritance: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_service_idempotency() -> void:
	var source := PetIdentityFactory.new().create(
		7001,
		&"dark",
		&"cat",
		2
	)
	var generator := ItemGenerator.new()
	var food := generator.generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		7002,
		4
	)
	var growth := generator.generate_for_stage(
		ItemGenerator.TYPE_GROWTH,
		7003,
		4
	)
	var items: Array = [
		food,
		growth,
	]
	var legacy := LegacyInheritanceService.new()

	_expect(
		source != null,
		"source identity fixture must exist"
	)
	_expect(
		not food.is_empty()
		and not growth.is_empty(),
		"legacy inventory fixtures must exist"
	)

	if (
		source == null
		or food.is_empty()
		or growth.is_empty()
	):
		return

	var prepared := legacy.prepare(
		source,
		items
	)
	_expect(
		bool(
			prepared.get(
				"ok",
				false
			)
		)
		and int(
			prepared.get(
				"target_generation",
				0
			)
		) == 3
		and int(
			prepared.get(
				"item_count",
				0
			)
		) == 2,
		"prepare must carry the full inventory and advance generation by one"
	)

	var binding := legacy.bind_to_run(
		7100
	)
	_expect(
		bool(
			binding.get(
				"ok",
				false
			)
		)
		and bool(
			binding.get(
				"has_legacy",
				false
			)
		)
		and int(
			binding.get(
				"generation",
				0
			)
		) == 3
		and int(
			binding.get(
				"item_count",
				0
			)
		) == 2,
		"pending legacy must bind the complete inventory to exactly one next-life run"
	)

	var meta := {
		"inventory": [],
	}
	var first := legacy.apply_pending_to_meta(
		meta,
		7100
	)
	var second := legacy.apply_pending_to_meta(
		meta,
		7100
	)

	var stored := (
		meta.get(
			"inventory",
			[]
		) as Array
	)
	_expect(
		bool(
			first.get(
				"applied",
				false
			)
		)
		and stored.size() == 2,
		"first legacy claim must add every inherited item"
	)
	_expect(
		bool(
			second.get(
				"applied",
				false
			)
		)
		and bool(
			second.get(
				"already_present",
				false
			)
		)
		and stored.size() == 2,
		"reloading the same legacy claim must not duplicate inherited inventory"
	)

	var expected_uids := [
		String(
			food.get(
				"uid",
				""
			)
		),
		String(
			growth.get(
				"uid",
				""
			)
		),
	]
	var inherited_uids: Array[String] = []

	for raw in stored:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var inherited := raw as Dictionary
		_expect(
			bool(
				inherited.get(
					"legacy_inherited",
					false
				)
			),
			"every inherited item must carry legacy metadata"
		)
		inherited_uids.append(
			String(
				inherited.get(
					"uid",
					""
				)
			)
		)

	inherited_uids.sort()
	expected_uids.sort()
	_expect(
		inherited_uids == expected_uids,
		"full-inventory inheritance must preserve every item identity"
	)

	var inheritance_id := String(
		first.get(
			"inheritance_id",
			""
		)
	)
	_expect(
		legacy.mark_claimed(
			inheritance_id,
			7100
		),
		"saved legacy claim must finalize"
	)
	_expect(
		String(
			legacy.load_data().get(
				"status",
				""
			)
		) == LegacyInheritanceService.STATUS_CLAIMED,
		"finalized legacy record must be marked claimed"
	)


func _test_generation_bootstrap_and_inventory_claim() -> void:
	var source := PetIdentityFactory.new().create(
		7201,
		&"water",
		&"cat",
		0
	)
	var generator := ItemGenerator.new()
	var gene := generator.generate_gene(
		GeneCatalog.new().find_by_id(
			GeneCatalog.new().load_default(),
			&"tail_long"
		),
		7202
	)
	var food := generator.generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		7203,
		4
	)
	var items: Array = [
		gene,
		food,
	]
	var legacy := LegacyInheritanceService.new()

	_expect(
		source != null
		and not gene.is_empty()
		and not food.is_empty(),
		"bootstrap legacy fixtures must exist"
	)

	if (
		source == null
		or gene.is_empty()
		or food.is_empty()
	):
		return

	_expect(
		bool(
			legacy.prepare(
				source,
				items,
				&"slow_digestion"
			).get(
				"ok",
				false
			)
		),
		"legacy prepare for bootstrap must succeed"
	)

	var egg := EggState.new()
	egg.run_seed = 7300
	egg.egg_seed = 7301
	egg.egg_type = "fire"
	egg.stage = 1
	egg.status = "ready_to_hatch"

	var hatch := HatchState.new()
	hatch.run_seed = 7300
	hatch.status = HatchState.STATUS_NAME_CONFIRMED
	hatch.pet_name = "Legacy Test"
	hatch.name_confirmed = true

	_expect(
		SaveService.new().save_game(
			egg.to_save_dict()
		),
		"save next-life egg fixture"
	)
	_expect(
		HatchSaveService.new().save_data(
			hatch.to_save_dict()
		),
		"save next-life hatch fixture"
	)

	var bootstrap := EvolutionBootstrapService.new().build_from_hatch()
	var identity := bootstrap.get(
		"identity"
	) as PetIdentity

	_expect(
		bool(
			bootstrap.get(
				"ok",
				false
			)
		)
		and identity != null
		and identity.generation() == 1,
		"next-life bootstrap must increment pet generation"
	)

	var game := InfantGameFacade.new()
	_expect(
		game.setup(
			7300,
			1,
			&"fire"
		),
		"next PetHome must initialize"
	)

	var inherited_items: Array = []

	for stored in game.inventory():
		if bool(
			stored.get(
				"legacy_inherited",
				false
			)
		):
			inherited_items.append(
				stored
			)

	_expect(
		inherited_items.size() == 2,
		"next PetHome inventory must receive every inherited item"
	)

	var inherited_uids: Array[String] = []
	for inherited in inherited_items:
		inherited_uids.append(
			String(
				inherited.get(
					"uid",
					""
				)
			)
		)

	var expected_uids: Array[String] = [
		String(gene.get("uid", "")),
		String(food.get("uid", "")),
	]
	inherited_uids.sort()
	expected_uids.sort()

	_expect(
		inherited_uids == expected_uids,
		"next PetHome must receive the exact previous-life inventory"
	)

	var snapshot := game.snapshot()
	var snapshot_items: Variant = snapshot.get(
		"legacy_inherited_items",
		[]
	)
	var inherited_skills: Variant = snapshot.get(
		"skills",
		[]
	)
	_expect(
		typeof(snapshot_items) == TYPE_ARRAY
		and (
			snapshot_items as Array
		).size() == 2,
		"PetHome snapshot must expose the complete inherited inventory feedback"
	)
	_expect(
		typeof(inherited_skills) == TYPE_ARRAY
		and not (inherited_skills as Array).is_empty()
		and String(
			((inherited_skills as Array)[0] as Dictionary).get(
				"skill_id",
				""
			)
		) == "slow_digestion"
		and String(
			((inherited_skills as Array)[0] as Dictionary).get(
				"source",
				""
			)
		) == "legacy",
		"next PetHome must put the inherited skill in Slot 1"
	)
	_expect(
		String(
			legacy.load_data().get(
				"status",
				""
			)
		) == LegacyInheritanceService.STATUS_CLAIMED,
		"PetHome save must finalize the pending inheritance"
	)


func _cleanup() -> void:
	LegacyInheritanceService.new().clear()
	SaveService.new().delete_save()
	HatchSaveService.new().delete_save()
	EvolutionSaveService.new().delete_data()
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
