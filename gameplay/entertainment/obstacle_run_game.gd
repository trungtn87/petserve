class_name ObstacleRunGame
extends RefCounted

const RESULT_READY: StringName = &"ready"
const RESULT_PLAYING: StringName = &"playing"
const RESULT_WIN: StringName = &"win"
const RESULT_LOSE: StringName = &"lose"

const WORLD_SIZE := Vector2(320, 420)
const PLAYER_Y: float = 362.0
const PLAYER_SIZE := Vector2(34, 36)
const PLAYER_MARGIN: float = 10.0
const ROUND_SECONDS: float = 40.0
const STARTING_LIVES: int = 3
const MOVE_SPEED: float = 310.0
const STEP: float = 1.0 / 120.0
const HIT_PROTECTION_SECONDS: float = 1.15
const LANE_CENTERS := [38.0, 99.0, 160.0, 221.0, 282.0]

var _rng := RandomNumberGenerator.new()
var _result: StringName = RESULT_READY
var _match_id: String = ""
var _elapsed: float = 0.0
var _accumulator: float = 0.0
var _invulnerable: float = 0.0
var _spawn_left: float = 0.8
var _lives: int = STARTING_LIVES
var _passed: int = 0
var _finish_bonus: int = 0
var _player_x: float = 0.0
var _target_x: float = 0.0
var _move_axis: float = 0.0
var _obstacles: Array[Dictionary] = []

func _init() -> void:
	_rng.randomize()
	reset()

func reset() -> void:
	_match_id = "obstacle_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_result = RESULT_READY
	_elapsed = 0.0
	_accumulator = 0.0
	_invulnerable = 0.0
	_spawn_left = 0.8
	_lives = STARTING_LIVES
	_passed = 0
	_finish_bonus = 0
	_player_x = WORLD_SIZE.x * 0.5 - PLAYER_SIZE.x * 0.5
	_target_x = _player_x
	_move_axis = 0.0
	_obstacles.clear()

func request_move(world_x: float) -> void:
	if _result == RESULT_READY:
		_result = RESULT_PLAYING
	if _result != RESULT_PLAYING:
		return
	_target_x = clampf(
		world_x - PLAYER_SIZE.x * 0.5,
		PLAYER_MARGIN,
		WORLD_SIZE.x - PLAYER_MARGIN - PLAYER_SIZE.x
	)

func set_move_axis(axis: float) -> void:
	var next_axis := clampf(axis, -1.0, 1.0)
	if absf(next_axis) > 0.01 and _result == RESULT_READY:
		_result = RESULT_PLAYING
	if _result != RESULT_PLAYING:
		_move_axis = 0.0
		return
	if absf(_move_axis) > 0.01 and absf(next_axis) <= 0.01:
		_target_x = _player_x
	_move_axis = next_axis

func tick(delta: float) -> void:
	if _result != RESULT_PLAYING:
		return
	# Never fast-forward a whole rain of hazards after an app hitch/resume.
	_accumulator += clampf(delta, 0.0, 0.25)
	while _accumulator >= STEP and _result == RESULT_PLAYING:
		_accumulator -= STEP
		_step(STEP)

func _step(delta: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)

	if absf(_move_axis) > 0.01:
		_player_x += _move_axis * MOVE_SPEED * delta
	else:
		_player_x = move_toward(
			_player_x,
			_target_x,
			MOVE_SPEED * delta
		)
	_player_x = clampf(
		_player_x,
		PLAYER_MARGIN,
		WORLD_SIZE.x - PLAYER_MARGIN - PLAYER_SIZE.x
	)

	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_pattern()
		var base_interval := lerpf(0.88, 0.48, _difficulty())
		_spawn_left = _rng.randf_range(
			base_interval * 0.86,
			base_interval * 1.14
		)

	for obstacle in _obstacles:
		if bool(obstacle["resolved"]):
			continue
		obstacle["y"] = float(obstacle["y"]) + speed() * float(obstacle["speed_mult"]) * delta
		var bounds := obstacle_rect(obstacle)
		if player_rect().grow(-4.0).intersects(bounds.grow(-3.0)):
			obstacle["resolved"] = true
			obstacle["y"] = WORLD_SIZE.y + 100.0
			if _invulnerable <= 0.0:
				_lives -= 1
				_invulnerable = HIT_PROTECTION_SECONDS
				if _lives <= 0:
					_result = RESULT_LOSE
					return
		elif bounds.position.y > PLAYER_Y + PLAYER_SIZE.y:
			obstacle["resolved"] = true
			_passed += 1

	for index in range(_obstacles.size() - 1, -1, -1):
		if bool(_obstacles[index]["resolved"]) or float(_obstacles[index]["y"]) > WORLD_SIZE.y + 60.0:
			_obstacles.remove_at(index)

	if _elapsed >= ROUND_SECONDS:
		_finish_bonus = 500 + _lives * 400
		_result = RESULT_WIN

func _spawn_pattern() -> void:
	var blocked := 1
	var difficulty := _difficulty()
	if difficulty >= 0.42 and _rng.randf() < 0.34:
		blocked = 2
	if difficulty >= 0.78 and _rng.randf() < 0.22:
		blocked = 3

	var chosen: Array[int] = []
	while chosen.size() < blocked:
		var lane := _rng.randi_range(0, LANE_CENTERS.size() - 1)
		if not chosen.has(lane):
			chosen.append(lane)

	for lane in chosen:
		var kind_roll := _rng.randf()
		var kind: StringName = &"rock"
		var item_size := Vector2(30, 30)
		var speed_mult := 1.0
		if kind_roll < 0.34:
			kind = &"crate"
			item_size = Vector2(34, 34)
			speed_mult = 0.94
		elif kind_roll < 0.67:
			kind = &"orb"
			item_size = Vector2(27, 27)
			speed_mult = 1.10
		else:
			item_size = Vector2(30, 32)
			speed_mult = 1.0

		_obstacles.append({
			"x": float(LANE_CENTERS[lane]) - item_size.x * 0.5,
			"y": -item_size.y - _rng.randf_range(0.0, 12.0),
			"width": item_size.x,
			"height": item_size.y,
			"speed_mult": speed_mult,
			"kind": kind,
			"resolved": false,
		})

func _difficulty() -> float:
	return clampf(_elapsed / ROUND_SECONDS, 0.0, 1.0)

func result() -> StringName:
	return _result

func match_id() -> String:
	return _match_id

func score() -> int:
	return int(floor(_elapsed)) * 10 + _passed * 60 + _finish_bonus

func lives() -> int:
	return _lives

func time_left() -> float:
	return maxf(0.0, ROUND_SECONDS - _elapsed)

func elapsed() -> float:
	return _elapsed

func passed() -> int:
	return _passed

func speed() -> float:
	return lerpf(138.0, 228.0, _difficulty())

func is_invulnerable() -> bool:
	return _invulnerable > 0.0

func player_rect() -> Rect2:
	return Rect2(
		Vector2(_player_x, PLAYER_Y),
		PLAYER_SIZE
	)

func obstacle_rect(obstacle: Dictionary) -> Rect2:
	return Rect2(
		Vector2(float(obstacle["x"]), float(obstacle["y"])),
		Vector2(float(obstacle["width"]), float(obstacle["height"]))
	)

func obstacles() -> Array[Dictionary]:
	return _obstacles.duplicate(true)

func reward_tier() -> int:
	return MiniGameRewardService.new().obstacle_reward_tier(score())
