class_name SudokuRules
extends RefCounted

const CLUES := [44, 36, 28]
const REWARDS := [1, 2, 3]
const NAMES := ["Dễ", "Vừa", "Khó"]

static func candidates(board: Array, index: int) -> Array[int]:
	var result: Array[int] = []
	for value in range(1, 10):
		var valid := true
		for other in 81:
			if other != index and peers(index, other) and int(board[other]) == value:
				valid = false
				break
		if valid:
			result.append(value)
	return result

static func peers(a: int, b: int) -> bool:
	return a / 9 == b / 9 or a % 9 == b % 9 or (a / 27 == b / 27 and (a % 9) / 3 == (b % 9) / 3)

static func conflicts(board: Array, index: int) -> bool:
	if int(board[index]) == 0:
		return false
	for other in 81:
		if other != index and peers(index, other) and int(board[other]) == int(board[index]):
			return true
	return false

static func solutions(board: Array, limit: int = 2) -> int:
	var rows: Array = []
	var columns: Array = []
	var boxes: Array = []
	rows.resize(9)
	columns.resize(9)
	boxes.resize(9)
	rows.fill(0)
	columns.fill(0)
	boxes.fill(0)
	for index in 81:
		var value := int(board[index])
		if value == 0:
			continue
		var row := index / 9
		var column := index % 9
		var box := (row / 3) * 3 + column / 3
		var bit := 1 << (value - 1)
		if (int(rows[row]) | int(columns[column]) | int(boxes[box])) & bit:
			return 0
		rows[row] = int(rows[row]) | bit
		columns[column] = int(columns[column]) | bit
		boxes[box] = int(boxes[box]) | bit
	return _search(board, rows, columns, boxes, limit)

static func _search(board: Array, rows: Array, columns: Array, boxes: Array, limit: int) -> int:
	var best := -1
	var best_mask := 0
	var best_count := 10
	for index in 81:
		if int(board[index]) != 0:
			continue
		var mask := 511 & ~(int(rows[index / 9]) | int(columns[index % 9]) | int(boxes[(index / 27) * 3 + (index % 9) / 3]))
		if mask == 0:
			return 0
		var count := 0
		var bits := mask
		while bits:
			bits &= bits - 1
			count += 1
		if count < best_count:
			best = index
			best_mask = mask
			best_count = count
			if count == 1:
				break
	if best == -1:
		return 1
	var row := best / 9
	var column := best % 9
	var box := (row / 3) * 3 + column / 3
	var total := 0
	for number in 9:
		var bit := 1 << number
		if not (best_mask & bit):
			continue
		board[best] = number + 1
		rows[row] = int(rows[row]) | bit
		columns[column] = int(columns[column]) | bit
		boxes[box] = int(boxes[box]) | bit
		total += _search(board, rows, columns, boxes, limit - total)
		rows[row] = int(rows[row]) & ~bit
		columns[column] = int(columns[column]) & ~bit
		boxes[box] = int(boxes[box]) & ~bit
		if total >= limit:
			break
	board[best] = 0
	return total

static func generate(level: int, rng: RandomNumberGenerator) -> Dictionary:
	# Random digits, bands, stacks and rows/columns preserve a valid full grid.
	var digits := _shuffle(range(1, 10), rng)
	var rows := _order(rng)
	var columns := _order(rng)
	var answer: Array = []
	for row in rows:
		for column in columns:
			answer.append(digits[(int(row) * 3 + int(row) / 3 + int(column)) % 9])
	var puzzle := answer.duplicate()
	var remaining := 81
	for index in _shuffle(range(81), rng):
		if remaining <= CLUES[clampi(level, 0, 2)]:
			break
		var value: int = puzzle[index]
		puzzle[index] = 0
		if solutions(puzzle) == 1:
			remaining -= 1
		else:
			puzzle[index] = value
	return {"puzzle": puzzle, "answer": answer}

static func _order(rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	for band in _shuffle([0, 1, 2], rng):
		for row in _shuffle([0, 1, 2], rng):
			result.append(int(band) * 3 + int(row))
	return result

static func _shuffle(values: Array, rng: RandomNumberGenerator) -> Array:
	var result := values.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var value: Variant = result[index]
		result[index] = result[other]
		result[other] = value
	return result
