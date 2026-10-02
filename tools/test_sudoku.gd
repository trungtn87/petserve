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
	var had := SaveManager.has_meta_save()
	var original := SaveManager.load_meta()
	var rng := RandomNumberGenerator.new()
	rng.seed = 735
	var answers: Array = []
	for level in 3:
		for trial in 5:
			var generated := SudokuRules.generate(level, rng)
			check(SudokuRules.solutions(generated.puzzle.duplicate()) == 1, "unique puzzle")
			check(SudokuRules.solutions(generated.answer.duplicate()) == 1 and not generated.answer.has(0), "valid solution")
			answers.append(generated.answer)
			check(81 - generated.puzzle.count(0) >= SudokuRules.CLUES[level], "clue floor")
	check(answers[0] != answers[1], "random boards differ")
	var session := SudokuSession.new()
	session.start(0)
	var index := session.puzzle.find(0)
	var given := 0
	while int(session.puzzle[given]) == 0:
		given += 1
	check(not session.enter(given, 1), "given locked")
	check(session.enter(index, 2, true) and int(session.notes[index]) == 2, "note toggles")
	check(session.enter(index, 2, true) and int(session.notes[index]) == 0, "note removes")
	check(session.undo() and int(session.notes[index]) == 2, "undo restores note")
	var loaded := SudokuSession.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(session.snapshot()))), "JSON resume")
	check(loaded.notes == session.notes and loaded.history == session.history, "notes and undo survive")
	var invalid := session.snapshot()
	invalid.board[given] = 0
	check(not loaded.restore(invalid), "corrupt givens rejected")
	var generated := SudokuRules.generate(2, rng)
	var fixture := {"puzzle": generated.puzzle, "board": generated.answer, "notes": [], "level": 2, "match_id": "sudoku_test", "settled": false, "history": [], "run_id": 935}
	fixture.notes.resize(81)
	fixture.notes.fill(0)
	SaveManager.save_meta({"sudoku": fixture, "chest_fragments": 9})
	var game := FailingFacade.new()
	check(game.setup(935, 2, &"dark"), "setup")
	check(game.open_sudoku().state.complete, "resume completed board")
	check(not game.open_sudoku(0, true).ok, "cannot discard pending reward")
	var pending := game._chests.pending_count()
	game.fail_save = true
	check(not game.settle_sudoku().ok, "failed save reported")
	check(not game.sudoku_snapshot().settled and game.snapshot().chest_fragments == 9, "reward failure rolls back")
	game.fail_save = false
	check(game.settle_sudoku().chests == 1, "hard reward")
	check(game.snapshot().chest_fragments == 9 and game._chests.pending_count() == pending + 1, "daily chest preserves existing fragments")
	check(not game.settle_sudoku().ok, "duplicate denied")
	var reloaded := InfantGameFacade.new()
	reloaded.setup(935, 2, &"dark")
	check(not reloaded.settle_sudoku().ok, "reload duplicate denied")
	check(reloaded.open_sudoku(1, true).ok, "new board")
	var before := reloaded.sudoku_snapshot()
	index = before.puzzle.find(0)
	check(reloaded.enter_sudoku(index, 4, true).ok, "facade notes")
	var next := InfantGameFacade.new()
	next.setup(935, 2, &"dark")
	check(int(next.open_sudoku().state.notes[index]) == 8, "durable notes")
	check(next.undo_sudoku().state.notes[index] == 0, "durable undo")
	game = FailingFacade.new()
	game.setup(935, 2, &"dark")
	before = game.sudoku_snapshot()
	game.fail_save = true
	check(not game.enter_sudoku(index, 5).ok and game.sudoku_snapshot() == before, "failed move rollback")
	var hub := EntertainmentHubUI.new()
	hub.energy_2048_api = next
	hub.size = Vector2(320, 520)
	add_child(hub)
	hub.open_hub(0, 4, true)
	hub._open_sudoku()
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := hub._sudoku_activity
	check(ui.visible and ui._state.board.size() == 81, "hub opens Sudoku")
	check(ui._board.size.x >= 240 and ui._board.size.y >= 150, "phone board is usable")
	check(ui._numbers[8].get_global_rect().end.x <= ui.get_global_rect().end.x + 1, "number pad fits phone")
	check(ui._message.get_global_rect().end.y <= ui.get_global_rect().end.y + 1, "controls fit phone height")
	check(not next.settle_sudoku().ok, "unfinished puzzle cannot claim")
	ui._selected = index
	ui._notes.button_pressed = false
	ui._enter(5)
	check(int(next.sudoku_snapshot().board[index]) == 5, "UI number input")
	hub.close_hub()
	check(not ui.visible and int(next.sudoku_snapshot().board[index]) == 5, "close preserves board")
	hub.queue_free()
	await get_tree().process_frame
	if had:
		SaveManager.save_meta(original)
	else:
		SaveManager.delete_meta()
	print("SUDOKU checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
