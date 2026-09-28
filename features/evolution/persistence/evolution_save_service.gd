class_name EvolutionSaveService
extends RefCounted


const SAVE_PATH: String = (
	"user://evolution_pet_v1.json"
)


func save_initial(
	identity: PetIdentity,
	genome: PetGenome,
	visual: PetVisualRecord,
	pet_name: String
) -> bool:
	if (
		identity == null
		or genome == null
		or visual == null
		or not identity.is_valid()
		or not genome.is_valid()
		or not visual.is_valid()
	):
		return false

	var data := {
		"schema": 1,
		"pet_name": pet_name,
		"identity": identity.to_dict(),
		"genome": genome.to_dict(),
		"current_visual": visual.to_dict(),
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return false

	file.store_string(
		JSON.stringify(data)
	)
	file.close()

	return true


func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed as Dictionary
