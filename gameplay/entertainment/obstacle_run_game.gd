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
const STARTING_LIVES: int = 3
const MOVE_SPEED: float = 340.0
const STEP: float = 1.0 / 120.0
const HIT_PROTECTION_SECONDS: float = 0.90
const LANE_CENTERS := [38.0, 99.0, 160.0, 221.0, 282.0]

const KIND_BERRY: StringName = &"berry"
const KIND_FISH: StringName = &"fish"
const KIND_MEAT: StringName = &"meat"
const KIND_TREAT: StringName = &"treat"
const KIND_ROCK: StringName = &"rock"
const KIND_CAN: StringName = &"can"
const KIND_POISON: StringName = &"poison"

var _rng := RandomNumberGenerator.new()
var _result: StringName = RESULT_READY
var _match_id: String = ""
var _elapsed: float = 0.0
var _accumulator: float = 0.0
var _invulnerable: float = 0.0
var _spawn_left: float = 0.65
var _lives: int = STARTING_LIVES
var _score: int = 0
var _eaten: int = 0
var _bad_hits: int = 0
var _player_x: float = 0.0
var _target_x: float = 0.0
var _move_axis: float = 0.0
var _obstacles: Array[Dictionary] = []


func _init() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_match_id = (
		"food_catch_"
		+ Crypto.new().generate_random_bytes(
			16
		).hex_encode()
	)
	_result = RESULT_READY
	_elapsed = 0.0
	_accumulator = 0.0
	_invulnerable = 0.0
	_spawn_left = 0.65
	_lives = STARTING_LIVES
	_score = 0
	_eaten = 0
	_bad_hits = 0
	_player_x = (
		WORLD_SIZE.x * 0.5
		- PLAYER_SIZE.x * 0.5
	)
	_target_x = _player_x
	_move_axis = 0.0
	_obstacles.clear()


func request_move(
	world_x: float
) -> void:
	if _result == RESULT_READY:
		_result = RESULT_PLAYING

	if _result != RESULT_PLAYING:
		return

	_target_x = clampf(
		world_x
		- PLAYER_SIZE.x * 0.5,
		PLAYER_MARGIN,
		WORLD_SIZE.x
		- PLAYER_MARGIN
		- PLAYER_SIZE.x
	)


func set_move_axis(
	axis: float
) -> void:
	var next_axis := clampf(
		axis,
		-1.0,
		1.0
	)

	if (
		absf(
			next_axis
		) > 0.01
		and _result == RESULT_READY
	):
		_result = RESULT_PLAYING

	if _result != RESULT_PLAYING:
		_move_axis = 0.0
		return

	if (
		absf(
			_move_axis
		) > 0.01
		and absf(
			next_axis
		) <= 0.01
	):
		_target_x = _player_x

	_move_axis = next_axis


func tick(
	delta: float
) -> void:
	if _result != RESULT_PLAYING:
		return

	# Không fast-forward cả màn vật rơi sau app hitch/resume.
	_accumulator += clampf(
		delta,
		0.0,
		0.25
	)

	while (
		_accumulator >= STEP
		and _result == RESULT_PLAYING
	):
		_accumulator -= STEP
		_step(
			STEP
		)


func _step(
	delta: float
) -> void:
	_elapsed += delta
	_invulnerable = maxf(
		0.0,
		_invulnerable - delta
	)

	if absf(
		_move_axis
	) > 0.01:
		_player_x += (
			_move_axis
			* MOVE_SPEED
			* delta
		)
	else:
		_player_x = move_toward(
			_player_x,
			_target_x,
			MOVE_SPEED * delta
		)

	_player_x = clampf(
		_player_x,
		PLAYER_MARGIN,
		WORLD_SIZE.x
		- PLAYER_MARGIN
		- PLAYER_SIZE.x
	)

	_spawn_left -= delta
	if _spawn_left <= 0.0:
		_spawn_pattern()
		var base_interval := lerpf(
			0.92,
			0.48,
			_difficulty()
		)
		_spawn_left = _rng.randf_range(
			base_interval * 0.82,
			base_interval * 1.18
		)

	for item in _obstacles:
		if bool(
			item.get(
				"resolved",
				false
			)
		):
			continue

		item["y"] = (
			float(
				item.get(
					"y",
					0.0
				)
			)
			+ speed()
			* float(
				item.get(
					"speed_mult",
					1.0
				)
			)
			* delta
		)

		var bounds := obstacle_rect(
			item
		)

		if player_rect().grow(
			-4.0
		).intersects(
			bounds.grow(
				-3.0
			)
		):
			item["resolved"] = true
			item["y"] = (
				WORLD_SIZE.y
				+ 100.0
			)

			if bool(
				item.get(
					"edible",
					false
				)
			):
				_score += maxi(
					0,
					int(
						item.get(
							"points",
							0
						)
					)
				)
				_eaten += 1
			elif _invulnerable <= 0.0:
				_lives -= 1
				_bad_hits += 1
				_invulnerable = (
					HIT_PROTECTION_SECONDS
				)

				if _lives <= 0:
					_result = RESULT_LOSE
					return
		elif (
			bounds.position.y
			> PLAYER_Y
			+ PLAYER_SIZE.y
		):
			item["resolved"] = true

	for index in range(
		_obstacles.size() - 1,
		-1,
		-1
	):
		if (
			bool(
				_obstacles[index].get(
					"resolved",
					false
				)
			)
			or float(
				_obstacles[index].get(
					"y",
					0.0
				)
			) > WORLD_SIZE.y
			+ 60.0
		):
			_obstacles.remove_at(
				index
			)


