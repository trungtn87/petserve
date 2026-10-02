class_name BreakoutSession
extends RefCounted

const RADIUS := 5.0
const PADDLE_Y := 385.0
var level := 1
var bricks: Array = []
var ball := Vector2(150, 375)
var velocity := Vector2.ZERO
var paddle_x := 150.0
var lives := 3
var score := 0
var status := "ready"
var match_id := ""
var settled := false
var wide_time := 0.0
var slow_time := 0.0
var drops: Array = []
var destroyed := 0
var _speed := 175.0
var _width := 82.0

func start(map_level: int) -> void:
	var map := BreakoutMaps.build(map_level)
	level = int(map.level)
	bricks = map.bricks.duplicate(true)
	_speed = float(map.speed)
	_width = float(map.paddle_width)
	paddle_x = 150.0
	lives = 3
	score = 0
	status = "ready"
	settled = false
	wide_time = 0
	slow_time = 0
	destroyed = 0
	drops.clear()
	match_id = "breakout_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_reset_ball()

func paddle_width() -> float:
	return _width * (1.45 if wide_time > 0 else 1.0)

func set_paddle(x: float) -> void:
	paddle_x = clampf(x, paddle_width() / 2, BreakoutMaps.WIDTH - paddle_width() / 2)
	if status == "ready":
		_reset_ball()

func launch() -> void:
	if status != "ready":
		return
	status = "playing"
	velocity = Vector2(0.35 if destroyed % 2 == 0 else -0.35, -1).normalized() * _speed

func remaining() -> int:
	var count := 0
	for brick in bricks:
		if int(brick.hp) > 0:
			count += 1
	return count

func tick(delta: float) -> void:
	if status != "playing":
		return
	# Fine spatial steps prevent tunnelling through a brick at low frame rates.
	var duration := clampf(delta, 0, 0.1)
	var steps := maxi(1, int(ceil(velocity.length() * duration / 2.0)))
	for step in steps:
		if status != "playing":
			break
		_step(duration / steps)

func _step(dt: float) -> void:
	wide_time = maxf(0, wide_time - dt)
	slow_time = maxf(0, slow_time - dt)
	set_paddle(paddle_x)
	var previous := ball
	ball += velocity * dt * (0.72 if slow_time > 0 else 1.0)
	if ball.x < RADIUS:
		ball.x = RADIUS
		velocity.x = absf(velocity.x)
	elif ball.x > BreakoutMaps.WIDTH - RADIUS:
		ball.x = BreakoutMaps.WIDTH - RADIUS
		velocity.x = -absf(velocity.x)
	if ball.y < RADIUS:
		ball.y = RADIUS
		velocity.y = absf(velocity.y)
	if velocity.y > 0 and previous.y <= PADDLE_Y - RADIUS and ball.y >= PADDLE_Y - RADIUS and absf(ball.x - paddle_x) <= paddle_width() / 2 + RADIUS:
		ball.y = PADDLE_Y - RADIUS
		var offset := clampf((ball.x - paddle_x) / (paddle_width() / 2), -1, 1)
		var direction := Vector2(offset * 0.85, -1).normalized()
		if absf(direction.x) < 0.1:
			direction = Vector2(0.12 if velocity.x >= 0 else -0.12, -1).normalized()
		velocity = direction * _speed
	for brick in bricks:
		if int(brick.hp) == 0:
			continue
		var rect := Rect2(float(brick.x), float(brick.y), float(brick.w), float(brick.h)).grow(RADIUS)
		if not rect.has_point(ball):
			continue
		if previous.y <= rect.position.y:
			ball.y = rect.position.y - 0.01
			velocity.y = -absf(velocity.y)
		elif previous.y >= rect.end.y:
			ball.y = rect.end.y + 0.01
			velocity.y = absf(velocity.y)
		elif previous.x <= rect.position.x:
			ball.x = rect.position.x - 0.01
			velocity.x = -absf(velocity.x)
		else:
			ball.x = rect.end.x + 0.01
			velocity.x = absf(velocity.x)
		_hit(brick)
		break
	_update_drops(dt)
	if remaining() == 0:
		status = "won"
		velocity = Vector2.ZERO
	elif ball.y > BreakoutMaps.HEIGHT + RADIUS:
		lives -= 1
		wide_time = 0
		slow_time = 0
		drops.clear()
		status = "lost" if lives <= 0 else "ready"
		_reset_ball()

