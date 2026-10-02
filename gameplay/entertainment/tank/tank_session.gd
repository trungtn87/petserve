class_name TankSession
extends RefCounted
## Authority-only simulation. All snapshots contain JSON-compatible primitives.
const DIRS := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
const STEP := 1.0 / 60.0
var rng := RandomNumberGenerator.new()
var match_id := ""
var status := "idle"
var duo := false
var settled := false
var wave := 0
var map_index := -1
var deck: Array = []
var tiles: Array = []
var players: Array = []
var enemies: Array = []
var bullets: Array = []
var pickups: Array = []
var effects: Array = []
var remaining := 0
var spawn_clock := 0.0
var frozen := 0.0
var fort := 0.0
var base_hp := 1
var base_grace := 0.0
var accumulator := 0.0
var serial := 0
var inputs := [{"dir": -1, "fire": false}, {"dir": -1, "fire": false}]

func start(two_players: bool = false, seed_value: int = 0) -> void:
	rng.randomize()
	if seed_value != 0:
		rng.seed = seed_value
	duo = two_players
	settled = false
	match_id = "tank_" + Crypto.new().generate_random_bytes(16).hex_encode()
	status = "playing"
	wave = 0
	deck.clear()
	players.clear()
	inputs = [{"dir": -1, "fire": false}, {"dir": -1, "fire": false}]
	for slot in (2 if duo else 1):
		players.append({"x": 6.5 + slot * 4, "y": 15.5, "dir": 0, "lives": 3 if duo else 5,
			"score": 0, "gun": 0 if duo else 1, "shield": 3.0, "cool": 0.0})
	_next_wave()

func _next_wave() -> void:
	wave += 1
	if deck.is_empty():
		for i in 20:
			deck.append(i)
		for i in range(19, 0, -1):
			var j := rng.randi_range(0, i)
			var old: int = deck[i]
			deck[i] = deck[j]
			deck[j] = old
		if deck.back() == map_index:
			var old: int = deck[0]
			deck[0] = deck[19]
			deck[19] = old
	map_index = int(deck.pop_back())
	tiles = TankMaps.cells(map_index)
	if not duo:
		# A clear defensive cross-lane lets one tank cover both flanks.
		for y in [12, 13]:
			for x in 16:
				tiles[y * 16 + x] = 0
		# Break up the three long firing lanes without sealing off the map.
		for x in [0, 8, 15]:
			tiles[11 * 16 + x] = 1
	base_hp = 1 if duo else 3
	base_grace = 0.0
	enemies.clear()
	bullets.clear()
	pickups.clear()
	effects.clear()
	remaining = 16 + mini(wave, 10) * 2 if duo else 8 + mini(6, (wave - 1) * 2 / 3)
	spawn_clock = 1.0 if duo else 4.0
	frozen = 0.0
	fort = 0.0 if duo else 15.0
	for i in players.size():
		players[i].x = 6.5 + i * 4
		players[i].y = 15.5
		players[i].shield = 3.0

func set_input(slot: int, direction: int, fire: bool) -> void:
	if slot >= 0 and slot < players.size():
		inputs[slot] = {"dir": clampi(direction, -1, 3), "fire": fire}

func tick(delta: float) -> void:
	if status != "playing":
		return
	accumulator += clampf(delta, 0, 0.1)
	while accumulator >= STEP and status == "playing":
		accumulator -= STEP
		_step(STEP)

func _step(dt: float) -> void:
	frozen = maxf(0, frozen - dt)
	fort = maxf(0, fort - dt)
	base_grace = maxf(0, base_grace - dt)
	for effect in effects:
		effect.time -= dt
	effects = effects.filter(func(e: Dictionary) -> bool: return float(e.time) > 0)
	for i in players.size():
		var p: Dictionary = players[i]
		p.shield = maxf(0, float(p.shield) - dt)
		p.cool = maxf(0, float(p.cool) - dt)
		if int(p.lives) <= 0:
			continue
		var direction := int(inputs[i].dir)
		if direction >= 0:
			p.dir = direction
			_move(p, 3.0 * dt)
		if bool(inputs[i].fire):
			_fire(p, i, int(p.gun))
		for item in pickups.duplicate():
			if Vector2(p.x, p.y).distance_to(Vector2(item.x, item.y)) < 0.75:
				_power(p, int(item.kind), i)
				pickups.erase(item)
	spawn_clock -= dt
	if remaining > 0 and enemies.size() < enemy_limit() and spawn_clock <= 0:
		_spawn()
		spawn_clock = spawn_interval()
	if frozen <= 0:
		for e in enemies:
			e.cool = maxf(0, float(e.cool) - dt)
			e.turn -= dt
			if float(e.turn) <= 0:
				e.dir = _enemy_direction(e)
				e.turn = rng.randf_range(0.4, 1.0)
			if not _move(e, float(e.speed) * dt):
				e.turn = 0.0
			_fire(e, -1, 1 if int(e.kind) == 2 else 0)
	_update_bullets(dt)
	if status != "playing":
		return
	var alive := false
	for p in players:
		alive = alive or int(p.lives) > 0
	if not alive:
		status = "lost"
	elif remaining == 0 and enemies.is_empty():
		_next_wave()

