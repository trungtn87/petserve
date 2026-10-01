extends Node

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var game := ObstacleRunGame.new()
	var first_id := game.match_id()
	game.tick(20.0)
	check(game.elapsed() == 0.0 and game.lives() == 3, "ready screen does not advance")
	game.request_jump()
	game.tick(-1.0)
	check(game.elapsed() == 0.0, "negative delta ignored")
	game.tick(0.2)
	check(not game.is_grounded(), "tap starts and jumps")
	var velocity := game._velocity
	game.request_jump()
	game.tick(0.02)
	check(game._velocity < velocity, "midair tap cannot reset velocity")
	game.reset()
	check(game.match_id() != first_id and game.result() == ObstacleRunGame.RESULT_READY, "restart creates a fresh match")

	# Idle play must lose, and the same collision must not drain multiple lives.
	game.request_jump()
	for frame in range(1800):
		game.tick(1.0 / 60.0)
		if game.lives() < 3:
			break
	check(game.lives() == 2, "collision costs exactly one life")
	for frame in range(30):
		game.tick(1.0 / 60.0)
	check(game.lives() == 2, "hit obstacle cannot damage again")
	for frame in range(2400):
		game.tick(1.0 / 60.0)
	check(game.result() == ObstacleRunGame.RESULT_LOSE, "no-input run loses")
	var final_score := game.score()
	game.request_jump()
	game.tick(0.25)
	check(game.score() == final_score, "finished match is frozen")

	# Different seeds/frame rates, with a generous ~0.30 s reaction distance.
	for seed_value in range(20):
		game.reset()
		game._rng.seed = seed_value
		game.request_jump()
		var dt: float = 1.0 / (30.0 if seed_value % 2 == 0 else 60.0)
		for frame in range(2600):
			for obstacle in game.obstacles():
				var gap := float(obstacle.x) - game.player_rect().end.x
				if not bool(obstacle.resolved) and gap > 0.0 and gap < game.speed() * 0.30 and game.is_grounded():
					game.request_jump()
			game.tick(dt)
			if game.result() != ObstacleRunGame.RESULT_PLAYING:
				break
		check(game.result() == ObstacleRunGame.RESULT_WIN and game.lives() == 3, "reachable clean win seed " + str(seed_value))
		check(game.reward_tier() == 4, "clean win earns tier four")

	# Old Maze claims still count toward the four-reward shared Stage 2 limit.
	var old_meta := {"mini_game_rewards": {"run_id": 99, "maze_hunt": {"claimed": 3}, "snake_hunt": {"claimed": 1}}}
	var rewards := MiniGameRewardService.new()
	rewards.setup(old_meta, null, 99)
	check(int(rewards.snapshot(99).stage2_activity_rewards_claimed) == 4, "old save retains shared reward cap")
	check(not rewards.claim_obstacle_run(99, 3200, "new_match").get("rewarded", false), "old cap blocks a new runner reward")

	var facade := InfantGameFacade.new()
	check(facade.setup(99123), "facade setup")
	check(not facade.claim_obstacle_run_reward(3200, "locked").get("rewarded", false), "stage one has no reward")
	check(facade.advance_to_stage(2), "stage two setup")
	check(facade.claim_obstacle_run_reward(3200, "runner_1").get("rewarded", false), "runner reward through facade")
	check(not facade.claim_obstacle_run_reward(3200, "runner_1").get("rewarded", false), "same match cannot reward twice")
	var reloaded := InfantGameFacade.new()
	check(reloaded.setup(99123, 2), "reload reward save")
	check(int(reloaded.snapshot().obstacle_rewards_claimed) == 1, "runner reward persists")
	check(not reloaded.claim_obstacle_run_reward(3200, "runner_1").get("rewarded", false), "match dedup persists")
	check(reloaded.claim_snake_hunt_reward(1200, "snake_1").get("rewarded", false), "snake shares pool")
	check(reloaded.claim_obstacle_run_reward(3200, "runner_2").get("rewarded", false), "runner third reward")
	check(reloaded.claim_snake_hunt_reward(1200, "snake_2").get("rewarded", false), "snake fourth reward")
	check(not reloaded.claim_obstacle_run_reward(3200, "runner_3").get("rewarded", false), "shared pool capped at four")

	# UI lives inside the actual hub bounds at the project's 360x640 viewport.
	get_tree().root.size = Vector2i(360, 640)
	var hub := EntertainmentHubUI.new()
	get_tree().root.add_child(hub)
	hub.open_hub(0, 4, true, 1, 0, 4, false)
	hub._open_obstacle()
	await get_tree().process_frame
	await get_tree().process_frame
	var activity: ObstacleRunActivityUI = hub._obstacle_activity
	check(activity.visible and activity._game.result() == ObstacleRunGame.RESULT_READY, "hub opens runner ready")
	check(activity._board.size.x >= 280.0, "board uses phone width")
	check(activity._jump_button.size.y >= 60.0, "large touch button")
	check(activity._message_label.get_global_rect().end.y < 640, "instructions fit phone height")
	check(activity._jump_button.get_global_rect().end.y < 640, "jump button fits phone height")
	activity._jump()
	activity.close_activity()
	var paused_time := activity._game.elapsed()
	await get_tree().process_frame
	check(activity._game.elapsed() == paused_time, "hidden activity stops processing")
	activity.open_activity()
	activity._game._result = ObstacleRunGame.RESULT_WIN
	activity.set_reward_status(0, 4, true)
	var claims: Array[String] = []
	activity.reward_requested.connect(func(_score: int, id: String) -> void:
		claims.append(id)
		activity.show_reward_message("Đã nhận rương")
		activity.set_reward_status(1, 4, true)
	)
	activity._on_reward_pressed()
	activity._on_reward_pressed()
	check(claims.size() == 1 and not activity._reward_button.visible, "successful claim is disabled for this match")
	activity.open_activity()
	check(not activity._reward_button.disabled and not activity._match_rewarded, "restart clears button lock")
	hub.queue_free()
	await get_tree().process_frame
	print("OBSTACLE RUN failures=", failures)
	get_tree().quit(1 if failures else 0)
