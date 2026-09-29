class_name MazeHuntGame
extends RefCounted


const RESULT_PLAYING: StringName = &"playing"
const RESULT_WIN: StringName = &"win"
const RESULT_LOSE: StringName = &"lose"

const CELL_WALL: String = "#"
const CELL_ORB: String = "."
const CELL_POWER: String = "o"
const CELL_PLAYER: String = "P"

const MOVE_INTERVAL: float = 0.13
const ROUND_SECONDS: float = 90.0
const POWER_SECONDS: float = 6.0
const STARTING_LIVES: int = 3

const MAP := [
	"#################",
	"#.......#.......#",
	"#.###.#.#.#.###.#",
	"#o#...#...#...#o#",
	"#.#.###.#.###.#.#",
	"#.....#...#.....#",
	"###.#.#.#.#.#.###",
	"#...#...P...#...#",
	"#.#.###.#.###.#.#",
	"#o#.....#.....#o#",
	"#.#####.#.#####.#",
	"#...............#",
	"#################",
]

const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


var _rng := RandomNumberGenerator.new()
var _walls: Dictionary = {}
var _orbs: Dictionary = {}
var _power_orbs: Dictionary = {}
var _enemies: Array[Dictionary] = []

var _player_spawn := Vector2i.ZERO
var _player_pos := Vector2i.ZERO
var _direction := Vector2i.ZERO
var _requested_direction := Vector2i.ZERO

var _move_accumulator: float = 0.0
var _time_left: float = ROUND_SECONDS
var _power_left: float = 0.0
var _score: int = 0
var _lives: int = STARTING_LIVES
var _ghost_chain: int = 1
var _result: StringName = RESULT_PLAYING


func _init() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_walls.clear()
	_orbs.clear()
	_power_orbs.clear()
	_enemies.clear()

	for y in range(MAP.size()):
		var row := String(MAP[y])

		for x in range(row.length()):
			var cell := row.substr(x, 1)
			var pos := Vector2i(x, y)

			match cell:
				CELL_WALL:
					_walls[pos] = true
				CELL_ORB:
					_orbs[pos] = true
				CELL_POWER:
					_power_orbs[pos] = true
				CELL_PLAYER:
					_player_spawn = pos

	_player_pos = _player_spawn
	_direction = Vector2i.ZERO
	_requested_direction = Vector2i.ZERO
	_move_accumulator = 0.0
	_time_left = ROUND_SECONDS
	_power_left = 0.0
	_score = 0
	_lives = STARTING_LIVES
	_ghost_chain = 1
	_result = RESULT_PLAYING

	_add_enemy(Vector2i(1, 1), Vector2i.RIGHT)
	_add_enemy(Vector2i(15, 1), Vector2i.LEFT)


func tick(delta: float) -> void:
	if _result != RESULT_PLAYING:
		return

	delta = maxf(delta, 0.0)
	_time_left = maxf(0.0, _time_left - delta)
	_power_left = maxf(0.0, _power_left - delta)

	if _power_left <= 0.0:
		_ghost_chain = 1

	if _time_left <= 0.0:
		_result = RESULT_LOSE
		return

	_move_accumulator += delta

	while _move_accumulator >= MOVE_INTERVAL and _result == RESULT_PLAYING:
		_move_accumulator -= MOVE_INTERVAL
		_step()


func request_direction(direction: Vector2i) -> void:
	if direction in DIRECTIONS:
		_requested_direction = direction


func result() -> StringName:
	return _result


func score() -> int:
	return _score


func lives() -> int:
	return _lives


func time_left() -> float:
	return _time_left


func power_left() -> float:
	return _power_left


func width() -> int:
	return String(MAP[0]).length()


func height() -> int:
	return MAP.size()


func player_position() -> Vector2i:
	return _player_pos


func enemy_positions() -> Array[Vector2i]:
	var result_positions: Array[Vector2i] = []

	for enemy in _enemies:
		result_positions.append(enemy.get("pos", Vector2i.ZERO))

	return result_positions


func is_wall(pos: Vector2i) -> bool:
	return _walls.has(pos)


func has_orb(pos: Vector2i) -> bool:
	return _orbs.has(pos)