func _hit(brick: Dictionary) -> void:
	if int(brick.hp) < 0:
		return
	brick.hp = int(brick.hp) - 1
	score += 10
	if int(brick.hp) == 0:
		destroyed += 1
		if destroyed % 5 == 0:
			var kind: String = ["wide", "slow", "life"][(destroyed / 5 - 1) % 3]
			drops.append({"x": float(brick.x) + float(brick.w) / 2, "y": float(brick.y), "kind": kind})

func _update_drops(dt: float) -> void:
	for index in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.y = float(drop.y) + 85 * dt
		if float(drop.y) >= PADDLE_Y - 8 and float(drop.y) <= PADDLE_Y + 10 and absf(float(drop.x) - paddle_x) <= paddle_width() / 2 + 8:
			match str(drop.kind):
				"wide": wide_time = 12.0
				"slow": slow_time = 10.0
				"life": lives = mini(5, lives + 1)
			drops.remove_at(index)
		elif float(drop.y) > BreakoutMaps.HEIGHT:
			drops.remove_at(index)

func _reset_ball() -> void:
	ball = Vector2(paddle_x, PADDLE_Y - RADIUS - 2)
	velocity = Vector2.ZERO

func snapshot() -> Dictionary:
	return {"schema": 1, "level": level, "bricks": bricks.duplicate(true), "ball": [ball.x, ball.y], "velocity": [velocity.x, velocity.y], "paddle_x": paddle_x, "paddle_width": paddle_width(), "lives": lives, "score": score, "status": status, "match_id": match_id, "settled": settled, "wide_time": wide_time, "slow_time": slow_time, "drops": drops.duplicate(true), "destroyed": destroyed}

func restore(data: Dictionary) -> bool:
	if int(data.get("level", 0)) < 1 or int(data.get("level", 0)) > BreakoutMaps.COUNT or str(data.get("match_id", "")).is_empty():
		return false
	var map := BreakoutMaps.build(int(data.level))
	var saved: Variant = data.get("bricks")
	if not saved is Array or saved.size() != map.bricks.size():
		return false
	for index in saved.size():
		if not saved[index] is Dictionary:
			return false
		for key in ["x", "y", "w", "h"]:
			if float(saved[index].get(key, -999)) != float(map.bricks[index][key]):
				return false
		var hp := int(saved[index].get("hp", -999))
		var initial_hp := int(map.bricks[index].hp)
		if (initial_hp < 0 and hp != -1) or (initial_hp > 0 and (hp < 0 or hp > initial_hp)):
			return false
	for key in ["ball", "velocity"]:
		var vector: Variant = data.get(key)
		if not vector is Array or vector.size() != 2:
			return false
		for component in vector:
			if not (component is int or component is float) or not is_finite(float(component)):
				return false
	level = int(data.level)
	bricks = saved.duplicate(true)
	ball = Vector2(float(data.ball[0]), float(data.ball[1]))
	velocity = Vector2(float(data.velocity[0]), float(data.velocity[1]))
	_speed = float(map.speed)
	_width = float(map.paddle_width)
	paddle_x = clampf(float(data.get("paddle_x", 150)), _width / 2, BreakoutMaps.WIDTH - _width / 2)
	lives = int(data.get("lives", 3))
	if lives < 0 or lives > 5 or velocity.length() > _speed + 1 or ball.x < 0 or ball.x > BreakoutMaps.WIDTH or ball.y < 0 or ball.y > BreakoutMaps.HEIGHT + RADIUS + 2:
		return false
	status = str(data.get("status", "ready"))
	if status not in ["ready", "playing", "won", "lost"] or (status == "won" and remaining() != 0) or (status == "lost" and lives != 0):
		return false
	match_id = str(data.match_id)
	settled = bool(data.get("settled", false))
	if settled and status != "won":
		return false
	score = maxi(0, int(data.get("score", 0)))
	destroyed = maxi(0, int(data.get("destroyed", 0)))
	wide_time = clampf(float(data.get("wide_time", 0)), 0, 12)
	slow_time = clampf(float(data.get("slow_time", 0)), 0, 10)
	drops = []
	var saved_drops: Variant = data.get("drops", [])
	if saved_drops is Array:
		for drop in saved_drops:
			if drop is Dictionary and str(drop.get("kind", "")) in ["wide", "slow", "life"] and float(drop.get("x", -1)) >= 0 and float(drop.get("x", 999)) <= BreakoutMaps.WIDTH and float(drop.get("y", -1)) >= 0 and float(drop.get("y", 999)) <= BreakoutMaps.HEIGHT:
				drops.append(drop.duplicate())
	if status == "ready":
		_reset_ball()
	return true
