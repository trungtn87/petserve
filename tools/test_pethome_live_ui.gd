extends Node


var failures := 0


func check(
	ok: bool,
	message: String
) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	SaveManager.delete_meta()

	var identity := PetIdentityFactory.new().create_initial(
		778811,
		&"light"
	)
	var genome := PetGenomeFactory.new().create_initial()
	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()

	var fixture_texture := (
		load("res://assets/ui/menu_icons.png")
		as Texture2D
	)
	fixture_texture.get_image().save_png(
		"user://design_fixture.png"
	)
	visual.image_path = "user://design_fixture.png"
	visual.source_mode = (
		&"initial_pethome_v5_text_to_image"
	)
	visual.renderer_id = &"test"
	visual.model_id = &"test"

	check(
		EvolutionSaveService.new().save_initial(
			identity,
			genome,
			visual,
			"PetVerse"
		),
		"fixture saved"
	)

	var home := PetHomeScreen.new()
	get_tree().root.add_child(home)
	await get_tree().process_frame

	var game: InfantGameFacade = home._game

	home._on_drawer_action(
		&"pet_info"
	)
	check(
		not home._section_tabs.visible,
		"single-page pet info retained"
	)
	home._close_section()

	home._on_drawer_action(
		&"chest"
	)
	check(
		home._section_overlay.visible,
		"storage and crystallization open in one section"
	)
	check(
		home._active_section == &"storage",
		"combined section uses storage id"
	)
	check(
		home._crystal_slot_views.size() == 4,
		"combined section keeps all crystallization slots visible"
	)
	home._close_section()
	check(
		home._drawer.is_open(),
		"section X returns to menu"
	)

	home._on_drawer_action(
		&"inventory"
	)
	home._hud._close_overlay()
	check(
		home._drawer.is_open(),
		"inventory X returns to menu"
	)

	home._drawer.close_drawer()
	home._open_food_shortcut()
	check(
		home._hud._overlay.visible,
		"food opens inventory"
	)
	home._hud._close_overlay()
	check(
		not home._drawer.is_open(),
		"home shortcut returns home"
	)

	home._on_drawer_action(
		&"chest"
	)
	check(
		bool(
			game.start_crystallization(
				0
			).get(
				"ok",
				false
			)
		),
		"start existing slot"
	)
	game._crystallization.process(
		int(
			Time.get_unix_time_from_system()
		) + 43200
	)
	home._open_storage()

	check(
		home._crystal_slot_views.size() == 4,
		"ready product stays in its crystallization slot"
	)
	var ready_view: Dictionary = home._crystal_slot_views.get(
		0,
		{}
	)
	check(
		bool(
			ready_view.get(
				"ready_to_claim",
				false
			)
		),
		"finished slot exposes claim state in place"
	)
	home._claim_crystallization(
		0
	)
	check(
		is_instance_valid(
			home._claim_popup
		),
		"claim opens reward confirmation"
	)
	check(
		home._crystal_slot_views.size() == 4,
		"claimed slot remains visible in combined section"
	)

	home.queue_free()
	await get_tree().process_frame

	print(
		"LIVE PETHOME UI failures=",
		failures
	)
	get_tree().quit(
		1
		if failures
		else 0
	)
