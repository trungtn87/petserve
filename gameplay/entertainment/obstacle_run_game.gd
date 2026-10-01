class_name ObstacleRunGame
extends RefCounted

const RESULT_READY: StringName = &"ready"
const RESULT_PLAYING: StringName = &"playing"
const RESULT_WIN: StringName = &"win"
const RESULT_LOSE: StringName = &"lose"
const WORLD_SIZE := Vector2(320, 260)
const GROUND_Y: float = 210.0
const PLAYER_X: float = 64.0
const PLAYER_SIZE := Vector2(30, 32)
const ROUND_SECONDS: float = 40.0
const STARTING_LIVES: int = 3
const GRAVITY: float = 1000.0
const JUMP_SPEED: float = 420.0
const STEP: float = 1.0 / 120.0
const JUMP_BUFFER_SECONDS: float = 0.14

var _rng := RandomNumberGenerator.new()
var _result: StringName = RESULT_READY
var _match_id: String = ""
var _elapsed: float = 0.0
var _accumulator: float = 0.0
var _height: float = 0.0
var _velocity: float = 0.0
var _jump_buffer: float = 0.0
var _invulnerable: float = 0.0
var _spawn_left: float = 1.4
var _lives: int = STARTING_LIVES
var _passed: int = 0
var _finish_bonus: int = 0
var _obstacles: Array[Dictionary] = []

func _init() -> void:
	_rng.randomize()
	reset()

func reset() -> void:
	_match_id = "obstacle_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_result = RESULT_READY
	_elapsed = 0.0
	_accumulator = 0.0
	_height = 0.0
	_velocity = 0.0
	_jump_buffer = 0.0
	_invulnerable = 0.0
	_spawn_left = 1.4
	_lives = STARTING_LIVES
	_passed = 0
	_finish_bonus = 0
	_obstacles.clear()

func request_jump() -> void:
	if _result == RESULT_READY:
		_result = RESULT_PLAYING
	if _result != RESULT_PLAYING:
		return
	# A slightly early tap before landing still becomes a jump.
	_jump_buffer = JUMP_BUFFER_SECONDS

func tick(delta: float) -> void:
	if _result != RESULT_PLAYING:
		return
	# Do not fast-forward through obstacles after a mobile app hitch/resume.
	_accumulator += clampf(delta, 0.0, 0.25)
	while _accumulator >= STEP and _result == RESULT_PLAYING:
		_accumulator -= STEP
		_step(STEP)

func _step(delta: float) -> void:
	_elapsed = minf(ROUND_SECONDS, _elapsed + delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	if _jump_buffer > 0.0 and _height <= 0.0:
		_velocity = JUMP_SPEED
		_jump_buffer = 0.0
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_height = maxf(0.0, _height + _velocity * delta)
	_velocity -= GRAVITY * delta
	if _height <= 0.0:
		_velocity = 0.0

	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_obstacles.append({
			"x": WORLD_SIZE.x + 12.0,
			"width": _rng.randf_range(18.0, 26.0),
			"height": _rng.randf_range(22.0, 38.0),
			"resolved": false,
		})
		# At least two full jump cycles between obstacles, even late in a run.
		_spawn_left = _rng.randf_range(2.0, 2.6)

	for obstacle in _obstacles:
		obstacle["x"] = float(obstacle["x"]) - speed() * delta
		if bool(obstacle["resolved"]):
			continue
		var bounds := obstacle_rect(obstacle)
		if player_rect().grow(-4.0).intersects(bounds.grow(-2.0)):
			obstacle["resolved"] = true
			if _invulnerable <= 0.0:
				_lives -= 1
				_invulnerable = 1.5
				if _lives <= 0:
					_result = RESULT_LOSE
					return
		elif bounds.end.x < PLAYER_X:
			obstacle["resolved"] = true
			_passed += 1
	for index in range(_obstacles.size() - 1, -1, -1):
		if float(_obstacles[index]["x"]) < -40.0:
			_obstacles.remove_at(index)

	if _elapsed >= ROUND_SECONDS:
		_finish_bonus = 500 + _lives * 400
		_result = RESULT_WIN

func result() -> StringName:
	return _result

func match_id() -> String:
	return _match_id

func score() -> int:
	return int(floor(_elapsed)) * 10 + _passed * 100 + _finish_bonus

func lives() -> int:
	return _lives

func time_left() -> float:
	return maxf(0.0, ROUND_SECONDS - _elapsed)

func elapsed() -> float:
	return _elapsed

func passed() -> int:
	return _passed

func speed() -> float:
	return lerpf(115.0, 155.0, _elapsed / ROUND_SECONDS)

func is_grounded() -> bool:
	return _height <= 0.0

func is_invulnerable() -> bool:
	return _invulnerable > 0.0

func player_rect() -> Rect2:
	return Rect2(Vector2(PLAYER_X, GROUND_Y - PLAYER_SIZE.y - _height), PLAYER_SIZE)

func obstacle_rect(obstacle: Dictionary) -> Rect2:
	return Rect2(
		float(obstacle["x"]), GROUND_Y - float(obstacle["height"]),
		float(obstacle["width"]), float(obstacle["height"])
	)

func obstacles() -> Array[Dictionary]:
	return _obstacles.duplicate(true)

func reward_tier() -> int:
	return MiniGameRewardService.new().obstacle_reward_tier(score())
