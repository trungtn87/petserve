class_name BallSortGame
extends RefCounted


const CAPACITY := 4
const MAX_COLORS := 10
const RESULT_PLAYING: StringName = &"playing"
const RESULT_WON: StringName = &"won"

var _rng := RandomNumberGenerator.new()
var _level := 1
var _config: Dictionary = {}
var _tubes: Array = []
var _initial_tubes: Array = []
var _selected := -1
var _moves := 0
var _history: Array[Dictionary] = []
var _generated_solution: Array[Dictionary] = []
var _result: StringName = RESULT_PLAYING
var _difficulty_score := 0


func start_level(level: int) -> void:
	_level = maxi(1, level)
	_config = config_for_level(_level)

	var chosen_tubes: Array = []
	var chosen_solution: Array[Dictionary] = []
	var chosen_score := -1
	var attempts := 6 if _level <= 10 else 10
	var prefer_harder := _level > 10

	for attempt in range(attempts):
		var generated := _generate_candidate(attempt)
		var candidate: Array = generated.get("tubes", [])
		if candidate.is_empty() or _is_solved_board(candidate):
			continue

		var score := _score_board(candidate)
		var should_take := chosen_tubes.is_empty()
		if not should_take:
			should_take = score > chosen_score if prefer_harder else score < chosen_score

		if should_take:
			chosen_tubes = candidate.duplicate(true)
			chosen_solution = (generated.get("solution", []) as Array).duplicate(true)
			chosen_score = score

	if chosen_tubes.is_empty():
		var fallback := _generate_candidate(99)
		chosen_tubes = (fallback.get("tubes", []) as Array).duplicate(true)
		chosen_solution = (fallback.get("solution", []) as Array).duplicate(true)
		chosen_score = _score_board(chosen_tubes)

	_tubes = chosen_tubes
	_initial_tubes = _tubes.duplicate(true)
	_generated_solution = chosen_solution
	_difficulty_score = maxi(1, chosen_score)
	_selected = -1
	_moves = 0
	_history.clear()
	_result = RESULT_PLAYING


static func config_for_level(level: int) -> Dictionary:
	var safe_level := maxi(1, level)
	var color_count := 3
	var empty_tubes := 2
	var scramble_steps := 10

	if safe_level <= 5:
		color_count = 3
		scramble_steps = 8 + safe_level * 2
	elif safe_level <= 10:
		color_count = 4
		scramble_steps = 18 + (safe_level - 6) * 2
	elif safe_level <= 30:
		color_count = 5
		scramble_steps = 28 + (safe_level - 11)
	elif safe_level <= 60:
		color_count = 6
		scramble_steps = 45 + (safe_level - 31)
	elif safe_level <= 100:
		color_count = 7
		empty_tubes = 1
		scramble_steps = 66 + (safe_level - 61)
	else:
		color_count = mini(
			MAX_COLORS,
			8 + int((safe_level - 101) / 40)
		)
		empty_tubes = 1
		scramble_steps = mini(
			160,
			90 + int(float(safe_level - 101) * 0.60)
		)

	var rank := "NORMAL"
	if safe_level % 30 == 0:
		rank = "EXPERT"
		scramble_steps += 20
	elif safe_level % 10 == 0:
		rank = "HARD"
		scramble_steps += 10

	return {
		"level": safe_level,
		"color_count": color_count,
		"empty_tubes": empty_tubes,
		"tube_count": color_count + empty_tubes,
		"scramble_steps": scramble_steps,
		"rank": rank,
	}


func level() -> int:
	return _level


func config() -> Dictionary:
	return _config.duplicate(true)


func tubes() -> Array:
	return _tubes.duplicate(true)


func selected_index() -> int:
	return _selected


func moves() -> int:
	return _moves


func result() -> StringName:
	return _result


func difficulty_score() -> int:
	return _difficulty_score


func can_undo() -> bool:
	return not _history.is_empty() and _result == RESULT_PLAYING


func restart() -> void:
	_tubes = _initial_tubes.duplicate(true)
	_selected = -1
	_moves = 0
	_history.clear()
	_result = RESULT_PLAYING


