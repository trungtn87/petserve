class_name HomeDefinition
extends Resource


@export var id: StringName = &""
@export var environment_scene: PackedScene
@export var pet_anchor: Vector2 = Vector2(180.0, 410.0)
@export var ambient_audio: AudioStream


func is_valid() -> bool:
	return not id.is_empty() and environment_scene != null
