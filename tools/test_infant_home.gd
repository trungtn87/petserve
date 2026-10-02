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
	check(int(meta.infant_state.growth_elapsed_seconds) == 1125, "fed/hungry boundary")
	lifecycle.tick(-10.0)
	check(int(meta.infant_state.growth_elapsed_seconds) == 1125, "negative delta ignored")
	meta.infant_state.last_update_unix = int(Time.get_unix_time_from_system()) - 1200
	lifecycle.setup(meta, 123)
	check(int(meta.infant_state.growth_elapsed_seconds) == 2025, "offline growth")
	lifecycle.tick(10000.0)
	check(lifecycle.snapshot().ready_to_evolve, "ready after growth")
	check(not lifecycle.apply_item({"item_type": "food", "main_value_seconds": 60}).ok, "ready pet cannot consume items")
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
	for i in range(4):
		check(game.claim_caro_win_reward().get("rewarded", false), "caro reward " + str(i))
	var caro_fallback := game.claim_caro_win_reward()
	check(
		caro_fallback.get("rewarded", false)
		and caro_fallback.get("reward_type", "") == "fragment"
		and int(game.snapshot().chest_fragments) == 1,
		"caro reward cap falls back to one fragment"
	)
	var reloaded := InfantGameFacade.new()
	reloaded.setup(456)
	check(int(reloaded.snapshot().caro_rewards_claimed) == 4, "reward cap persists")
	check(int(reloaded.snapshot().inventory_count) == 7, "inventory persists")
	var obstacle_stage1 := reloaded.claim_obstacle_run_reward(900, "obstacle_stage1_fragment")
	check(
		obstacle_stage1.get("rewarded", false)
		and obstacle_stage1.get("reward_type", "") == "fragment",
		"obstacle outside stage two falls back to fragment"
	)
	check(
		not reloaded.claim_obstacle_run_reward(900, "obstacle_stage1_fragment").get("rewarded", false),
		"same obstacle match cannot claim fallback twice"
	)
	var snake_stage1 := reloaded.claim_snake_hunt_reward(900, "snake_stage1_fragment")
	check(
		snake_stage1.get("rewarded", false)
		and snake_stage1.get("reward_type", "") == "fragment"
		and int(reloaded.snapshot().chest_fragments) == 3,
		"snake outside stage two falls back to fragment"
	)
	check(reloaded.advance_to_stage(2), "advance to stage two")
	check(reloaded.claim_obstacle_run_reward(1200, "obstacle_match_1").get("rewarded", false), "obstacle shared reward 1")
	check(not reloaded.claim_obstacle_run_reward(1200, "obstacle_match_1").get("rewarded", false), "same obstacle match cannot reward twice")
	check(reloaded.claim_snake_hunt_reward(1100, "snake_match_1").get("rewarded", false), "snake shared reward 2")
	check(reloaded.claim_obstacle_run_reward(2200, "obstacle_match_2").get("rewarded", false), "obstacle shared reward 3")
	check(reloaded.claim_snake_hunt_reward(1800, "snake_match_2").get("rewarded", false), "snake shared reward 4")
	var obstacle_cap := reloaded.claim_obstacle_run_reward(4000, "obstacle_match_cap")
	check(
		obstacle_cap.get("rewarded", false)
		and obstacle_cap.get("reward_type", "") == "fragment",
		"stage two shared reward cap obstacle falls back to fragment"
	)
	var snake_cap := reloaded.claim_snake_hunt_reward(4000, "snake_match_cap")
	check(
		snake_cap.get("rewarded", false)
		and snake_cap.get("reward_type", "") == "fragment"
		and int(reloaded.snapshot().chest_fragments) == 5,
		"stage two shared reward cap snake falls back to fragment"
	)
	check(int(reloaded.snapshot().stage2_activity_rewards_claimed) == 4, "stage two shared reward cap persists")
	check(int(reloaded.snapshot().obstacle_rewards_claimed) == 2, "obstacle contribution persists")
	check(int(reloaded.snapshot().snake_rewards_claimed) == 2, "snake contribution persists")
	var obstacle := ObstacleRunGame.new()
	check(obstacle.result() == ObstacleRunGame.RESULT_READY, "runner waits for tap")
	obstacle.request_jump()
	obstacle.tick(0.14)
	check(not obstacle.is_grounded(), "runner jumps")
	check(obstacle.result() == ObstacleRunGame.RESULT_PLAYING, "runner starts on tap")
	var snake := SnakeHuntGame.new()
	var snake_start := snake.head_position()
	snake.request_direction(Vector2i.LEFT)
	snake.tick(0.23)
	check(snake.head_position().x > snake_start.x, "snake rejects instant reverse")
	check(snake.result() == SnakeHuntGame.RESULT_PLAYING, "snake starts active")
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
	check(request != null and request.mode == PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT, "edit request")
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
	home._on_drawer_action(&"evolution")
	home._on_drawer_action(&"settings")
	home._on_drawer_action(&"chest")
	home._open_chest()
	home._hud.open_inventory()
	home._open_games()
	await get_tree().process_frame
	home._hub.open_hub(0, 4, true, 1, 0, 4, false)
	check(not home._hub._obstacle_card.disabled, "obstacle playable in stage one")
	check(not home._hub._snake_card.disabled, "snake playable in stage one")
	home._hub._open_obstacle()
	await get_tree().process_frame
	check(home._hub._obstacle_activity.visible, "obstacle opens in stage one without reward")
	home._hub._show_hub_screen()
	home._hub._open_snake()
	await get_tree().process_frame
	check(home._hub._snake_activity.visible, "snake opens in stage one without reward")
	home._hub._show_hub_screen()
	home._hub.open_hub(4, 4, false, 3, 4, 4, false)
	check(not home._hub._obstacle_card.disabled, "obstacle playable after stage two")
	check(not home._hub._snake_card.disabled, "snake playable after stage two")
	home.queue_free()
	await get_tree().process_frame
	print("INFANT HOME failures=", failures)
	get_tree().quit(1 if failures else 0)
