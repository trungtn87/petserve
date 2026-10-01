extends Node

class FailingSaveFacade extends InfantGameFacade:
	var fail_save := false
	func save() -> bool:
		return false if fail_save else super.save()

var failures := 0
var checks := 0
var _original_meta: Dictionary
var _had_meta := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	call_deferred("run")

func row(values: Array) -> Array:
	var board := values.duplicate()
	board.resize(16)
	for index in range(values.size(), 16):
		board[index] = 0
	return board

func fixture(tile: int, run_id: int = 2048) -> Dictionary:
	var session := Energy2048Session.new()
	session.start()
	session.board = row([tile, 2])
	var data := session.snapshot()
	data["run_id"] = run_id
	return data

func run() -> void:
	_had_meta = SaveManager.has_meta_save()
	_original_meta = SaveManager.load_meta()
	_test_rules()
	_test_sessions()
	_test_rewards()
	_test_facade()
	await _test_ui()
	if _had_meta:
		SaveManager.save_meta(_original_meta)
	else:
		SaveManager.delete_meta()
	print("ENERGY 2048 checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)

func _test_rules() -> void:
	var result := Energy2048Rules.slide(row([2, 2, 2, 2]), Vector2i.LEFT)
	check(result.board.slice(0, 4) == [4, 4, 0, 0] and result.gained == 8, "four equal tiles merge pairwise")
	result = Energy2048Rules.slide(row([2, 2, 4, 0]), Vector2i.LEFT)
	check(result.board.slice(0, 4) == [4, 4, 0, 0] and result.gained == 4, "no chain merge within a move")
	result = Energy2048Rules.slide(row([2, 2, 2, 0]), Vector2i.RIGHT)
	check(result.board.slice(0, 4) == [0, 0, 2, 4], "right merges closest edge first")
	result = Energy2048Rules.slide(row([2, 0, 2, 2]), Vector2i.LEFT)
	check(result.board.slice(0, 4) == [4, 2, 0, 0], "compress gaps before merge")
	var vertical := [2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0, 2, 0, 0, 0]
	result = Energy2048Rules.slide(vertical, Vector2i.UP)
	check(result.board[0] == 4 and result.board[4] == 4 and result.board[12] == 0, "up merge")
	result = Energy2048Rules.slide(vertical, Vector2i.DOWN)
	check(result.board[12] == 4 and result.board[8] == 4 and result.board[0] == 0, "down merge")
	var blocked := [2,4,2,4,4,2,4,2,2,4,2,4,4,2,4,2]
	check(not Energy2048Rules.can_move(blocked), "full alternating board loses")
	blocked[0] = 4
	check(Energy2048Rules.can_move(blocked), "full board with adjacent pair stays playable")
	check(not Energy2048Rules.slide(row([2,4]), Vector2i.LEFT).changed, "invalid swipe stays unchanged")
	check(not Energy2048Rules.slide(row([2,4]), Vector2i.ZERO).changed, "invalid direction ignored")
	for pair in [[64,0], [128,1], [256,2], [512,3], [1024,5], [2048,10]]:
		check(Energy2048Rules.fragments(pair[0]) == pair[1], "reward threshold " + str(pair[0]))

func _test_sessions() -> void:
	var session := Energy2048Session.new()
	session.start()
	check(session.board.count(0) == 14, "new board has exactly two tiles")
	session.board = row([2,4])
	var before := session.snapshot()
	check(not session.move(Vector2i.LEFT).changed and session.snapshot() == before, "no-op consumes no spawn or RNG")
	var reloaded := Energy2048Session.new()
	check(reloaded.restore(JSON.parse_string(JSON.stringify(before))), "JSON round trip restores session")
	session.move(Vector2i.RIGHT)
	reloaded.move(Vector2i.RIGHT)
	check(session.snapshot() == reloaded.snapshot(), "resume preserves next spawn and score")
	check(session.board.count(0) == 13, "successful slide spawns exactly one tile")
	session.board = row([1024,1024])
	session.move(Vector2i.LEFT)
	check(session.status == "won" and session.score >= 2048, "2048 ends the game")
	before = session.snapshot()
	session.move(Vector2i.RIGHT)
	check(before == session.snapshot(), "cannot move after win")
	session.start()
	session.board = [8,16,8,16,16,8,16,8,8,16,8,16,32,64,32,0]
	session.move(Vector2i.RIGHT)
	check(session.status == "lost", "last spawn detects no remaining moves")
	session.start()
	session.finish()
	check(session.status == "ended", "early finish")
	var bad := fixture(128)
	bad.board[0] = 3
	check(not reloaded.restore(bad), "corrupt tiles rejected")

func _test_rewards() -> void:
	var data := fixture(512)
	var meta := {"energy_2048": data, "chest_fragments": 8}
	var chests := ChestService.new()
	chests.setup(meta, ItemGenerator.new())
	var rewards := MiniGameRewardService.new()
	rewards.setup(meta, chests, 2048)
	check(not rewards.claim_energy_2048(2048, 2, data.match_id).ok, "playing match cannot claim")
	data.status = "lost"
	check(not rewards.claim_energy_2048(2048, 2, "forged").ok, "wrong match ID rejected")
	check(not rewards.claim_energy_2048(999, 2, data.match_id).ok, "old life cannot claim")
	var result := rewards.claim_energy_2048(2048, 2, data.match_id)
	check(result.ok and result.fragments == 3 and result.crafted == 1, "loss awards only top milestone and crafts chest")
	check(chests.fragment_count() == 1 and chests.pending_count() == 1, "existing fragments combine correctly")
	check(not rewards.claim_energy_2048(2048, 2, data.match_id).ok, "duplicate claim rejected")
	meta = JSON.parse_string(JSON.stringify(meta))
	chests.setup(meta, ItemGenerator.new())
	rewards.setup(meta, chests, 2048)
	check(not rewards.claim_energy_2048(2048, 2, data.match_id).ok and chests.fragment_count() == 1, "reload cannot duplicate reward")
	check(int(rewards.snapshot(2048).stage2_activity_rewards_claimed) == 0, "2048 leaves existing stage2 shared cap untouched")

func _test_facade() -> void:
	SaveManager.save_meta({"energy_2048": fixture(128), "chest_fragments": 9})
	var game := FailingSaveFacade.new()
	check(game.setup(2048, 2, &"dark"), "facade setup")
	var initial := game.open_energy_2048()
	check(initial.ok and initial.state.board[0] == 128, "facade resumes saved board")
	check(not game.restart_energy_2048().ok, "restart cannot discard unsettled reward")
	game.fail_save = true
	check(not game.move_energy_2048(Vector2i.RIGHT).ok, "move surfaces persistence failure")
	check(game.energy_2048_snapshot() == initial.state, "failed move restores board, RNG and score")
	check(not game.finish_energy_2048().ok, "reward surfaces persistence failure")
	check(game.energy_2048_snapshot() == initial.state and game.snapshot().chest_fragments == 9, "failed reward restores board and fragments")
	game.fail_save = false
	var awarded := game.finish_energy_2048()
	check(awarded.ok and awarded.fragments == 1 and awarded.crafted == 1, "retry awards once")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(2048, 2, &"dark")
	check(not reloaded.finish_energy_2048().ok, "facade reward survives reload without duplication")
	check(reloaded.restart_energy_2048().ok, "new match after settlement")
	check(not reloaded.energy_2048_snapshot().settled, "new match is independently claimable")
	var new_life := InfantGameFacade.new()
	new_life.setup(2049, 1, &"water")
	check(new_life.energy_2048_snapshot().is_empty(), "new life cannot resume old board")

func _test_ui() -> void:
	SaveManager.save_meta({"energy_2048": fixture(128, 2049)})
	var game := InfantGameFacade.new()
	game.setup(2049, 1, &"water")
	var hub := EntertainmentHubUI.new()
	hub.energy_2048_api = game
	add_child(hub)
	hub.open_hub(0, 4, true)
	hub._open_energy_2048()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen := hub._energy_2048_activity
	check(screen.visible and screen._state.board.size() == 16, "PetHome hub opens a playable board")
	check(screen._board.size.x >= 240 and screen._board.size.y >= 210, "board remains large on 360x640 viewport")
	check(screen._message.get_global_rect().end.y <= hub.get_global_rect().end.y, "controls fit phone viewport")
	var match_id: String = screen._state.match_id
	hub._show_hub_screen()
	hub._open_energy_2048()
	check(screen._state.match_id == match_id, "back and reopen preserves match")
	# Exercise touch input at actual board-local coordinates.
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = screen._board._rect().get_center()
	screen._board._gui_input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = press.position + Vector2(70, 0)
	screen._board._gui_input(release)
	check(screen._state.board[3] == 2 and screen._state.board[2] == 128, "touch swipe slides right exactly once")
	check(game.energy_2048_snapshot().board == screen._state.board, "touch swipe persists displayed board")
	screen._board._elapsed = 1.0
	screen._request_finish()
	check(screen._confirm.visible and "1 mảnh" in screen._confirm.dialog_text, "early finish asks for confirmation with exact reward")
	screen._confirm.hide()
	screen._claim()
	check(screen._state.settled and screen._restart.visible and not screen._finish.visible, "successful reward changes to new-game action")
	screen._new_match()
	check(screen._state.match_id != match_id and not screen._state.settled, "UI new match works after claiming")
	hub.close_hub()
	check(not screen.visible, "closing hub stops interaction")
	hub.queue_free()
	await get_tree().process_frame
