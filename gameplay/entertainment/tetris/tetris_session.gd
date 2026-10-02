class_name TetrisSession
extends RefCounted

const WIDTH := 10
const HEIGHT := 20
const MAX_LEVEL := 10
const POINTS_PER_FRAGMENT := 2000
const FALL_SECONDS := [0.65, 0.55, 0.45, 0.37, 0.30, 0.25, 0.20, 0.17, 0.14, 0.12]
const LOCK_SECONDS := [0.45, 0.425, 0.40, 0.375, 0.35, 0.325, 0.30, 0.275, 0.26, 0.25]
const SHAPES := [
	[Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1)],
	[Vector2i(1,0), Vector2i(2,0), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(1,0), Vector2i(2,0), Vector2i(0,1), Vector2i(1,1)],
	[Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
	[Vector2i(2,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1)],
]

var board: Array = []
var score := 0
var lines := 0
var combo := -1
var last_clear_four := false
var piece := 0
var rotation := 0
var position := Vector2i(3, 0)
var queue: Array[int] = []
var status := "idle"
var settled := false
var match_id := ""
var fall_elapsed := 0.0
var lock_elapsed := 0.0
var lock_resets := 0
var _rng := RandomNumberGenerator.new()

func start() -> void:
	_rng.randomize()
	board.resize(WIDTH * HEIGHT)
	board.fill(0)
	score = 0
	lines = 0
	combo = -1
	last_clear_four = false
	queue.clear()
	status = "playing"
	settled = false
	match_id = "tetris_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_fill_queue()
	_spawn(queue.pop_front())

func level() -> int:
	return mini(MAX_LEVEL, 1 + int(lines / 6))

func fall_interval() -> float:
	return FALL_SECONDS[level() - 1]

func lock_delay() -> float:
	return LOCK_SECONDS[level() - 1]

func fragments() -> int:
	return int(score / POINTS_PER_FRAGMENT)

func cells(kind: int, turn: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw in SHAPES[kind]:
		var cell: Vector2i = raw
		if kind != 1:
			var dimension := 4 if kind == 0 else 3
			for step in posmod(turn, 4):
				cell = Vector2i(dimension - 1 - cell.y, cell.x)
		result.append(cell)
	return result

func fits(at: Vector2i, turn: int) -> bool:
	for cell in cells(piece, turn):
		var point := at + cell
		if point.x < 0 or point.x >= WIDTH or point.y >= HEIGHT:
			return false
		if point.y >= 0 and int(board[point.y * WIDTH + point.x]) != 0:
			return false
	return true

func grounded() -> bool:
	return not fits(position + Vector2i.DOWN, rotation)

func ghost_position() -> Vector2i:
	var ghost := position
	while fits(ghost + Vector2i.DOWN, rotation):
		ghost += Vector2i.DOWN
	return ghost

func move_horizontal(direction: int) -> bool:
	if status != "playing" or direction not in [-1, 1]:
		return false
	var was_grounded := grounded()
	var target := position + Vector2i(direction, 0)
	if not fits(target, rotation):
		return false
	position = target
	_reset_lock(was_grounded)
	return true

func rotate_piece() -> bool:
	if status != "playing" or piece == 1:
		return false
	var was_grounded := grounded()
	var next_turn := posmod(rotation + 1, 4)
	# Small wall/floor kicks; never move the piece through occupied cells.
	for offset in [Vector2i.ZERO, Vector2i(-1,0), Vector2i(1,0), Vector2i(-2,0), Vector2i(2,0), Vector2i(0,-1), Vector2i(0,-2)]:
		if fits(position + offset, next_turn):
			position += offset
			rotation = next_turn
			_reset_lock(was_grounded)
			return true
	return false

func _reset_lock(was_grounded: bool) -> void:
	if was_grounded and lock_resets < 8:
		lock_elapsed = 0.0
		lock_resets += 1

func soft_drop() -> bool:
	if status != "playing" or grounded():
		return false
	position += Vector2i.DOWN
	fall_elapsed = 0.0
	return true

func hard_drop() -> void:
	if status != "playing":
		return
	position = ghost_position()
	_lock_piece()

func tick(delta: float) -> bool:
	if status != "playing" or delta <= 0.0:
		return false
	var changed := false
	# Process elapsed time in short slices so gravity and lock time are correct
	# even when a frame stalls. Background time is never fed to this method.
	var remaining := minf(delta, 0.5)
	while remaining > 0.000001 and status == "playing":
		var step := minf(remaining, 0.01)
		remaining -= step
		if grounded():
			lock_elapsed += step
			if lock_elapsed >= lock_delay():
				_lock_piece()
				changed = true
		else:
			fall_elapsed += step
			if fall_elapsed >= fall_interval():
				fall_elapsed -= fall_interval()
				position += Vector2i.DOWN
				changed = true
	return changed

func _lock_piece() -> void:
	for cell in cells(piece, rotation):
		if (position + cell).y < 0:
			status = "lost"
			return
	for cell in cells(piece, rotation):
		var point := position + cell
		board[point.y * WIDTH + point.x] = piece + 1
	_clear_lines()
	_fill_queue()
	_spawn(queue.pop_front())

func _clear_lines() -> int:
	var kept: Array = []
	var count := 0
	for y in HEIGHT:
		var row := board.slice(y * WIDTH, (y + 1) * WIDTH)
		if not row.has(0):
			count += 1
		else:
			kept.append_array(row)
	if count == 0:
		combo = -1
		return 0
	var multiplier := level()
	combo += 1
	var gained := int([0,100,300,500,800][count]) * multiplier
	if count == 4 and last_clear_four:
		gained += 400 * multiplier
	gained += 50 * combo * multiplier
	last_clear_four = count == 4
	score += gained
	lines += count
	board = []
	board.resize(count * WIDTH)
	board.fill(0)
	board.append_array(kept)
	return count

func _fill_queue() -> void:
	while queue.size() < 3:
		var bag: Array[int] = [0,1,2,3,4,5,6]
		for index in range(6, 0, -1):
			var other := _rng.randi_range(0, index)
			var temporary := bag[index]
			bag[index] = bag[other]
			bag[other] = temporary
		queue.append_array(bag)

func _spawn(kind: int) -> void:
	piece = kind
	rotation = 0
	position = Vector2i(3, 0)
	fall_elapsed = 0.0
	lock_elapsed = 0.0
	lock_resets = 0
	if not fits(position, rotation):
		status = "lost"

func abandon() -> void:
	if status == "playing":
		status = "abandoned"

func snapshot() -> Dictionary:
	return {"board": board.duplicate(), "score": score, "lines": lines,
		"level": level(), "piece": piece, "rotation": rotation,
		"position": position, "ghost": ghost_position(),
		"next": queue.slice(0, 2), "status": status, "settled": settled,
		"match_id": match_id, "fragments": fragments()}
