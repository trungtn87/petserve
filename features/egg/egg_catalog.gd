class_name EggCatalog
extends RefCounted


const TYPES: Array[String] = [
	"metal",
	"wood",
	"water",
	"fire",
	"earth",
	"dark",
	"light"
]


const NAMES: Dictionary = {
	"metal": "KIM",
	"wood": "MỘC",
	"water": "THỦY",
	"fire": "HỎA",
	"earth": "THỔ",
	"dark": "ÁM",
	"light": "QUANG"
}


static func is_valid(
	egg_type: String
) -> bool:
	return TYPES.has(
		egg_type
	)


static func name_for(
	egg_type: String
) -> String:
	return str(
		NAMES.get(
			egg_type,
			"KHÔNG XÁC ĐỊNH"
		)
	)
