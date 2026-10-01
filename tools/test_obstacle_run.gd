extends Node

var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func _force_hit(game: ObstacleRunGame) -> void:
	var player := game.player_rect()
	game._invulnerable = 0.0
	game._obstacles.append({
		"x": player.position.x,
		"y": player.position.y,
		"width": player.size.x,
		"height": player.size.y,
		"speed_mult": 0.0,
		"kind": &"crate",
		"resolved": false,
	})
	game.tick(1.0 / 30.0)

func _safe_target(game: ObstacleRunGame) -> float:
	var candidates := ObstacleRunGame.LANE_CENTERS
	var best_x := float(candidates[0])
	var best_clearance := -1.0
	for candidate_value in candidates:
		var candidate := float(candidate_value)
		var clearance := 999.0
		for obstacle in game.obstacles():
			var rect := game.obstacle_rect(obstacle)
			if rect.position.y < 190.0:
				continue
			clearance = minf(
				clearance,
				absf(rect.get_center().x - candidate)
			)
		if clearance > best_clearance:
			best_clearance = clearance
			best_x = candidate
	return best_x

func run() -> void:
	var game := ObstacleRunGame.new()
	var first_id := game.match_id()
	game.tick(20.0)
	check(
		game.elapsed() == 0.0 and game.lives() == 3,
		"ready screen does not advance"
	)

	var start_x := game.player_rect().position.x
	game.request_move(260.0)
	game.tick(-1.0)
	check(game.elapsed() == 0.0, "negative delta ignored")
	game.tick(0.2)
	check(
		game.result() == ObstacleRunGame.RESULT_PLAYING,
		"first move starts match"
	)
	check(
		game.player_rect().position.x > start_x,
		"touch target moves pet horizontally"
	)

	game.set_move_axis(-1.0)
	game.tick(0.2)
	check(
		game.player_rect().position.x < 230.0,
		"keyboard axis moves pet"
	)
	game.set_move_axis(0.0)

	game.reset()
	check(
		game.match_id() != first_id
		and game.result() == ObstacleRunGame.RESULT_READY,
		"restart creates a fresh match"
	)

	game.request_move(160.0)
	_force_hit(game)
	check(game.lives() == 2, "collision costs exactly one life")
	var after_hit := game.lives()
	for frame in range(30):
		game.tick(1.0 / 60.0)
	check(
		game.lives() == after_hit,
		"resolved object cannot damage repeatedly"
	)

	game.reset()
	game.request_move(160.0)
	_force_hit(game)
	_force_hit(game)
	_force_hit(game)
	check(
		game.result() == ObstacleRunGame.RESULT_LOSE,
		"three hits lose"
	)
	var final_score := game.score()
	game.request_move(50.0)
	game.tick(0.25)
	check(
		game.score() == final_score,
		"finished match is frozen"
	)

	for seed_value in range(10):
		game.reset()
		game._rng.seed = seed_value
		game.request_move(160.0)
		var dt: float = (
			1.0 / 30.0
			if seed_value % 2 == 0
			else 1.0 / 60.0
		)
		for frame in range(3000):
			game.request_move(_safe_target(game))
			game.tick(dt)
			if game.result() != ObstacleRunGame.RESULT_PLAYING:
				break
		check(
			game.result() == ObstacleRunGame.RESULT_WIN,
			"reachable clean win seed " + str(seed_value)
		)
		check(
			game.lives() == 3,
			"autopilot keeps all lives seed " + str(seed_value)
		)
		check(
			game.reward_tier() == 4,
			"clean win earns tier four"
		)

	var old_meta := {
		"mini_game_rewards": {
			"run_id": 99,
			"maze_hunt": {"claimed": 3},
			"snake_hunt": {"claimed": 1},
		},
	}
	var rewards := MiniGameRewardService.new()
	rewards.setup(old_meta, null, 99)
	check(
		int(rewards.snapshot(99).stage2_activity_rewards_claimed) == 4,
		"old save retains shared reward cap"
	)
	check(
		not rewards.claim_obstacle_run(
			99,
			3200,
			"new_match"
		).get("rewarded", false),
		"old cap blocks a new dodge reward"
	)

	var facade := InfantGameFacade.new()
	check(facade.setup(99123), "facade setup")
	check(
		not facade.claim_obstacle_run_reward(
			3200,
			"locked"
		).get("rewarded", false),
		"stage one has no reward"
	)
	check(
		facade.advance_to_stage(2),
		"stage two setup"
	)
	check(
		facade.claim_obstacle_run_reward(
			3200,
			"dodge_1"
		).get("rewarded", false),
		"dodge reward through facade"
	)
	check(
		not facade.claim_obstacle_run_reward(
			3200,
			"dodge_1"
		).get("rewarded", false),
		"same match cannot reward twice"
	)

	var reloaded := InfantGameFacade.new()
	check(
		reloaded.setup(99123, 2),
		"reload reward save"
	)
	check(
		int(reloaded.snapshot().obstacle_rewards_claimed) == 1,
		"dodge reward persists"
	)
	check(
		not reloaded.claim_obstacle_run_reward(
			3200,
			"dodge_1"
		).get("rewarded", false),
		"match dedup persists"
	)
	check(
		reloaded.claim_snake_hunt_reward(
			1200,
			"snake_1"
		).get("rewarded", false),
		"snake shares pool"
	)
	check(
		reloaded.claim_obstacle_run_reward(
			3200,
			"dodge_2"
		).get("rewarded", false),
		"dodge third reward"
	)
	check(
		reloaded.claim_snake_hunt_reward(
			1200,
			"snake_2"
		).get("rewarded", false),
		"snake fourth reward"
	)
	check(
		not reloaded.claim_obstacle_run_reward(
			3200,
			"dodge_3"
		).get("rewarded", false),
		"shared pool capped at four"
	)

	get_tree().root.size = Vector2i(360, 640)
	var hub := EntertainmentHubUI.new()
	get_tree().root.add_child(hub)
	hub.open_hub(
		0,
		4,
		true,
		1,
		0,
		4,
		false
	)
	hub._open_obstacle()
	await get_tree().process_frame
	await get_tree().process_frame

	var activity: ObstacleRunActivityUI = hub._obstacle_activity
	check(
		activity.visible
		and activity._game.result() == ObstacleRunGame.RESULT_READY,
		"hub opens dodge ready"
	)
	check(
		activity._board.size.x >= 280.0,
		"board uses phone width"
	)
	check(
		activity._board.size.y >= 300.0,
		"portrait board has useful height"
	)
	check(
		activity._control_label.get_global_rect().end.y < 640,
		"drag hint fits phone height"
	)
	check(
		activity._message_label.get_global_rect().end.y < 640,
		"instructions fit phone height"
	)

	activity._move_to(260.0)
	check(
		activity._game.result() == ObstacleRunGame.RESULT_PLAYING,
		"touch move starts activity"
	)
	activity.close_activity()
	var paused_time := activity._game.elapsed()
	await get_tree().process_frame
	check(
		activity._game.elapsed() == paused_time,
		"hidden activity stops processing"
	)

	activity.open_activity()
	activity._game._result = ObstacleRunGame.RESULT_WIN
	activity.set_reward_status(0, 4, true)
	var claims: Array[String] = []
	activity.reward_requested.connect(
		func(_score: int, id: String) -> void:
			claims.append(id)
			activity.show_reward_message("Đã nhận rương")
			activity.set_reward_status(1, 4, true)
	)
	activity._on_reward_pressed()
	activity._on_reward_pressed()
	check(
		claims.size() == 1
		and not activity._reward_button.visible,
		"successful claim is disabled for this match"
	)
	activity.open_activity()
	check(
		not activity._reward_button.disabled
		and not activity._match_rewarded,
		"restart clears button lock"
	)

	hub.queue_free()
	await get_tree().process_frame
	print("FALLING DODGE failures=", failures)
	get_tree().quit(1 if failures else 0)
