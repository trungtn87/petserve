extends Node
class ClockRewards extends MiniGameRewardService:
	var today := "2026-10-03"
	func _day() -> String:
		return today
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var meta: Dictionary = {}
	var chests := ChestService.new()
	chests.setup(meta, ItemGenerator.new())
	var rewards := ClockRewards.new()
	rewards.setup(meta, chests, 1)
	for game in ["caro_3x3", "maze_hunt", "2048", "tetris", "tank", "sudoku", "breakout", "jigsaw"]:
		var initial := chests.pending_count()
		var result := rewards.claim_game(1, 1, game, "first")
		check(result.chests == 1 and result.fragments == 0 and chests.pending_count() == initial + 1, game + " first chest")
		check(not rewards.claim_game(1, 4, game, "first").ok, game + " duplicate")
		for i in 10:
			result = rewards.claim_game(2, 5, game, "extra_%d" % i)
			check(result.fragments == 1 and result.chests == 0, game + " one fragment across stages/lives")
		check(not rewards.claim_game(2, 2, game, "cap").rewarded, game + " daily cap")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(meta))
	chests.setup(restored, ItemGenerator.new())
	rewards.setup(restored, chests, 3)
	check(not rewards.claim_game(3, 3, "tank", "solo_next").rewarded, "reload and mode share quota")
	rewards.today = "2026-10-02"
	check(not rewards.claim_game(3, 3, "tank", "clock_back").rewarded, "clock rollback")
	rewards.today = "2026-10-04"
	check(rewards.claim_game(3, 2, "tank", "next_day").chests == 1, "new day grants chest")
	check(rewards.claim_game(3, 2, "tank", "next_extra").fragments == 1, "new day fragment reset")
	var final_meta: Dictionary = {}
	chests.setup(final_meta, ItemGenerator.new())
	for stage in range(1, 5):
		check(chests.ensure_evolution_chest(77, stage, stage + 1), "every evolution including final")
		var count := chests.pending_count()
		check(chests.ensure_evolution_chest(77, stage, stage + 1) and chests.pending_count() == count, "evolution duplicate")
		check(not chests.open_next().is_empty(), "evolution chest opens")
	check(chests.ensure_daily_chest(5), "daily at final stage")
	var daily_count := chests.pending_count()
	check(chests.ensure_daily_chest(5) and chests.pending_count() == daily_count, "daily duplicate")
	var effect := preload("res://screens/pet_home/chest_open_effect.gd").new()
	add_child(effect)
	await effect.finished
	check(true, "animation finishes")
	print("DAILY REWARDS checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
