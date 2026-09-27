class_name PetDefinition
extends Resource


@export var id: StringName = &""
@export var display_name: String = ""
@export var actor_scene: PackedScene
@export var capability_ids: Array[StringName] = []
@export var appearance_profile: PetAppearanceProfile
@export var presentation_profile: Resource


func is_valid() -> bool:
	return not id.is_empty() and actor_scene != null


func has_capability(capability_id: StringName) -> bool:
	return capability_ids.has(capability_id)
