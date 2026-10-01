class_name Energy2048Rules
extends RefCounted

const SIZE := 4
const TARGET := 2048
const MILESTONES := [128, 256, 512, 1024, 2048]
const REWARDS := [1, 2, 3, 5, 10]

# Pure move: spawning belongs to the session, so invalid swipes consume no RNG.
static func slide(board: Array, direction: Vector2i) -> Dictionary:
	var next := board.duplicate()
	var gained := 0
	var motions: Array[Dictionary] = []
	var merged: Array[int] = []
	if direction not in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		return {"board": next, "changed": false, "gained": 0, "motions": [], "merged": []}
	for line in SIZE:
		var indices: Array[int] = []
		for step in SIZE:
			var index := line * SIZE + step
			if direction == Vector2i.RIGHT:
				index = line * SIZE + SIZE - 1 - step
			elif direction == Vector2i.UP:
				index = step * SIZE + line
			elif direction == Vector2i.DOWN:
				index = (SIZE - 1 - step) * SIZE + line
			if int(board[index]) > 0:
				indices.append(index)
			# Clear this whole line before writing the packed result.
			next[index] = 0
		var source := 0
		var output := 0
		while source < indices.size():
			var from := indices[source]
			var value := int(board[from])
			var target := line * SIZE + output
			if direction == Vector2i.RIGHT:
				target = line * SIZE + SIZE - 1 - output
			elif direction == Vector2i.UP:
				target = output * SIZE + line
			elif direction == Vector2i.DOWN:
				target = (SIZE - 1 - output) * SIZE + line
			motions.append({"from": from, "to": target, "value": value})
			if source + 1 < indices.size() and int(board[indices[source + 1]]) == value:
				motions.append({"from": indices[source + 1], "to": target, "value": value})
				value *= 2
				gained += value
				merged.append(target)
				source += 1
			next[target] = value
			source += 1
			output += 1
	return {"board": next, "changed": next != board, "gained": gained, "motions": motions, "merged": merged}

static func can_move(board: Array) -> bool:
	for index in SIZE * SIZE:
		if int(board[index]) == 0:
			return true
		if index % SIZE < SIZE - 1 and board[index] == board[index + 1]:
			return true
		if index < SIZE * (SIZE - 1) and board[index] == board[index + SIZE]:
			return true
	return false

static func largest(board: Array) -> int:
	var value := 0
	for tile in board:
		value = maxi(value, int(tile))
	return value

static func fragments(tile: int) -> int:
	for index in range(MILESTONES.size() - 1, -1, -1):
		if tile >= MILESTONES[index]:
			return REWARDS[index]
	return 0
