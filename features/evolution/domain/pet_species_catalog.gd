class_name PetSpeciesCatalog
extends RefCounted


const SPECIES: Array[StringName] = [
	&"cat",
	&"dog",
	&"fox",
	&"bear",
	&"rabbit",
	&"lizard",
	&"bird",
	&"dragon",
	&"phoenix",
	&"horse",
	&"qilin",
	&"deer",
]


static func all() -> Array[StringName]:
	return SPECIES.duplicate()


static func is_supported(species: StringName) -> bool:
	return SPECIES.has(_normalize(species))


static func pick_for_seed(seed: int) -> StringName:
	if seed <= 0 or SPECIES.is_empty():
		return &"cat"

	var index := posmod(seed * 1103515245 + 12345, SPECIES.size())
	return SPECIES[index]


static func _normalize(value: StringName) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)
