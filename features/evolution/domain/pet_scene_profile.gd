class_name PetSceneProfile
extends RefCounted


const SCHEMA_VERSION: int = 1


var element: StringName = &""
var environment_theme: String = ""
var environment_variant: int = 0
var palette_id: StringName = &""
var palette_description: String = ""
var lighting_theme: String = ""
var motif_id: StringName = &""
var motif_description: String = ""
var scene_seed: int = 0


func is_valid() -> bool:
	return (
		not String(element).is_empty()
		and not environment_theme.is_empty()
		and environment_variant >= 0
		and not String(palette_id).is_empty()
		and not palette_description.is_empty()
		and not lighting_theme.is_empty()
		and not String(motif_id).is_empty()
		and not motif_description.is_empty()
		and scene_seed > 0
	)


func same_profile(
	other
) -> bool:
	if other == null:
		return false

	return (
		element == other.element
		and environment_theme == other.environment_theme
		and environment_variant == other.environment_variant
		and palette_id == other.palette_id
		and palette_description == other.palette_description
		and lighting_theme == other.lighting_theme
		and motif_id == other.motif_id
		and motif_description == other.motif_description
		and scene_seed == other.scene_seed
	)


func to_dict() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"element": String(element),
		"environment_theme": environment_theme,
		"environment_variant": environment_variant,
		"palette_id": String(palette_id),
		"palette_description": palette_description,
		"lighting_theme": lighting_theme,
		"motif_id": String(motif_id),
		"motif_description": motif_description,
		"scene_seed": scene_seed,
	}


static func from_dict(
	data: Dictionary
):
	var profile := PetSceneProfile.new()

	profile.element = StringName(
		str(data.get("element", ""))
	)
	profile.environment_theme = str(
		data.get("environment_theme", "")
	)
	profile.environment_variant = int(
		data.get("environment_variant", 0)
	)
	profile.palette_id = StringName(
		str(data.get("palette_id", ""))
	)
	profile.palette_description = str(
		data.get("palette_description", "")
	)
	profile.lighting_theme = str(
		data.get("lighting_theme", "")
	)
	profile.motif_id = StringName(
		str(data.get("motif_id", ""))
	)
	profile.motif_description = str(
		data.get("motif_description", "")
	)
	profile.scene_seed = int(
		data.get("scene_seed", 0)
	)

	if not profile.is_valid():
		return null

	return profile
