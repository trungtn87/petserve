class_name BreakoutMaps
extends RefCounted

const COUNT := 30
const WIDTH := 300.0
const HEIGHT := 420.0
const NAMES := ["Khởi đầu", "Cầu thang", "Kim cương", "Hai cánh", "Đường hầm", "Làn sóng"]

static func build(level: int) -> Dictionary:
	level = clampi(level, 1, COUNT)
	var rows := 3 + (level - 1) / 6
	var pattern := (level - 1) % 6
	var bricks: Array = []
	for row in rows:
		for column in 6:
			var include := true
			match pattern:
				1: include = column <= row + 2 or column == 5
				2: include = absi(column * 2 - 5) <= 3 + (row % 3) * 2
				3: include = column != 2 and column != 3 or row % 2 == 0
				4: include = row % 3 != 1 or column == 0 or column == 5
				5: include = (row + column) % 4 != 0
			if not include:
				continue
			var hp := 1
			if level >= 7 and (row + column + level) % 3 == 0:
				hp = 2
			if level >= 19 and (row * 3 + column + level) % 4 == 0:
				hp = 3
			var steel := level >= 13 and row == rows - 1 and column in [1, 4]
			bricks.append({"x": 7.0 + column * 48.0, "y": 34.0 + row * 23.0, "w": 46.0, "h": 20.0, "hp": -1 if steel else hp, "max_hp": hp})
	return {"level": level, "name": NAMES[pattern], "bricks": bricks,
		"speed": 175.0 + (level - 1) * 4.0, "paddle_width": 82.0 - (level - 1) * 0.8}
