extends Node

var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func run() -> void:
	# Run with a separate XDG_DATA_HOME; never touch a player's save.
	var meta := {}
	var lifecycle := InfantLifecycle.new()
	lifecycle.setup(meta, 123)
	lifecycle.tick(1200.0)
	var growth := int(meta.infant_state.growth_elapsed_seconds)
	check(growth > 0 and growth <= 1200, "hunger limits growth")
	lifecycle.tick(-10.0)
	check(int(meta.infant_state.growth_elapsed_seconds) == growth, "negative delta ignored")
	meta.infant_state.last_update_unix = int(Time.get_unix_time_from_system()) - 1200
	lifecycle.setup(meta, 123)
	check(int(meta.infant_state.growth_elapsed_seconds) >= growth, "offline growth never decreases progress")
	var game := InfantGameFacade.new()
	check(game.setup(456), "setup save")
	var items := game.open_next_chest()
	check(items.size() == 6, "hatch chest six slots")
	var hatch_has_gene := false
	for item in items:
		if StringName(
			item.get(
				"item_type",
				""
			)
		) == ItemGenerator.TYPE_GENE:
			hatch_has_gene = true
			break
	check(
		hatch_has_gene,
		"hatch chest provides a normal Stage 1 Gene source"
	)
	var daily_items := game.open_next_chest()
	check(daily_items.size() == 2, "daily chest two slots")
	check(game.open_next_chest().is_empty(), "opened chest queue is exhausted")
	var uid := str(items[0].uid)
	check(game.use_item(uid).ok, "use food")
	check(not game.use_item(uid).ok, "item cannot be consumed twice")
	check(game.claim_caro_win_reward("gomoku_first").get("chests", 0) == 1, "first daily Gomoku chest")
	for i in 10:
		check(game.claim_caro_win_reward("gomoku_extra_%d" % i).get("fragments", 0) == 1, "one fragment per additional match")
	check(not game.claim_caro_win_reward("gomoku_capped").get("rewarded", false), "ten fragment cap")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(456)
	check(int(reloaded.snapshot().caro_rewards_claimed) == 1, "daily chest quota persists")
	check(not reloaded.claim_caro_win_reward("gomoku_first").get("rewarded", false), "duplicate survives reload")
	check(reloaded.claim_obstacle_run_reward(900, "obstacle_stage1").get("chests", 0) == 1, "obstacle chest at stage one")
	check(reloaded.advance_to_stage(2), "advance to stage two")
	check(reloaded.claim_obstacle_run_reward(1200, "obstacle_stage2").get("fragments", 0) == 1, "stage change keeps daily quota")
	var identity := PetIdentityFactory.new().create_initial(456, &"dark")
	var genome := PetGenomeFactory.new().create_initial()
	var image := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color("252139"))
	image.save_png("user://test_pet.png")
	var visual := PetVisualRecord.new()
	visual.pet_id = identity.pet_id()
	visual.image_path = "user://test_pet.png"
	visual.source_mode = &"initial_pethome_v5_text_to_image"
	visual.renderer_id = &"test"
	visual.model_id = &"test"
	check(EvolutionSaveService.new().save_initial(identity, genome, visual, "Mèo"), "initial save")
	var service := InfantEvolutionService.new()
	check(not service.prepare({"ready_to_evolve": false}).ok, "premature evolution rejected")
	var first := service.prepare({"ready_to_evolve": true})
	check(first.ok, "prepare evolution")
	var again := service.prepare({"ready_to_evolve": true})
	check(JSON.parse_string(JSON.stringify(first.data.pending_evolution)) == again.data.pending_evolution, "retry stable result")
	var request := service.build_request(first.data)
	check(request != null and request.mode == PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE, "evolution image generation request")
	check(int(EvolutionSaveService.new().load_data().genome.stage) == 1, "stage unchanged before render")
	check(not service.commit(PetRenderResult.fail(&"test", "failure")), "render failure rejected")
	check(service.commit(PetRenderResult.ok("user://test_pet.png", &"test", &"test", {})), "commit evolution")
	var saved := EvolutionSaveService.new().load_data()
	check(int(saved.genome.stage) == 2, "stage two committed")
	check(PetIdentity.from_dict(saved.identity).same_identity(identity), "identity preserved")
	check(saved.evolution_history.size() == 1, "history exactly once")
	check(GameApp.new()._current_pet_visual_state() == &"current", "stage two resumes without infant rerender")
	check(not service.commit(PetRenderResult.ok("user://test_pet.png", &"test", &"test", {})), "duplicate commit rejected")
	var home = load("res://scenes/pet/pet_home.tscn").instantiate()
	get_tree().root.add_child(home)
	await get_tree().process_frame
	check(home._hud != null and home._hub != null, "home gameplay UI instanced")
	home._on_menu_pressed()
	await get_tree().create_timer(0.3).timeout
	check(home._drawer.is_open(), "hamburger opens drawer")
	home._on_menu_pressed()
	await get_tree().create_timer(0.3).timeout
	check(not home._drawer.is_open(), "hamburger closes drawer")
	home._on_drawer_action(&"pet_info")
	check(not home._section_tabs.visible, "single page hides tabs")
	var headings: Array[String] = []
	var meters := 0
	for child in home._section_body.get_children():
		if child is HBoxContainer:
			for label in child.get_children():
				if label is Label:
					headings.append(label.text)
		if child is VBoxContainer:
			for bar in child.get_children():
				if bar is ProgressBar:
					meters += 1
	check(meters == 2, "two status meters")
	for heading in ["Thông tin", "Trạng thái", "Kỹ năng", "Gene", "Tiến hóa"]:
		check(headings.has(heading), "single-page heading: " + heading)
	home._close_section()
	await get_tree().create_timer(0.3).timeout
	check(home._drawer.is_open(), "close info returns to menu")
	home._on_drawer_action(&"evolution")
	home._on_drawer_action(&"settings")
	home._on_drawer_action(&"chest")
	home._open_chest()
	home._hud.open_inventory()
	home._open_games()
	await get_tree().process_frame
	home._hub.open_hub(0, 4, true, 1, 0, 4, false)
	check(not home._hub._obstacle_card.disabled, "obstacle playable in stage one")
	home._hub._open_obstacle()
	await get_tree().process_frame
	check(home._hub._obstacle_activity.visible, "obstacle opens in stage one without reward")
	home._hub._show_hub_screen()
	home._hub._show_hub_screen()
	home._hub.open_hub(4, 4, false, 3, 4, 4, false)
	check(not home._hub._obstacle_card.disabled, "obstacle playable after stage two")
	home.queue_free()
	await get_tree().process_frame
	print("INFANT HOME failures=", failures)
	get_tree().quit(1 if failures else 0)
