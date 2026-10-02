extends Node

class FailingSaveFacade extends InfantGameFacade:
	var fail_save := false
	func save() -> bool:
		return false if fail_save else super.save()

var checks := 0
var failures := 0
var original: Dictionary
var had_meta := false
var archive_text := ""
var had_archive := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	had_meta = SaveManager.has_meta_save()
	original = SaveManager.load_meta()
	had_archive = FileAccess.file_exists(TetrisRecords.ARCHIVE_PATH)
	if had_archive:
		archive_text = FileAccess.get_file_as_string(TetrisRecords.ARCHIVE_PATH)
	_test_session()
	_test_records()
	_test_facade()
	await _test_ui()
	if had_meta:
		SaveManager.save_meta(original)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.META_PATH))
	if had_archive:
		var file := FileAccess.open(TetrisRecords.ARCHIVE_PATH, FileAccess.WRITE)
		file.store_string(archive_text)
		file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TetrisRecords.ARCHIVE_PATH))
	print("TETRIS checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _fill_rows(session: TetrisSession, amount: int) -> void:
	session.board.fill(0)
	for y in range(20 - amount, 20):
		for x in 10:
			session.board[y * 10 + x] = 1

func _test_session() -> void:
	var session := TetrisSession.new()
	session.start()
	check(session.board.size() == 200 and session.score == 0 and session.lines == 0, "empty 10x20 board")
	var first_bag := [session.piece]
	first_bag.append_array(session.queue.slice(0,6))
	first_bag.sort()
	check(first_bag == [0,1,2,3,4,5,6], "seven bag has one of each shape")
	for kind in 7:
		for turn in 4:
			check(session.cells(kind, turn).size() == 4, "four cells for each rotation")
	session.tick(0.5)
	check(session.position.y == 0, "initial gravity interval")
	session.tick(0.16)
	check(session.position.y == 1 and session.score == 0, "gravity drops without scoring")
	session.piece = 1
	session.position = Vector2i(-1,0)
	check(not session.move_horizontal(-1), "left wall collision")
	session.position = Vector2i(3,0)
	check(session.ghost_position().y == 18, "ghost predicts bottom for O")
	session.hard_drop()
	check(session.score == 0, "hard drop awards no points")
	session.start()
	for amount in range(1,5):
		_fill_rows(session, amount)
		session.lines = 0
		session.score = 0
		session.combo = -1
		session.last_clear_four = false
		check(session._clear_lines() == amount and session.score == [0,100,300,500,800][amount], "line scoring " + str(amount))
		check(session.board.size() == 200 and session.board.count(0) == 200, "clears compact rows")
	_fill_rows(session,4)
	session.lines = 0
	session.score = 0
	session.combo = -1
	session.last_clear_four = false
	session._clear_lines()
	_fill_rows(session,4)
	session._clear_lines()
	check(session.score == 2050, "back to back four plus combo")
	session._clear_lines()
	check(session.combo == -1 and session.last_clear_four, "empty lock resets combo but preserves four-clear chain")
	session.lines = 60000
	check(session.level() == 10 and is_equal_approx(session.fall_interval(),0.12) and is_equal_approx(session.lock_delay(),0.25), "infinite game caps speed at level ten")
	session.combo = -1
	session.last_clear_four = false
	session.score = 0
	_fill_rows(session,4)
	session._clear_lines()
	check(session.score == 8000 and session.lines == 60004 and session.status == "playing", "score multiplier caps but play and lines continue")
	session.score = 47500
	check(session.fragments() == 23, "unlimited fragments")
	session.start()
	session.piece = 1
	session.position = Vector2i(3,18)
	for index in 12:
		session.move_horizontal(-1 if index % 2 == 0 else 1)
	check(session.lock_resets == 8, "lock delay reset limit")
	session.tick(0.46)
	check(session.board.count(0) == 196, "grounded piece locks")
	session.start()
	session.board.fill(1)
	session._spawn(0)
	check(session.status == "lost", "blocked spawn ends game")
	var before := session.snapshot()
	session.tick(1.0)
	session.hard_drop()
	check(session.snapshot() == before, "no play after loss")
	session.start()
	session.abandon()
	check(session.status == "abandoned", "abandon ends without settlement")

func _test_records() -> void:
	var records: Dictionary = {}
	var session := TetrisSession.new()
	session.start()
	session.score = 5000
	check(not TetrisRecords.record(records, session,"2026-10-02",100).broken_record, "tie with initial 5000 is not a record")
	session.start()
	session.score = 6000
	var result := TetrisRecords.record(records, session,"2026-10-02",101)
	check(result.bonus_chests == 1 and result.rank == 1, "first broken record grants one chest")
	session.start()
	session.score = 7000
	result = TetrisRecords.record(records,session,"2026-10-02",102)
	check(result.broken_record and result.bonus_chests == 0, "same day updates top but no repeated bonus")
	session.start()
	session.score = 8000
	check(TetrisRecords.record(records,session,"2026-10-01",103).bonus_chests == 0, "backward day does not reopen bonus")
	session.start()
	session.score = 9000
	check(TetrisRecords.record(records,session,"2026-10-03",104).bonus_chests == 1, "next day new record awards bonus")
	for index in 15:
		session.start()
		session.score = index
		TetrisRecords.record(records,session,"2026-10-03",200+index)
	check(records.entries.size() == 10 and records.entries[0].score == 9000, "top ten sorted by score")

func _test_facade() -> void:
	SaveManager.save_meta({"tetris_records": {}, "chest_fragments": 9, "daily_game_rewards_v2": {}, "last_daily_chest_day": ""})
	var game := FailingSaveFacade.new()
	check(game.setup(123,1,&"dark"), "facade setup")
	check(game.start_tetris().ok, "start via facade")
	check(not game.settle_tetris().ok, "playing match cannot receive reward")
	game._tetris_session.score = 47500
	game._tetris_session.status = "lost"
	game.fail_save = true
	check(not game.settle_tetris().ok, "failed reward save reported")
	check(game.snapshot().chest_fragments == 9 and game.tetris_records().is_empty() and not game._tetris_session.settled, "failed save rolls back fragments records bonus and settlement")
	game.fail_save = false
	var result := game.settle_tetris()
	check(result.ok and result.fragments == 0 and result.chests == 1 and result.bonus_chests == 0, "first completed match grants the daily chest without a score bonus")
	check(game.snapshot().chest_fragments == 9 and game._chests.pending_count() == 3, "daily game chest is added to hatch and daily login chests; fragments stay unchanged")
	check(not game.settle_tetris().ok, "cannot receive twice")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(123,1,&"dark")
	check(not reloaded.settle_tetris().ok and reloaded.tetris_records().best_score == 47500, "reload preserves top and cannot replay settlement")
	game.start_tetris()
	game._tetris_session.score = 49000
	game.abandon_tetris()
	check(not game.settle_tetris().ok, "abandon forfeits score reward")
	SaveManager.delete_meta()
	check(not SaveManager.has_meta_save() and TetrisRecords.load_archive().best_score == 47500, "life reset archives top before deleting inventory")
	var next_life := InfantGameFacade.new()
	next_life.setup(124,1,&"water")
	check(next_life.tetris_records().best_score == 47500, "top survives new pet life")
	next_life.start_tetris()
	next_life._tetris_session.score = 50000
	next_life._tetris_session.status = "lost"
	check(next_life.settle_tetris().bonus_chests == 0, "daily cap survives life reset")

func _test_ui() -> void:
	get_window().size = Vector2i(360, 640)
	get_window().content_scale_size = Vector2i(360, 640)
	SaveManager.save_meta({"tetris_records": {}})
	var game := InfantGameFacade.new()
	game.setup(125,1,&"water")
	var hub := EntertainmentHubUI.new()
	hub.energy_2048_api = game
	add_child(hub)
	hub.open_hub(0,4,true)
	hub._open_tetris()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := hub._tetris_activity
	check(screen.visible and screen._state.board.size() == 200, "hub launches tetris")
	check(screen._board.board_rect().size.y >= 260, "portrait board large enough")
	check(screen._message.get_global_rect().end.y <= hub.get_global_rect().end.y, "phone controls fit")
	var x: int = game._tetris_session.position.x
	screen._begin_horizontal(-1)
	check(game._tetris_session.position.x == x-1, "touch movement")
	screen._release_inputs()
	screen._toggle_pause()
	var before := game.tetris_snapshot()
	screen._process(1.0)
	check(game.tetris_snapshot() == before, "pause freezes gravity")
	screen._toggle_pause()
	screen._show_ranking()
	before = game.tetris_snapshot()
	screen._process(1.0)
	check(game.tetris_snapshot() == before and screen._ranking.visible, "ranking modal freezes game")
	screen._ranking.hide()
	screen._process(0.0)
	check(not game.action_tetris("hold").ok, "hold function removed")
	check(screen._handheld._rects().size() == 5, "four directions plus one rotation button")
	check(screen._handheld._rects().rotate.size.x >= 80, "large rotation button")
	check(screen._handheld.get_global_rect().end.y <= hub.get_global_rect().end.y and screen._handheld.get_global_rect().end.x <= 360, "handheld fits phone")
	var turn := game._tetris_session.rotation
	game._tetris_session.piece = 2
	var pad := screen._handheld
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.pressed = true
	press.position = pad.get_global_transform_with_canvas() * pad._rects().left.get_center()
	pad._input(press)
	var rotate := InputEventScreenTouch.new()
	rotate.index = 2
	rotate.pressed = true
	rotate.position = pad.get_global_transform_with_canvas() * pad._rects().rotate.get_center()
	pad._input(rotate)
	check(game._tetris_session.rotation != turn and screen._horizontal == -1, "multitouch rotates while moving")
	press.pressed = false
	pad._input(press)
	check(screen._horizontal == 0, "finger release stops movement")
	rotate.pressed = false
	pad._input(rotate)
	var drop := InputEventScreenTouch.new()
	drop.index = 3
	drop.pressed = true
	drop.position = pad.get_global_transform_with_canvas() * pad._rects().drop.get_center()
	pad._input(drop)
	check(game._tetris_session.board.count(0) == 196, "up direction hard drops")
	drop.pressed = false
	pad._input(drop)
	screen._request_back()
	check(screen._confirm.visible, "back confirms reward forfeiture")
	screen._confirm.hide()
	game._tetris_session.score = 6000
	game._tetris_session.status = "lost"
	screen._apply({"ok":true,"state":game.tetris_snapshot()})
	check(game._tetris_session.settled and screen._new.visible and not screen._claim.visible, "loss automatically settles once")
	await get_tree().process_frame
	check(screen._message.get_global_rect().end.y <= hub.get_global_rect().end.y, "result controls fit phone")
	screen._new_match()
	check(game._tetris_session.status == "playing", "replay starts new game")
	hub.close_hub()
	check(game._tetris_session == null and not screen.visible, "close forfeits active game")
	hub.queue_free()
	await get_tree().process_frame
