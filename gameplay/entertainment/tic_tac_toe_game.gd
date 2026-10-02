class_name TicTacToeGame
extends RefCounted
## Freestyle Gomoku. Legacy class name preserves existing reward integrations.
const SIZE := 15
const EMPTY := 0
const PLAYER := 1
const PET := 2
const RESULT_PLAYING: StringName = &"playing"
const RESULT_PLAYER: StringName = &"player"
const RESULT_PET: StringName = &"pet"
const RESULT_DRAW: StringName = &"draw"
const DIRECTIONS := [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(1,-1)]
var _board: Array[int] = []
var turn := PLAYER
var moves := 0
var last_move := -1
var winning_cells: Array[int] = []
var _result := RESULT_PLAYING

func _init() -> void:
	reset()

func reset() -> void:
	_board.resize(SIZE * SIZE)
	_board.fill(EMPTY)
	turn = PLAYER
	moves = 0
	last_move = -1
	winning_cells.clear()
	_result = RESULT_PLAYING

func board() -> Array[int]:
	return _board.duplicate()

func result() -> StringName:
	return _result

func play(index: int, side: int) -> bool:
	if _result != RESULT_PLAYING or side != turn or index < 0 or index >= _board.size() or _board[index] != EMPTY:
		return false
	_board[index] = side
	last_move = index
	moves += 1
	winning_cells = _line(index, side)
	if not winning_cells.is_empty():
		_result = RESULT_PLAYER if side == PLAYER else RESULT_PET
	elif moves == SIZE * SIZE:
		_result = RESULT_DRAW
	turn = PET if side == PLAYER else PLAYER
	return true

func player_move(index: int) -> bool:
	return play(index, PLAYER)

func pet_move() -> int:
	if turn != PET or _result != RESULT_PLAYING:
		return -1
	var candidates := _candidates()
	for side in [PET, PLAYER]:
		for index in candidates:
			_board[index] = side
			var wins := not _line(index, side).is_empty()
			_board[index] = EMPTY
			if wins:
				play(index, PET)
				return index
	var best := -1
	var best_score := -1.0
	for index in candidates:
		var score := _score(index, PET) * 1.1 + _score(index, PLAYER)
		var point := Vector2(index % SIZE, index / SIZE)
		score += 1.0 / (1.0 + point.distance_to(Vector2(7,7)))
		if score > best_score:
			best_score = score
			best = index
	if best >= 0:
		play(best, PET)
	return best

func _inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE

func _line(index: int, side: int) -> Array[int]:
	var origin := Vector2i(index % SIZE, index / SIZE)
	for direction in DIRECTIONS:
		var cells: Array[int] = [index]
		for sign_value in [-1,1]:
			var p: Vector2i = origin + direction * sign_value
			while _inside(p) and _board[p.y * SIZE + p.x] == side:
				cells.append(p.y * SIZE + p.x)
				p += direction * sign_value
		if cells.size() >= 5:
			return cells
	return []

func _candidates() -> Array[int]:
	if moves == 0:
		return [112]
	var found: Dictionary = {}
	for index in _board.size():
		if _board[index] == EMPTY:
			continue
		var origin := Vector2i(index % SIZE, index / SIZE)
		for dy in range(-2,3):
			for dx in range(-2,3):
				var p := origin + Vector2i(dx,dy)
				if _inside(p) and _board[p.y * SIZE + p.x] == EMPTY:
					found[p.y * SIZE + p.x] = true
	var cells: Array[int] = []
	for index in found:
		cells.append(int(index))
	return cells

func _score(index: int, side: int) -> float:
	var score := 0.0
	var origin := Vector2i(index % SIZE, index / SIZE)
	for direction in DIRECTIONS:
		var count := 1
		var open_ends := 0
		for sign_value in [-1,1]:
			var p: Vector2i = origin + direction * sign_value
			while _inside(p) and _board[p.y * SIZE + p.x] == side:
				count += 1
				p += direction * sign_value
			if _inside(p) and _board[p.y * SIZE + p.x] == EMPTY:
				open_ends += 1
		if open_ends > 0:
			score += pow(8.0, count) * open_ends
	return score
