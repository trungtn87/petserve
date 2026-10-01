class_name EvolutionSaveService
extends RefCounted


const PetSceneProfileScript = preload(
	"res://features/evolution/domain/pet_scene_profile.gd"
)
const PetSceneProfileFactoryScript = preload(
	"res://features/evolution/domain/pet_scene_profile_factory.gd"
)


const SAVE_PATH: String = (
	"user://evolution_pet_v1.json"
)

const CURRENT_SCHEMA: int = 2


func save_initial(
	identity: PetIdentity,
	genome: PetGenome,
	visual: PetVisualRecord,
	pet_name: String,
	scene_profile = null,
	mythic_destiny: Dictionary = {}
) -> bool:
	if scene_profile == null and identity != null:
		scene_profile = (
			PetSceneProfileFactoryScript.new()
			.create_initial(identity)
		)

	if (
		not mythic_destiny.is_empty()
		and not SpeciesMythicDestinyService.new()
			.validate_for_identity(
				mythic_destiny,
				identity
			)
	):
		return false

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

	if not mythic_destiny.is_empty():
		data["mythic_destiny"] = (
			mythic_destiny.duplicate(
				true
			)
		)

	return save_data(data)


func save_data(data: Dictionary) -> bool:
	return AtomicJson.write(SAVE_PATH, data)


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


func delete_data() -> bool:
	if not FileAccess.file_exists(
		SAVE_PATH
	):
		return true

	return (
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				SAVE_PATH
			)
		) == OK
	)


func load_scene_profile():
	var data := load_data()

	if data.is_empty():
		return null

	var value: Variant = data.get(
		"scene_profile",
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return null

	return PetSceneProfileScript.from_dict(
		value as Dictionary
	)
