class_name EvolutionSaveService
extends RefCounted


const SAVE_PATH: String = (
	"user://evolution_pet_v1.json"
)

const CURRENT_SCHEMA: int = 2


func save_initial(
	identity: PetIdentity,
	genome: PetGenome,
	visual: PetVisualRecord,
	pet_name: String,
	scene_profile: PetSceneProfile = null
) -> bool:
	if scene_profile == null and identity != null:
		scene_profile = (
			PetSceneProfileFactory.new()
			.create_initial(identity)
		)

	if (
		identity == null
		or genome == null
		or visual == null
		or scene_profile == null
		or not identity.is_valid()
		or not genome.is_valid()
		or not visual.is_valid()
		or not scene_profile.is_valid()
		or scene_profile.element != identity.element()
	):
		return false

	var data := {
		"schema": CURRENT_SCHEMA,
		"pet_name": pet_name,
		"identity": identity.to_dict(),
		"genome": genome.to_dict(),
		"scene_profile": scene_profile.to_dict(),
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


func load_scene_profile() -> PetSceneProfile:
	var data := load_data()

	if data.is_empty():
		return null

	var value: Variant = data.get(
		"scene_profile",
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return null

	return PetSceneProfile.from_dict(
		value as Dictionary
	)