func tap_tube(index: int) -> Dictionary:
	if index < 0 or index >= _tubes.size():
		return {"ok": false, "message": "Ống không hợp lệ."}

	if _result == RESULT_WON:
		return {"ok": false, "message": "Màn này đã hoàn thành."}

	var tube: Array = _tubes[index]

	if _selected < 0:
		if tube.is_empty():
			return {"ok": false, "message": "Ống này đang trống."}
		_selected = index
		return {
			"ok": true,
			"selected": true,
			"message": "Đã chọn ống %d. Chọn ống đích." % (index + 1),
		}

	if _selected == index:
		_selected = -1
		return {"ok": true, "message": "Đã bỏ chọn."}

	var source := _selected
	return move_ball(source, index)


func can_move(source: int, destination: int) -> bool:
	if _result == RESULT_WON:
		return false
	return _can_move(source, destination)


func move_ball(source: int, destination: int) -> Dictionary:
	if source < 0 or source >= _tubes.size():
		return {"ok": false, "message": "Ống nguồn không hợp lệ."}
	if destination < 0 or destination >= _tubes.size():
		return {"ok": false, "message": "Hãy thả tinh thể vào một ống đích."}
	if _result == RESULT_WON:
		return {"ok": false, "message": "Màn này đã hoàn thành."}
	if source == destination:
		return {"ok": false, "message": "Hãy kéo tinh thể sang một ống khác."}
	if not _can_move(source, destination):
		return {
			"ok": false,
			"message": "Chỉ thả được lên màu giống nhau hoặc ống trống.",
		}

	var ball: int = int((_tubes[source] as Array).pop_back())
	(_tubes[destination] as Array).append(ball)
	_history.append({"from": source, "to": destination, "ball": ball})
	_moves += 1
	_selected = -1

	if is_solved():
		_result = RESULT_WON
		return {
			"ok": true,
			"moved": true,
			"complete": true,
			"message": "Hoàn thành!",
		}

	return {
		"ok": true,
		"moved": true,
		"message": "Đã di chuyển.",
	}


func undo() -> Dictionary:
	if not can_undo():
		return {"ok": false, "message": "Không còn bước để hoàn tác."}

	var move: Dictionary = _history.pop_back()
	var source := int(move.get("from", -1))
	var destination := int(move.get("to", -1))

	if (
		source < 0
		or destination < 0
		or source >= _tubes.size()
		or destination >= _tubes.size()
		or (_tubes[destination] as Array).is_empty()
	):
		return {"ok": false, "message": "Không thể hoàn tác bước này."}

	var ball := int((_tubes[destination] as Array).pop_back())
	(_tubes[source] as Array).append(ball)
	_moves = maxi(0, _moves - 1)
	_selected = -1
	_result = RESULT_PLAYING
	return {"ok": true, "message": "Đã hoàn tác."}


func hint() -> Dictionary:
	if _result == RESULT_WON:
		return {"ok": false, "message": "Màn đã hoàn thành."}

	var fallback: Dictionary = {}

	for source in range(_tubes.size()):
		var source_tube: Array = _tubes[source]
		if source_tube.is_empty() or _is_complete_tube(source_tube):
			continue

		var ball := int(source_tube.back())
		for destination in range(_tubes.size()):
			if source == destination:
				continue
			var destination_tube: Array = _tubes[destination]
			if destination_tube.size() >= CAPACITY:
				continue
			if not destination_tube.is_empty() and int(destination_tube.back()) == ball:
				return {
					"ok": true,
					"from": source,
					"to": destination,
					"message": "Gợi ý: ống %d → ống %d." % [source + 1, destination + 1],
				}
			if destination_tube.is_empty() and fallback.is_empty():
				fallback = {
					"ok": true,
					"from": source,
					"to": destination,
					"message": "Gợi ý: thử ống %d → ống %d." % [source + 1, destination + 1],
				}

	if not fallback.is_empty():
		return fallback
	return {"ok": false, "message": "Không tìm thấy nước đi hữu ích."}


func is_solved() -> bool:
	return _is_solved_board(_tubes)


func debug_generated_solution() -> Array[Dictionary]:
	return _generated_solution.duplicate(true)