func _spawn() -> void:
	var x := [0.5, 8.5, 15.5][rng.randi_range(0, 2)] as float
	for e in enemies:
		if Vector2(e.x, e.y).distance_to(Vector2(x, 0.5)) < 1.0:
			return
	var kind := rng.randi_range(0, mini(3, 1 + wave / 3) if duo else mini(3, (wave - 1) / 3))
	serial += 1
	enemies.append({"id": serial, "x": x, "y": 0.5, "dir": 2, "hp": 3 if kind == 3 else 1,
		"kind": kind, "speed": ((2.0 if kind == 1 else 1.2) + mini(wave, 10) * 0.06) if duo else (1.3 if kind == 1 else 0.9) + mini(wave, 10) * 0.03,
		"turn": 0.0, "cool": 0.7, "carrier": serial % (5 if duo else 3) == 0})
	remaining -= 1

func _enemy_direction(e: Dictionary) -> int:
	# Follow a shortest route to the base; brick is traversable in planning and shot on contact.
	# Most early solo turns patrol corridors instead of rushing the objective.
	if not duo and float(e.y) < 10.0 and rng.randf() < 0.55:
		return int(e.dir) if rng.randf() < 0.5 else rng.randi_range(0,3)
	var start_cell := Vector2i(int(e.x), int(e.y))
	var queue: Array = [start_cell]
	var first: Dictionary = {start_cell: -1}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == Vector2i(8, 15):
			return int(first[cell]) if int(first[cell]) >= 0 else 2
		for d in [2, 1, 3, 0]:
			var next := cell + Vector2i(DIRS[d])
			if next.x < 0 or next.x >= 16 or next.y < 0 or next.y >= 16 or first.has(next):
				continue
			if int(tiles[next.y * 16 + next.x]) in [2, 3]:
				continue
			first[next] = d if cell == start_cell else first[cell]
			queue.append(next)
	return rng.randi_range(0, 3)

func _move(tank: Dictionary, amount: float) -> bool:
	var pos := Vector2(tank.x, tank.y)
	var d: Vector2 = DIRS[int(tank.dir)]
	# Steer toward lane centers when turning, rather than snagging tile corners.
	if d.x == 0:
		pos.x = move_toward(pos.x, floorf(pos.x) + 0.5, amount)
	else:
		pos.y = move_toward(pos.y, floorf(pos.y) + 0.5, amount)
	var next := pos + d * amount
	for corner in [Vector2(-0.32,-0.32), Vector2(0.32,-0.32), Vector2(-0.32,0.32), Vector2(0.32,0.32)]:
		var point: Vector2 = next + corner
		if point.x < 0 or point.y < 0 or point.x >= 16 or point.y >= 16:
			return false
		if int(tiles[int(point.y) * 16 + int(point.x)]) in [1, 2, 3, 5]:
			return false
	# Enemy tanks cannot drive through players or other enemies. Allies may overlap.
	for other in enemies + players:
		if other == tank or (not tank.has("id") and not other.has("id")):
			continue
		if other.has("lives") and int(other.lives) <= 0:
			continue
		var center := Vector2(other.x, other.y)
		var offset := next - center
		if absf(offset.x) < 0.68 and absf(offset.y) < 0.68 and next.distance_squared_to(center) < pos.distance_squared_to(center):
			return false
	tank.x = next.x
	tank.y = next.y
	return true

func _fire(tank: Dictionary, owner: int, gun: int) -> void:
	if float(tank.cool) > 0:
		return
	var count := 0
	for b in bullets:
		if int(b.owner) == owner and (owner >= 0 or int(b.source) == int(tank.id)):
			count += 1
	if count >= (2 if gun >= 2 or (owner >= 0 and not duo) else 1):
		return
	var dir: Vector2 = DIRS[int(tank.dir)]
	bullets.append({"x": float(tank.x) + dir.x * 0.43, "y": float(tank.y) + dir.y * 0.43,
		"dir": int(tank.dir), "owner": owner, "source": int(tank.get("id", 0)), "gun": gun})
	if owner >= 0:
		tank.cool = 0.25
	elif duo:
		tank.cool = maxf(0.4, (1.0 if int(tank.get("kind",0)) == 2 else 1.4) - mini(wave, 10) * 0.07)
	else:
		tank.cool = maxf(1.2, (1.8 if int(tank.get("kind",0)) == 2 else 2.2) - mini(wave, 10) * 0.05)

