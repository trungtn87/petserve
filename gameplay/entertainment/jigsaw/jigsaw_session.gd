class_name JigsawSession
extends RefCounted

const SAVE_PATH := "user://jigsaw_v2.json"
const COUNTS := [50, 100, 200]
const GRIDS := [Vector2i(5, 10), Vector2i(10, 10), Vector2i(10, 20)]

var level := 0
var image_path := ""
var seed_value := 1
var placed: Array[int] = []
var rotations: Array[int] = []
var horizontal: Array[int] = []
var vertical: Array[int] = []


func start(path: String, difficulty: int) -> void:
	image_path = path
	level = clampi(difficulty, 0, 2)
	seed_value = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	placed.clear()
	_build_edges()
	_build_rotations()


func grid() -> Vector2i:
	return GRIDS[level]


func count() -> int:
	return COUNTS[level]


func reward_chests() -> int:
	return level + 1


func complete() -> bool:
	return placed.size() == count()


func place(index: int) -> bool:
	if index < 0 or index >= count() or placed.has(index):
		return false
	placed.append(index)
	return true


func remaining() -> Array[int]:
	var result: Array[int] = []
	for index in count():
		if not placed.has(index):
			result.append(index)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item := result[i]
		result[i] = result[j]
		result[j] = item
	return result


func rotation_steps(index: int) -> int:
	if index < 0 or index >= rotations.size():
		return 0
	return posmod(rotations[index], 4)


func is_upright(index: int) -> bool:
	return rotation_steps(index) == 0


func rotate_piece(index: int) -> bool:
	if index < 0 or index >= count() or placed.has(index):
		return false
	while rotations.size() < count():
		rotations.append(0)
	rotations[index] = posmod(rotations[index] + 1, 4)
	return true


func snapshot() -> Dictionary:
	return {
		"version": 2,
		"level": level,
		"image_path": image_path,
		"seed": seed_value,
		"placed": placed.duplicate(),
		"rotations": rotations.duplicate(),
	}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 2:
		return false

	var difficulty := int(data.get("level", -1))
	var path := str(data.get("image_path", ""))
	var values: Variant = data.get("placed", null)
	var rotation_values: Variant = data.get("rotations", null)

	if (
		difficulty < 0
		or difficulty > 2
		or path.is_empty()
		or not values is Array
		or not rotation_values is Array
	):
		return false

	var checked: Array[int] = []
	for value in values:
		if not (value is int or value is float) or float(value) != float(int(value)):
			return false
		var index := int(value)
		if index < 0 or index >= COUNTS[difficulty] or checked.has(index):
			return false
		checked.append(index)

	if (rotation_values as Array).size() != COUNTS[difficulty]:
		return false

	var restored_rotations: Array[int] = []
	for value in rotation_values:
		if not (value is int or value is float) or float(value) != float(int(value)):
			return false
		restored_rotations.append(posmod(int(value), 4))

	level = difficulty
	image_path = path
	seed_value = int(data.get("seed", 1))
	placed = checked
	rotations = restored_rotations
	_build_edges()
	return true


func _build_rotations() -> void:
	rotations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5A17
	for _index in count():
		rotations.append(rng.randi_range(0, 3))


func _build_edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	horizontal.clear()
	vertical.clear()
	for _i in (grid().y - 1) * grid().x:
		horizontal.append(1 if rng.randi_range(0, 1) == 1 else -1)
	for _i in grid().y * (grid().x - 1):
		vertical.append(1 if rng.randi_range(0, 1) == 1 else -1)


func polygon(index: int) -> PackedVector2Array:
	var columns := grid().x
	var x := index % columns
	var y := index / columns
	var signs := [
		0 if y == 0 else -horizontal[(y - 1) * columns + x],
		0 if x == columns - 1 else vertical[y * (columns - 1) + x],
		0 if y == grid().y - 1 else horizontal[y * columns + x],
		0 if x == 0 else -vertical[y * (columns - 1) + x - 1],
	]
	var corners := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	var result := PackedVector2Array()
	var profile := [
		Vector2(0, 0), Vector2(.36, 0), Vector2(.41, .045),
		Vector2(.36, .10), Vector2(.36, .16), Vector2(.42, .21),
		Vector2(.50, .23), Vector2(.58, .21), Vector2(.64, .16),
		Vector2(.64, .10), Vector2(.59, .045), Vector2(.64, 0)
	]
	for side in 4:
		var origin: Vector2 = corners[side]
		var direction: Vector2 = corners[(side + 1) % 4] - origin
		var normal := Vector2(direction.y, -direction.x)
		if signs[side] == 0:
			result.append(origin)
		else:
			for point in profile:
				result.append(origin + direction * point.x + normal * point.y * signs[side])
	return result


func uv(index: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var cell := Vector2(index % grid().x, index / grid().x)
	for point in polygon(index):
		result.append((cell + point) / Vector2(grid()))
	return result
