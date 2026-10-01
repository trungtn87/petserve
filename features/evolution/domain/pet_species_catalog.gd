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


const SPECIES_WEIGHTS: Dictionary = {
	&"cat": 12,
	&"dog": 12,
	&"fox": 10,
	&"bear": 8,
	&"rabbit": 10,
	&"lizard": 8,
	&"bird": 8,
	&"dragon": 5,
	&"phoenix": 5,
	&"horse": 8,
	&"qilin": 4,
	&"deer": 7,
}


static func all() -> Array[StringName]:
	return SPECIES.duplicate()


static func is_supported(species: StringName) -> bool:
	return SPECIES.has(_normalize(species))


static func pick_for_seed(seed: int) -> StringName:
	if seed <= 0 or SPECIES.is_empty():
		return &"cat"

	var total_weight := 0
	for species in SPECIES:
		total_weight += int(
			SPECIES_WEIGHTS.get(
				species,
				1
			)
		)

	if total_weight <= 0:
		return &"cat"

	var roll := posmod(
		seed * 1103515245 + 12345,
		total_weight
	)
	var cursor := 0

	for species in SPECIES:
		cursor += int(
			SPECIES_WEIGHTS.get(
				species,
				1
			)
		)
		if roll < cursor:
			return species

	return SPECIES.back()


static func _normalize(value: StringName) -> StringName:
	return StringName(
		String(value)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)
