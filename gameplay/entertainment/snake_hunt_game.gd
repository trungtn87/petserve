class_name SnakeHuntGame
extends RefCounted


const RESULT_PLAYING: StringName = &"playing"
const RESULT_WIN: StringName = &"win"
const RESULT_LOSE: StringName = &"lose"

const GRID_WIDTH: int = 15
const GRID_HEIGHT: int = 19
const ROUND_SECONDS: float = 75.0
const TARGET_FOOD: int = 10
const START_INTERVAL: float = 0.22
const MIN_INTERVAL: float = 0.10

const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


var _rng := RandomNumberGenerator.new()
var _snake: Array[Vector2i] = []
var _direction := Vector2i.RIGHT
var _requested_direction := Vector2i.RIGHT
var _food := Vector2i.ZERO
var _gold_food: bool = false

var _move_accumulator: float = 0.0
var _time_left: float = ROUND_SECONDS
var _score: int = 0
var _food_eaten: int = 0
var _result: StringName = RESULT_PLAYING
var _match_sequence: int = 0
var _match_id: String = ""


func _init() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_match_sequence += 1
	_match_id = (
		"snake_%s_%s_%s"
		% [
			str(
				Time.get_unix_time_from_system()
			),
			str(
				Time.get_ticks_usec()
			),
			str(
				_match_sequence
			),
		]
	)
	_snake = [
		Vector2i(7, 9),
		Vector2i(6, 9),
		Vector2i(5, 9),
	]
	_direction = Vector2i.RIGHT
	_requested_direction = Vector2i.RIGHT
	_move_accumulator = 0.0
	_time_left = ROUND_SECONDS
	_score = 0
	_food_eaten = 0
	_result = RESULT_PLAYING
	_spawn_food()


func tick(delta: float) -> void:
	if _result != RESULT_PLAYING:
		return

	delta = maxf(delta, 0.0)
	_time_left = maxf(0.0, _time_left - delta)

	if _time_left <= 0.0:
		_result = RESULT_LOSE
		return

	_move_accumulator += delta
	var interval := move_interval()

	while (
		_move_accumulator >= interval
		and _result == RESULT_PLAYING
	):
		_move_accumulator -= interval
		_step()
		interval = move_interval()


func request_direction(direction: Vector2i) -> void:
	if direction not in DIRECTIONS:
		return

	if direction == -_direction:
		return

	_requested_direction = direction


func result() -> StringName:
	return _result


func match_id() -> String:
	return _match_id


func score() -> int:
	return _score


func food_eaten() -> int:
	return _food_eaten


func target_food() -> int:
	return TARGET_FOOD


func time_left() -> float:
	return _time_left


func move_interval() -> float:
	var speed_steps := _food_eaten / 3
	return maxf(
		MIN_INTERVAL,
		START_INTERVAL - float(speed_steps) * 0.025
	)


func snake_cells() -> Array[Vector2i]:
	return _snake.duplicate()


func head_position() -> Vector2i:
	if _snake.is_empty():
		return Vector2i.ZERO
	return _snake[0]


func food_position() -> Vector2i:
	return _food


func is_gold_food() -> bool:
	return _gold_food


func reward_tier() -> int:
	if _score >= 1900:
		return 4
	if _score >= 1400:
		return 3
	if _score >= 1000:
		return 2
	return 1


func snapshot() -> Dictionary:
	return {
		"match_id": _match_id,
		"result": String(_result),
		"score": _score,
		"food_eaten": _food_eaten,
		"target_food": TARGET_FOOD,
		"time_left": _time_left,
		"reward_tier": reward_tier(),
	}


func _step() -> void:
	if _requested_direction != -_direction:
		_direction = _requested_direction

	var next := head_position() + _direction

	if not _inside(next):
		_result = RESULT_LOSE
		return

	var will_eat := next == _food
	var collision_limit := (
		_snake.size()
		if will_eat
		else _snake.size() - 1
	)

	for index in range(maxi(0, collision_limit)):
		if _snake[index] == next:
			_result = RESULT_LOSE
			return

	_snake.push_front(next)

	if will_eat:
		_food_eaten += 1
		_score += 250 if _gold_food else 100

		if _food_eaten >= TARGET_FOOD:
			_score += 500 + int(floor(_time_left)) * 5
			_result = RESULT_WIN
			return

		_spawn_food()
	else:
		_snake.pop_back()


func _spawn_food() -> void:
	var open_cells: Array[Vector2i] = []

	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := Vector2i(x, y)

			if not _snake.has(cell):
				open_cells.append(cell)

	if open_cells.is_empty():
		_result = RESULT_WIN
		return

	_food = open_cells[
		_rng.randi_range(
			0,
			open_cells.size() - 1
		)
	]
	_gold_food = _rng.randf() <= 0.15


func _inside(pos: Vector2i) -> bool:
	return (
		pos.x >= 0
		and pos.y >= 0
		and pos.x < GRID_WIDTH
		and pos.y < GRID_HEIGHT
	)
