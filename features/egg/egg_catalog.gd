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


const NAME_KEYS: Dictionary = {
	"metal": "EGG_ELEMENT_METAL",
	"wood": "EGG_ELEMENT_WOOD",
	"water": "EGG_ELEMENT_WATER",
	"fire": "EGG_ELEMENT_FIRE",
	"earth": "EGG_ELEMENT_EARTH",
	"dark": "EGG_ELEMENT_DARK",
	"light": "EGG_ELEMENT_LIGHT"
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
	var key := String(NAME_KEYS.get(egg_type, "EGG_ELEMENT_UNKNOWN"))
	return LocalizationManager.text(key, "UNKNOWN")
