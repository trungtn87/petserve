class_name TankMaps
extends RefCounted

const WIDTH := 16
const HEIGHT := 16
const SYMBOLS := {".": 0, "B": 1, "S": 2, "W": 3, "G": 4, "H": 5}

static func all_maps() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://gameplay/entertainment/tank/tank_maps.json"))

static func cells(index: int) -> Array:
	var map: Dictionary = all_maps()[index]
	var result: Array = []
	for row in map.rows:
		for symbol in str(row):
			result.append(SYMBOLS[symbol])
	return result
