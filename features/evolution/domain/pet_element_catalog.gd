class_name PetElementCatalog
extends RefCounted


const IDS: Array[StringName] = [
	&"metal",
	&"wood",
	&"water",
	&"fire",
	&"earth",
	&"dark",
	&"light",
]

const DISPLAY_NAMES := {
	"metal": "Kim",
	"wood": "Mộc",
	"water": "Thủy",
	"fire": "Hỏa",
	"earth": "Thổ",
	"dark": "Ám",
	"light": "Quang",
}

const PROMPT_NAMES := {
	"metal": "Metal (Kim)",
	"wood": "Wood (Mộc)",
	"water": "Water (Thủy)",
	"fire": "Fire (Hỏa)",
	"earth": "Earth (Thổ)",
	"dark": "Umbral shadow (Ám)",
	"light": "Radiant light (Quang)",
}


static func display_name(
	element: StringName
) -> String:
	var key := String(
		element
	).strip_edges().to_lower()

	return String(
		DISPLAY_NAMES.get(
			key,
			key
		)
	)


static func display_name_upper(
	element: StringName
) -> String:
	return display_name(
		element
	).to_upper()


static func prompt_name(
	element: StringName
) -> String:
	var key := String(
		element
	).strip_edges().to_lower()

	return String(
		PROMPT_NAMES.get(
			key,
			key
		)
	)


static func is_valid(
	element: StringName
) -> bool:
	return IDS.has(
		StringName(
			String(element)
				.strip_edges()
				.to_lower()
		)
	)