func _can_move(source: int, destination: int) -> bool:
	if source == destination:
		return false

	var source_tube: Array = _tubes[source]
	var destination_tube: Array = _tubes[destination]

	if source_tube.is_empty() or destination_tube.size() >= CAPACITY:
		return false
	if destination_tube.is_empty():
		return true

	return int(source_tube.back()) == int(destination_tube.back())


func _generate_candidate(attempt: int) -> Dictionary:
	var colors := int(_config.get("color_count", 3))
	var empty_count := int(_config.get("empty_tubes", 2))
	var board: Array = []

	for color_index in range(colors):
		var tube: Array = []
		for _slot in range(CAPACITY):
			tube.append(color_index)
		board.append(tube)

	for _empty in range(empty_count):
		board.append([])

	_rng.seed = int(_level) * 1000003 + attempt * 7919 + 918273
	var reverse_moves: Array[Dictionary] = []
	var last_from := -1
	var last_to := -1
	var steps := int(_config.get("scramble_steps", 20))

	for _step_index in range(steps):
		var preferred: Array[Vector2i] = []
		var fallback: Array[Vector2i] = []

		for source in range(board.size()):
			var source_tube: Array = board[source]
			if source_tube.is_empty():
				continue

			var ball := int(source_tube.back())
			var reversible := (
				source_tube.size() == 1
				or int(source_tube[source_tube.size() - 2]) == ball
			)
			if not reversible:
				continue

			for destination in range(board.size()):
				if source == destination:
					continue
				if source == last_to and destination == last_from:
					continue

				var destination_tube: Array = board[destination]
				if destination_tube.size() >= CAPACITY:
					continue

				var pair := Vector2i(source, destination)
				fallback.append(pair)
				if (
					not destination_tube.is_empty()
					and int(destination_tube.back()) != ball
				):
					preferred.append(pair)

		var pool: Array[Vector2i] = (
			preferred
			if not preferred.is_empty() and _rng.randf() < 0.86
			else fallback
		)
		if pool.is_empty():
			break

		var chosen := pool[_rng.randi_range(0, pool.size() - 1)]
		var moved_ball := int((board[chosen.x] as Array).pop_back())
		(board[chosen.y] as Array).append(moved_ball)
		reverse_moves.append({"from": chosen.y, "to": chosen.x})
		last_from = chosen.x
		last_to = chosen.y

	var solution: Array[Dictionary] = []
	for index in range(reverse_moves.size() - 1, -1, -1):
		solution.append(reverse_moves[index].duplicate(true))

	return {
		"tubes": board,
		"solution": solution,
	}


func _score_board(board: Array) -> int:
	var segments := 0
	var mixed_tubes := 0
	var occupied_by_color: Dictionary = {}

	for tube_index in range(board.size()):
		var tube: Array = board[tube_index]
		if tube.is_empty():
			continue

		var changes := 0
		for index in range(1, tube.size()):
			if int(tube[index]) != int(tube[index - 1]):
				changes += 1
		segments += changes
		if changes > 0:
			mixed_tubes += 1

		var seen: Dictionary = {}
		for raw_ball in tube:
			var ball := int(raw_ball)
			seen[ball] = true
		for ball_key in seen.keys():
			var count := int(occupied_by_color.get(ball_key, 0))
			occupied_by_color[ball_key] = count + 1

	var split_score := 0
	for location_count in occupied_by_color.values():
		split_score += maxi(0, int(location_count) - 1)

	var score := (
		segments * 5
		+ mixed_tubes * 4
		+ split_score * 3
		+ int(_config.get("color_count", 3)) * 6
	)
	if int(_config.get("empty_tubes", 2)) == 1:
		score += 18

	match String(_config.get("rank", "NORMAL")):
		"HARD":
			score += 12
		"EXPERT":
			score += 24

	return score


func _is_solved_board(board: Array) -> bool:
	for tube_value in board:
		var tube: Array = tube_value
		if tube.is_empty():
			continue
		if not _is_complete_tube(tube):
			return false
	return true


func _is_complete_tube(tube: Array) -> bool:
	if tube.size() != CAPACITY:
		return false

	var color := int(tube[0])
	for ball in tube:
		if int(ball) != color:
			return false
	return true