func _spawn_pattern() -> void:
	var amount := 1
	var difficulty := _difficulty()

	if (
		difficulty >= 0.35
		and _rng.randf() < lerpf(
			0.12,
			0.42,
			difficulty
		)
	):
		amount = 2

	var lanes: Array[int] = []

	while lanes.size() < amount:
		var lane := _rng.randi_range(
			0,
			LANE_CENTERS.size() - 1
		)

		if not lanes.has(
			lane
		):
			lanes.append(
				lane
			)

	for lane in lanes:
		_spawn_item(
			lane
		)


func _spawn_item(
	lane: int
) -> void:
	var roll := _rng.randf()
	var kind: StringName
	var edible := true
	var points := 0
	var item_size := Vector2(
		30,
		30
	)
	var speed_mult := 1.0

	if roll < 0.24:
		kind = KIND_BERRY
		points = 80
		item_size = Vector2(
			27,
			27
		)
		speed_mult = 1.08
	elif roll < 0.47:
		kind = KIND_FISH
		points = 120
		item_size = Vector2(
			34,
			24
		)
	elif roll < 0.64:
		kind = KIND_MEAT
		points = 160
		item_size = Vector2(
			31,
			28
		)
		speed_mult = 0.96
	elif roll < 0.72:
		kind = KIND_TREAT
		points = 220
		item_size = Vector2(
			28,
			28
		)
		speed_mult = 1.16
	elif roll < 0.83:
		kind = KIND_ROCK
		edible = false
		item_size = Vector2(
			31,
			29
		)
		speed_mult = 1.02
	elif roll < 0.93:
		kind = KIND_CAN
		edible = false
		item_size = Vector2(
			25,
			33
		)
		speed_mult = 1.10
	else:
		kind = KIND_POISON
		edible = false
		item_size = Vector2(
			29,
			29
		)
		speed_mult = 0.94

	_obstacles.append({
		"x": float(
			LANE_CENTERS[lane]
		)
		- item_size.x * 0.5,
		"y": -item_size.y
		- _rng.randf_range(
			0.0,
			12.0
		),
		"width": item_size.x,
		"height": item_size.y,
		"speed_mult": speed_mult,
		"kind": kind,
		"edible": edible,
		"points": points,
		"resolved": false,
	})


func _difficulty() -> float:
	# Không có thời gian kết thúc. Độ khó tăng mềm trong khoảng 3 phút rồi giữ trần.
	return clampf(
		_elapsed / 180.0,
		0.0,
		1.0
	)


func result() -> StringName:
	return _result


func match_id() -> String:
	return _match_id


func score() -> int:
	return _score


func lives() -> int:
	return _lives


func time_left() -> float:
	# Giữ API cũ cho caller legacy; game mới không có giới hạn thời gian.
	return 0.0


func elapsed() -> float:
	return _elapsed


func eaten() -> int:
	return _eaten


func bad_hits() -> int:
	return _bad_hits


func passed() -> int:
	# Alias legacy: số vật đã ăn.
	return _eaten


func speed() -> float:
	return lerpf(
		128.0,
		218.0,
		_difficulty()
	)


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func player_rect() -> Rect2:
	return Rect2(
		Vector2(
			_player_x,
			PLAYER_Y
		),
		PLAYER_SIZE
	)


func obstacle_rect(
	obstacle: Dictionary
) -> Rect2:
	return Rect2(
		Vector2(
			float(
				obstacle.get(
					"x",
					0.0
				)
			),
			float(
				obstacle.get(
					"y",
					0.0
				)
			)
		),
		Vector2(
			float(
				obstacle.get(
					"width",
					0.0
				)
			),
			float(
				obstacle.get(
					"height",
					0.0
				)
			)
		)
	)


func obstacles() -> Array[Dictionary]:
	return _obstacles.duplicate(
		true
	)


func reward_tier() -> int:
	return clampi(
		int(
			ceil(
				float(
					maxi(
						1,
						score()
					)
				)
				/ 500.0
			)
		),
		1,
		10
	)
