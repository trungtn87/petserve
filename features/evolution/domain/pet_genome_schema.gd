class_name PetGenomeSchema
extends RefCounted


const BASE_TRAIT: StringName = &"base"

const LOCKED_RENDER_FIELDS: Array[StringName] = [
	&"species",
	&"primary_element",
	&"life_stage",
	&"face_identity",
]

const VISUAL_LOCI: Array[StringName] = [
	&"body",
	&"eyes",
	&"ears",
	&"whiskers",
	&"fur",
	&"coat",
	&"tail",
	&"paws",
	&"mane",
	&"mark",
	&"structure",
	&"aura",
	&"horns",
	&"wings",
	&"hooves",
	&"antlers",
]


static func render_field_count() -> int:
	return (
		LOCKED_RENDER_FIELDS.size()
		+ VISUAL_LOCI.size()
	)


static func visual_loci() -> Array[StringName]:
	var result: Array[StringName] = []

	for locus in VISUAL_LOCI:
		result.append(locus)

	return result


static func is_visual_locus(
	locus: StringName
) -> bool:
	return VISUAL_LOCI.has(locus)


static func base_traits() -> Dictionary:
	var result: Dictionary = {}

	for locus in VISUAL_LOCI:
		result[locus] = BASE_TRAIT

	return result


static func complete_visual_traits(
	source: Dictionary
) -> Dictionary:
	var result := base_traits()

	for key_value in source.keys():
		var locus := StringName(
			str(key_value)
			.strip_edges()
			.to_lower()
		)

		if not is_visual_locus(locus):
			continue

		var value := StringName(
			str(source[key_value])
			.strip_edges()
			.to_lower()
		)

		if String(value).is_empty():
			continue

		result[locus] = value

	return result
