class_name InitialSpeciesCatalog
extends RefCounted


const DEFAULT_PATH: String = (
	"res://data/evolution/visual/initial_species_profiles.json"
)


func load_default() -> Array[InitialSpeciesProfile]:
	return load_from_path(DEFAULT_PATH)


func load_from_path(
	path: String
) -> Array[InitialSpeciesProfile]:
	var result: Array[InitialSpeciesProfile] = []

	if not FileAccess.file_exists(path):
		return result

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return result

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_ARRAY:
		return result

	for value in parsed as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue

		var profile := InitialSpeciesProfile.from_dict(
			value as Dictionary
		)

		if profile != null:
			result.append(profile)

	return result


func find_by_species(
	profiles: Array[InitialSpeciesProfile],
	species: StringName
) -> InitialSpeciesProfile:
	for profile in profiles:
		if profile.species == species:
			return profile

	return null
