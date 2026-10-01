class_name Energy2048Session
extends RefCounted

var board: Array = []
var score := 0
var match_id := ""
var status := "playing"
var settled := false
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func start() -> void:
	board.resize(16)
	board.fill(0)
	score = 0
	status = "playing"
	settled = false
	match_id = "2048_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_spawn()
	_spawn()

func restore(data: Dictionary) -> bool:
	var saved: Variant = data.get("board", [])
	if not saved is Array or saved.size() != 16 or str(data.get("match_id", "")).is_empty():
		return false
	board = []
	for raw in saved:
		var tile := int(raw)
		if tile < 0 or tile > 2048 or (tile != 0 and (tile < 2 or (tile & (tile - 1)) != 0)):
			return false
		board.append(tile)
	score = maxi(0, int(data.get("score", 0)))
	match_id = str(data.match_id)
	status = str(data.get("status", "playing"))
	if status not in ["playing", "won", "lost", "ended"]:
		return false
	settled = bool(data.get("settled", false))
	# Strings avoid precision loss when the metadata is round-tripped through JSON.
	_rng.state = int(str(data.get("rng_state", _rng.state)))
	return true

func snapshot() -> Dictionary:
	return {"board": board.duplicate(), "score": score, "match_id": match_id,
		"status": status, "settled": settled, "rng_state": str(_rng.state)}

func move(direction: Vector2i) -> Dictionary:
	if status != "playing" or settled:
		return {"changed": false}
	var result := Energy2048Rules.slide(board, direction)
	if not result.changed:
		return result
	board = result.board
	score += int(result.gained)
	_spawn()
	if Energy2048Rules.largest(board) >= Energy2048Rules.TARGET:
		status = "won"
	elif not Energy2048Rules.can_move(board):
		status = "lost"
	return result

func finish() -> void:
	if status == "playing":
		status = "ended"

func _spawn() -> void:
	var empty: Array[int] = []
	for index in 16:
		if int(board[index]) == 0:
			empty.append(index)
	if not empty.is_empty():
		board[empty[_rng.randi_range(0, empty.size() - 1)]] = 2 if _rng.randf() < 0.9 else 4