func has_power_orb(pos: Vector2i) -> bool:
	return _power_orbs.has(pos)


func remaining_collectibles() -> int:
	return _orbs.size() + _power_orbs.size()


func reward_tier() -> int:
	if _score >= 3000:
		return 4
	if _score >= 2000:
		return 3
	if _score >= 1000:
		return 2
	return 1


func snapshot() -> Dictionary:
	return {
		"result": String(_result),
		"score": _score,
		"lives": _lives,
		"time_left": _time_left,
		"power_left": _power_left,
		"remaining": remaining_collectibles(),
		"reward_tier": reward_tier(),
	}


func _step() -> void:
	if _can_walk(_player_pos + _requested_direction):
		_direction = _requested_direction

	if _can_walk(_player_pos + _direction):
		_player_pos += _direction

	_collect_at_player()

	if _resolve_collision():
		return

	_move_enemies()

	if _resolve_collision():
		return

	if remaining_collectibles() <= 0:
		_score += 500 + int(floor(_time_left)) * 5
		_result = RESULT_WIN


func _collect_at_player() -> void:
	if _orbs.erase(_player_pos):
		_score += 10

	if _power_orbs.erase(_player_pos):
		_score += 50
		_power_left = POWER_SECONDS
		_ghost_chain = 1


func _move_enemies() -> void:
	for index in range(_enemies.size()):
		var enemy := _enemies[index]
		var pos: Vector2i = enemy.get("pos", Vector2i.ZERO)
		var current: Vector2i = enemy.get("dir", Vector2i.ZERO)
		var choices: Array[Vector2i] = []

		for direction in DIRECTIONS:
			if direction == -current:
				continue
			if _can_walk(pos + direction):
				choices.append(direction)

		if choices.is_empty():
			for direction in DIRECTIONS:
				if _can_walk(pos + direction):
					choices.append(direction)

		if choices.is_empty():
			continue

		var chosen := _choose_enemy_direction(pos, choices)
		enemy["dir"] = chosen
		enemy["pos"] = pos + chosen
		_enemies[index] = enemy


func _choose_enemy_direction(
	pos: Vector2i,
	choices: Array[Vector2i]
) -> Vector2i:
	if choices.size() == 1:
		return choices[0]

	if _rng.randf() < 0.28:
		return choices[_rng.randi_range(0, choices.size() - 1)]

	var best: Vector2i = choices[0]
	var best_distance: int = 1000000

	for direction in choices:
		var next: Vector2i = pos + direction
		var distance: int = absi(next.x - _player_pos.x) + absi(next.y - _player_pos.y)

		if distance < best_distance:
			best_distance = distance
			best = direction

	return best


func _resolve_collision() -> bool:
	for index in range(_enemies.size()):
		var enemy := _enemies[index]

		if enemy.get("pos", Vector2i.ZERO) != _player_pos:
			continue

		if _power_left > 0.0:
			_score += 100 * _ghost_chain
			_ghost_chain = mini(_ghost_chain * 2, 8)
			enemy["pos"] = enemy.get("spawn", Vector2i.ZERO)
			enemy["dir"] = Vector2i.ZERO
			_enemies[index] = enemy
			return false

		_lives -= 1

		if _lives <= 0:
			_result = RESULT_LOSE
			return true

		_reset_positions()
		return true

	return false


func _reset_positions() -> void:
	_player_pos = _player_spawn
	_direction = Vector2i.ZERO
	_requested_direction = Vector2i.ZERO
	_move_accumulator = 0.0

	for index in range(_enemies.size()):
		var enemy := _enemies[index]
		enemy["pos"] = enemy.get("spawn", Vector2i.ZERO)
		enemy["dir"] = Vector2i.ZERO
		_enemies[index] = enemy


func _add_enemy(
	spawn: Vector2i,
	direction: Vector2i
) -> void:
	_enemies.append({
		"spawn": spawn,
		"pos": spawn,
		"dir": direction,
	})


func _can_walk(pos: Vector2i) -> bool:
	if (
		pos.x < 0
		or pos.y < 0
		or pos.x >= width()
		or pos.y >= height()
	):
		return false

	return not _walls.has(pos)
