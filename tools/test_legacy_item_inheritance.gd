extends Node


var _failures: int = 0


func _ready() -> void:
	_cleanup()
	_test_service_idempotency()
	_cleanup()
	_test_generation_bootstrap_and_inventory_claim()
	_cleanup()

	if _failures == 0:
		print("Legacy Item Inheritance: PASS")
		get_tree().quit(0)
		return

	push_error(
		"Legacy Item Inheritance: FAIL (%d)"
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
	var item := ItemGenerator.new().generate_for_stage(
		ItemGenerator.TYPE_FOOD,
		7002,
		4
	)
	var legacy := LegacyInheritanceService.new()

	_expect(
		source != null,
		"source identity fixture must exist"
	)
	_expect(
		not item.is_empty(),
		"legacy item fixture must exist"
	)

	if source == null or item.is_empty():
		return

	var prepared := legacy.prepare(
		source,
		item
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
		) == 3,
		"prepare must advance generation by one"
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
		) == 3,
		"pending legacy must bind to exactly one next-life run"
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

	_expect(
		bool(
			first.get(
				"applied",
				false
			)
		)
		and (
			meta.get(
				"inventory",
				[]
			) as Array
		).size() == 1,
		"first legacy claim must add exactly one inherited item"
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
		and (
			meta.get(
				"inventory",
				[]
			) as Array
		).size() == 1,
		"reloading the same legacy claim must not duplicate the item"
	)

	var inherited := (
		meta.get(
			"inventory",
			[]
		) as Array
	)[0] as Dictionary

	_expect(
		bool(
			inherited.get(
				"legacy_inherited",
				false
			)
		)
		and String(
			inherited.get(
				"uid",
				""
			)
		) == String(
			item.get(
				"uid",
				""
			)
		),
		"inherited item must preserve item identity and carry legacy metadata"
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
	var item := ItemGenerator.new().generate_gene(
		GeneCatalog.new().find_by_id(
			GeneCatalog.new().load_default(),
			&"tail_long"
		),
		7202
	)
	var legacy := LegacyInheritanceService.new()

	_expect(
		source != null
		and not item.is_empty(),
		"bootstrap legacy fixtures must exist"
	)

	if source == null or item.is_empty():
		return

	_expect(
		bool(
			legacy.prepare(
				source,
				item
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

	var inherited_item: Dictionary = {}
	for stored in game.inventory():
		if bool(
			stored.get(
				"legacy_inherited",
				false
			)
		):
			inherited_item = stored
			break

	_expect(
		not inherited_item.is_empty(),
		"next PetHome inventory must receive the inherited item"
	)
	_expect(
		String(
			inherited_item.get(
				"uid",
				""
			)
		) == String(
			item.get(
				"uid",
				""
			)
		),
		"next PetHome must receive the exact selected item"
	)

	var snapshot := game.snapshot()
	var snapshot_item: Variant = snapshot.get(
		"legacy_inherited_item",
		{}
	)
	_expect(
		typeof(snapshot_item) == TYPE_DICTIONARY
		and not (
			snapshot_item as Dictionary
		).is_empty(),
		"PetHome snapshot must expose inherited item feedback"
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
