extends Node

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var game := ObstacleRunGame.new()
	game.request_move(160.0)
	game._spawn_left = 999.0
	for frame in range(3000):
		game.tick(1.0 / 60.0)
	check(
		game.result() == ObstacleRunGame.RESULT_PLAYING,
		"food catch is endless"
	)

	var player := game.player_rect()
	game._obstacles.append({
		"x": player.position.x,
		"y": player.position.y,
		"width": player.size.x,
		"height": player.size.y,
		"speed_mult": 0.0,
		"kind": ObstacleRunGame.KIND_FISH,
		"edible": true,
		"points": 120,
		"resolved": false,
	})
	game.tick(1.0 / 30.0)
	check(
		game.score() >= 120 and game.eaten() >= 1,
		"edible item scores"
	)

	check(
		MiniGameRewardService.new().obstacle_reward_tier(1000) == 2,
		"score reward uses 500 point steps"
	)

	print("FOOD CATCH failures=", failures)
	get_tree().quit(1 if failures else 0)