func _update_bullets(dt: float) -> void:
	var dead: Array = []
	for b in bullets:
		for sub in 2:
			var d: Vector2 = DIRS[int(b.dir)]
			var speed := 10.0 if int(b.gun) > 0 else 7.0
			if int(b.owner) < 0 and not duo:
				speed = 7.0 if int(b.gun) > 0 else 5.0
			b.x += d.x * speed * dt * 0.5
			b.y += d.y * speed * dt * 0.5
			if b.x < 0 or b.y < 0 or b.x >= 16 or b.y >= 16:
				dead.append(b)
				break
			var cell := int(b.y) * 16 + int(b.x)
			var tile := int(tiles[cell])
			if tile in [1, 2, 5]:
				if tile == 1 or (tile == 2 and int(b.gun) >= 3):
					if not (fort > 0 and cell in [231,232,233,247,249]):
						tiles[cell] = 0
				if tile == 5:
					if duo:
						base_hp = 0
					elif int(b.owner) < 0 and fort <= 0 and base_grace <= 0:
						base_hp -= 1
						base_grace = 2.5
						_explode(8.5, 15.5)
					if base_hp <= 0:
						status = "lost"
				dead.append(b)
				break
			var targets: Array = enemies.duplicate() if int(b.owner) >= 0 else players
			var hit := false
			for t in targets:
				if int(b.owner) < 0 and int(t.lives) <= 0:
					continue
				if absf(float(t.x) - float(b.x)) < 0.38 and absf(float(t.y) - float(b.y)) < 0.38:
					hit = true
					if int(b.owner) >= 0:
						t.hp -= 1
						if int(t.hp) <= 0:
							_kill(t, int(b.owner))
					elif float(t.shield) <= 0:
						t.lives -= 1
						t.gun = 0 if duo else maxi(1, int(t.gun) - 1)
						_explode(float(t.x), float(t.y))
						t.x = 6.5 + players.find(t) * 4
						t.y = 15.5
						t.shield = 3.0
					break
			if hit:
				dead.append(b)
				break
	for b in dead:
		bullets.erase(b)
	# Opposing projectiles cancel each other.
	for a in bullets.duplicate():
		for b in bullets.duplicate():
			if (int(a.owner) < 0) != (int(b.owner) < 0) and Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y)) < 0.22:
				bullets.erase(a)
				bullets.erase(b)

func _kill(e: Dictionary, owner: int) -> void:
	players[owner].score += (int(e.kind) + 1) * 100
	_explode(float(e.x), float(e.y))
	enemies.erase(e)
	if bool(e.carrier) and pickups.size() < 3:
		pickups.append({"x": float(e.x), "y": float(e.y), "kind": rng.randi_range(0,4)})

func _explode(x: float, y: float) -> void:
	effects.append({"x": x, "y": y, "time": 0.25})

func _power(p: Dictionary, kind: int, owner: int) -> void:
	match kind:
		0: p.gun = mini(3, int(p.gun) + 1)
		1: p.shield = 8.0
		2: frozen = 6.0
		3:
			for e in enemies.duplicate():
				_kill(e, owner)
		4:
			fort = 10.0
			for cell in [231,232,233,247,249]:
				tiles[cell] = 1

func team_score() -> int:
	var total := 0
	for p in players:
		total += int(p.score)
	return total

func snapshot() -> Dictionary:
	return {"match_id": match_id, "status": status, "duo": duo, "wave": wave, "map_index": map_index,
		"tiles": tiles.duplicate(), "players": players.duplicate(true), "enemies": enemies.duplicate(true),
		"bullets": bullets.duplicate(true), "pickups": pickups.duplicate(true), "effects": effects.duplicate(true),
		"remaining": remaining, "base_hp": base_hp, "fort": fort, "frozen": frozen, "team_score": team_score()}


func enemy_limit() -> int:
	return 6 if duo else (2 if wave <= 5 else 3)

func spawn_interval() -> float:
	return maxf(0.65, 2.4 - mini(wave, 10) * 0.15) if duo else maxf(2.2, 3.6 - mini(wave - 1, 9) * 0.15)
