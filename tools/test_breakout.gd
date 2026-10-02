extends Node

class FailingFacade extends InfantGameFacade:
	var fail_save := false
	func save() -> bool:
		return false if fail_save else super.save()

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var original := SaveManager.load_meta()
	var had := SaveManager.has_meta_save()
	var signatures: Array[String] = []
	var speed := 0.0
	var width := 999.0
	for level in range(1, 31):
		var map := BreakoutMaps.build(level)
		check(float(map.speed) > speed and float(map.paddle_width) < width, "difficulty increases")
		speed = float(map.speed)
		width = float(map.paddle_width)
		var signature := JSON.stringify(map.bricks)
		check(not signatures.has(signature), "30 distinct layouts")
		signatures.append(signature)
		var session := BreakoutSession.new()
		session.start(level)
		check(session.remaining() > 0 and session.lives == 3 and session.status == "ready", "playable initial map")
		var restored := BreakoutSession.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(session.snapshot()))), "map JSON resume")
	var session := BreakoutSession.new()
	session.start(1)
	session.set_paddle(-999)
	check(session.paddle_x == session.paddle_width() / 2 and session.ball.x == session.paddle_x, "left clamp and attached ball")
	session.set_paddle(999)
	check(session.paddle_x == 300 - session.paddle_width() / 2, "right clamp")
	session.launch()
	check(session.status == "playing" and session.velocity.y < 0, "launch")
	session.ball = Vector2(5.1, 250)
	session.velocity = Vector2(-100, 140)
	session.tick(0.02)
	check(session.velocity.x > 0, "wall bounce")
	session.set_paddle(150)
	session.ball = Vector2(150, 379)
	session.velocity = Vector2(0, 175)
	session.tick(0.02)
	check(session.velocity.y < 0 and absf(session.velocity.x) > 0, "paddle bounce avoids vertical trap")
	var brick: Dictionary = session.bricks[0]
	session.ball = Vector2(float(brick.x) + 20, float(brick.y) - 6)
	session.velocity = Vector2(0, 175)
	session.tick(0.02)
	check(int(brick.hp) == 0 and session.velocity.y < 0 and session.score == 10, "brick collision")
	session.drops = [{"x":150.0,"y":384.0,"kind":"wide"},{"x":150.0,"y":384.0,"kind":"slow"},{"x":150.0,"y":384.0,"kind":"life"}]
	session._update_drops(0.01)
	check(session.wide_time == 12 and session.slow_time == 10 and session.lives == 4 and session.drops.is_empty(), "all three pickups")
	for lost in 4:
		session.status = "playing"
		session.ball = Vector2(10, 424)
		session.velocity = Vector2(0,175)
		session.tick(0.02)
	check(session.status == "lost" and session.lives == 0, "falling ball consumes lives")
	session.start(20)
	var steel: Dictionary = {}
	for item in session.bricks:
		if int(item.hp) == -1:
			steel = item
		elif int(item.hp) > 1:
			var hp: int = item.hp
			session._hit(item)
			check(int(item.hp) == hp - 1, "armored brick takes one damage")
	check(not steel.is_empty(), "late map includes steel")
	session._hit(steel)
	check(int(steel.hp) == -1, "steel indestructible")
	for item in session.bricks:
		if int(item.hp) > 0:
			item.hp = 0
	session.launch()
	session.tick(0.01)
	check(session.status == "won", "steel does not block completion")
	await _facade_and_ui()
	if had:
		SaveManager.save_meta(original)
	else:
		SaveManager.delete_meta()
	print("BREAKOUT checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _facade_and_ui() -> void:
	SaveManager.save_meta({"chest_fragments": 9})
	var game := FailingFacade.new()
	check(game.setup(781, 2, &"dark"), "facade setup")
	check(game.open_breakout().ok, "start map one")
	check(not game.start_breakout(2).ok and not game.settle_breakout().ok, "locked map and incomplete reward denied")
	game.tick_breakout(0.01, 180, true)
	check(game.checkpoint_breakout().ok, "checkpoint")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(781, 2, &"dark")
	check(reloaded.open_breakout().state.ball == game.breakout_snapshot().ball, "reload retains moving ball")
	for brick in game._breakout_session.bricks:
		if int(brick.hp) > 0:
			brick.hp = 0
	game._breakout_session.status = "won"
	game.fail_save = true
	var fragments: int = game.snapshot().chest_fragments
	check(not game.settle_breakout().ok, "reward save failure")
	check(not game._breakout_session.settled and game.breakout_progress().unlocked == 1 and game.snapshot().chest_fragments == fragments, "failed reward rolls back progress and fragments")
	game.fail_save = false
	check(game.settle_breakout().chests == 1 and game.breakout_progress().unlocked == 2, "first clear rewards and unlocks")
	check(game.snapshot().chest_fragments == 9, "ten fragments craft chest")
	check(not game.settle_breakout().ok, "duplicate denied")
	reloaded = InfantGameFacade.new()
	reloaded.setup(781, 2, &"dark")
	reloaded.open_breakout()
	check(not reloaded.settle_breakout().ok and reloaded.breakout_progress().unlocked == 2, "durable settlement and unlock")
	check(reloaded.start_breakout(1).ok, "replay unlocked map")
	for brick in reloaded._breakout_session.bricks:
		brick.hp = 0
	reloaded._breakout_session.status = "won"
	check(reloaded.settle_breakout().fragments == 1, "repeat clear gives no duplicate first-clear reward")
	check(reloaded.start_breakout(2).ok, "new unlocked map")
	var hub := EntertainmentHubUI.new()
	hub.energy_2048_api = reloaded
	hub.size = Vector2(360,640)
	add_child(hub)
	hub.open_hub(0,4,true)
	hub._open_breakout()
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := hub._breakout_activity
	check(ui.visible and int(ui._state.level) == 2, "hub launches breakout")
	check(ui._board.size.y >= 300 and ui._message.get_global_rect().end.y <= ui.get_global_rect().end.y + 1, "phone board and controls fit")
	ui._set_paused(true)
	var before := reloaded.breakout_snapshot()
	ui._process(1.0)
	check(reloaded.breakout_snapshot() == before, "pause freezes physics")
	ui._set_paused(false)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = ui._board._area().position + ui._board._area().size * Vector2(0.6, 0.7)
	ui._board._gui_input(touch)
	check(absf(ui._target_x - 180) < 1 and ui._launch, "touch positions paddle and launches")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = ui._board._area().position + ui._board._area().size * Vector2(0.4, 0.7)
	ui._board._gui_input(drag)
	check(absf(ui._target_x - 120) < 1, "finger drag follows paddle")
	touch.pressed = false
	ui._board._gui_input(touch)
	ui._play_pressed()
	ui._process(0.02)
	check(reloaded._breakout_session.status == "playing", "launch button")
	hub.close_hub()
	check(not ui.visible, "close screen")
	var next := InfantGameFacade.new()
	next.setup(781, 2, &"dark")
	check(next.open_breakout().state.status == "playing", "close saves unfinished map")
	hub.queue_free()
	await get_tree().process_frame
