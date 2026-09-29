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
	check(game.open_next_chest().is_empty(), "chest cannot open twice")
	var uid := str(items[0].uid)
	check(game.use_item(uid).ok, "use food")
	check(not game.use_item(uid).ok, "item cannot be consumed twice")
	for i in range(4):
		check(game.claim_caro_win_reward().get("rewarded", false), "caro reward " + str(i))
	check(not game.claim_caro_win_reward().get("rewarded", false), "reward cap")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(456)
	check(int(reloaded.snapshot().caro_rewards_claimed) == 4, "reward cap persists")
	check(int(reloaded.snapshot().inventory_count) == 5, "inventory persists")
	check(not reloaded.claim_maze_hunt_reward(900).get("rewarded", false), "maze reward locked in stage one")
	check(not reloaded.claim_snake_hunt_reward(900).get("rewarded", false), "snake reward locked in stage one")
	check(reloaded.advance_to_stage(2), "advance to stage two")
	check(reloaded.claim_maze_hunt_reward(1200).get("rewarded", false), "maze shared reward 1")
	check(reloaded.claim_snake_hunt_reward(1100).get("rewarded", false), "snake shared reward 2")
	check(reloaded.claim_maze_hunt_reward(2200).get("rewarded", false), "maze shared reward 3")
	check(reloaded.claim_snake_hunt_reward(1800).get("rewarded", false), "snake shared reward 4")
	check(not reloaded.claim_maze_hunt_reward(4000).get("rewarded", false), "stage two shared reward cap maze")
	check(not reloaded.claim_snake_hunt_reward(4000).get("rewarded", false), "stage two shared reward cap snake")
	check(int(reloaded.snapshot().stage2_activity_rewards_claimed) == 4, "stage two shared reward cap persists")
	check(int(reloaded.snapshot().maze_rewards_claimed) == 2, "maze contribution persists")
	check(int(reloaded.snapshot().snake_rewards_claimed) == 2, "snake contribution persists")
	var maze := MazeHuntGame.new()
	var maze_start := maze.player_position()
	maze.request_direction(Vector2i.RIGHT)
	maze.tick(0.14)
	check(maze.player_position() != maze_start, "maze player auto moves")
	check(maze.result() == MazeHuntGame.RESULT_PLAYING, "maze starts active")
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
	home.queue_free()
	await get_tree().process_frame
	print("INFANT HOME failures=", failures)
	get_tree().quit(1 if failures else 0)
