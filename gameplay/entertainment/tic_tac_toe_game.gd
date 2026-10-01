class_name TicTacToeGame
extends RefCounted


const EMPTY: int = 0
const PLAYER: int = 1
const PET: int = 2

const RESULT_PLAYING: StringName = &"playing"
const RESULT_PLAYER: StringName = &"player"
const RESULT_PET: StringName = &"pet"
const RESULT_DRAW: StringName = &"draw"

const WIN_LINES: Array = [
	[0, 1, 2],
	[3, 4, 5],
	[6, 7, 8],
	[0, 3, 6],
	[1, 4, 7],
	[2, 5, 8],
	[0, 4, 8],
	[2, 4, 6],
]

const SMART_MOVE_CHANCE: float = 0.70
const BLOCK_CHANCE: float = 0.85


var _board: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_board = [
		EMPTY, EMPTY, EMPTY,
		EMPTY, EMPTY, EMPTY,
		EMPTY, EMPTY, EMPTY,
	]


func board() -> Array[int]:
	return _board.duplicate()


func result() -> StringName:
	for line in WIN_LINES:
		var a := int(line[0])
		var b := int(line[1])
		var c := int(line[2])
		var value := _board[a]

		if (
			value != EMPTY
			and value == _board[b]
			and value == _board[c]
		):
			return RESULT_PLAYER if value == PLAYER else RESULT_PET

	for value in _board:
		if value == EMPTY:
			return RESULT_PLAYING

	return RESULT_DRAW


func player_move(index: int) -> bool:
	if result() != RESULT_PLAYING:
		return false

	if index < 0 or index >= _board.size():
		return false

	if _board[index] != EMPTY:
		return false

	_board[index] = PLAYER
	return true


func pet_move() -> int:
	if result() != RESULT_PLAYING:
		return -1

	var index := _choose_pet_move()

	if index < 0:
		return -1

	_board[index] = PET
	return index


func _choose_pet_move() -> int:
	var open_cells := _open_cells()

	if open_cells.is_empty():
		return -1

	var winning := _find_finishing_move(PET)

	if winning >= 0:
		return winning

	var block := _find_finishing_move(PLAYER)

	if block >= 0 and _rng.randf() <= BLOCK_CHANCE:
		return block

	if _rng.randf() <= SMART_MOVE_CHANCE:
		var preferred: Array[int] = [4, 0, 2, 6, 8, 1, 3, 5, 7]

		for index in preferred:
			if _board[index] == EMPTY:
				return index

	return open_cells[_rng.randi_range(0, open_cells.size() - 1)]


func _find_finishing_move(side: int) -> int:
	for index in range(_board.size()):
		if _board[index] != EMPTY:
			continue

		_board[index] = side
		var current_result := result()
		_board[index] = EMPTY

		if (
			side == PLAYER
			and current_result == RESULT_PLAYER
		):
			return index

		if (
			side == PET
			and current_result == RESULT_PET
		):
			return index

	return -1


func _open_cells() -> Array[int]:
	var result_cells: Array[int] = []

	for index in range(_board.size()):
		if _board[index] == EMPTY:
			result_cells.append(index)

	return result_cells
