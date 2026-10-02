class_name SudokuSession
extends RefCounted

var puzzle: Array = []
var board: Array = []
var notes: Array = []
var history: Array = []
var level := 0
var match_id := ""
var settled := false

func start(difficulty: int) -> void:
	level = clampi(difficulty, 0, 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	puzzle = SudokuRules.generate(level, rng).puzzle
	board = puzzle.duplicate()
	notes.resize(81)
	notes.fill(0)
	history.clear()
	settled = false
	match_id = "sudoku_" + Crypto.new().generate_random_bytes(16).hex_encode()

func restore(data: Dictionary) -> bool:
	for key in ["puzzle", "board", "notes"]:
		var values: Variant = data.get(key)
		if not values is Array or values.size() != 81:
			return false
		for value in values:
			if not (value is int or value is float) or float(value) != int(value) or int(value) < 0 or int(value) > (511 if key == "notes" else 9):
				return false
	if str(data.get("match_id", "")).is_empty():
		return false
	puzzle = []
	board = []
	notes = []
	for index in 81:
		puzzle.append(int(data.puzzle[index]))
		board.append(int(data.board[index]))
		notes.append(int(data.notes[index]))
	for index in 81:
		if int(puzzle[index]) > 0 and (int(board[index]) != int(puzzle[index]) or SudokuRules.conflicts(puzzle, index)):
			return false
	level = clampi(int(data.get("level", 0)), 0, 2)
	match_id = str(data.match_id)
	settled = bool(data.get("settled", false))
	history = []
	var saved: Variant = data.get("history", [])
	if saved is Array:
		for item in saved.slice(maxi(0, saved.size() - 100)):
			if not item is Dictionary or not item.get("board") is Array or item.board.size() != 81 or not item.get("notes") is Array or item.notes.size() != 81:
				return false
			var old_board: Array = []
			var old_notes: Array = []
			for index in 81:
				var value := int(item.board[index])
				var mask := int(item.notes[index])
				if value < 0 or value > 9 or mask < 0 or mask > 511 or (int(puzzle[index]) != 0 and value != int(puzzle[index])):
					return false
				old_board.append(value)
				old_notes.append(mask)
			history.append({"board": old_board, "notes": old_notes})
	return not settled or complete()

func snapshot() -> Dictionary:
	return {"schema": 1, "puzzle": puzzle.duplicate(), "board": board.duplicate(), "notes": notes.duplicate(), "history": history.duplicate(true), "level": level, "match_id": match_id, "settled": settled, "complete": complete()}

func complete() -> bool:
	if board.size() != 81 or board.has(0):
		return false
	for index in 81:
		if SudokuRules.conflicts(board, index):
			return false
	return true

func enter(index: int, value: int, note: bool = false) -> bool:
	if settled or complete() or index < 0 or index >= 81 or value < 0 or value > 9 or int(puzzle[index]) != 0:
		return false
	if note and (value == 0 or int(board[index]) != 0):
		return false
	if not note and int(board[index]) == value and (value != 0 or int(notes[index]) == 0):
		return false
	_remember()
	if note:
		notes[index] = int(notes[index]) ^ (1 << (value - 1))
	else:
		board[index] = value
		notes[index] = 0
		if value != 0:
			for other in 81:
				if SudokuRules.peers(index, other):
					notes[other] = int(notes[other]) & ~(1 << (value - 1))
	return true

func undo() -> bool:
	if settled or history.is_empty():
		return false
	var last: Dictionary = history.pop_back()
	board = last.board.duplicate()
	notes = last.notes.duplicate()
	return true

func _remember() -> void:
	history.append({"board": board.duplicate(), "notes": notes.duplicate()})
	if history.size() > 100:
		history.pop_front()
