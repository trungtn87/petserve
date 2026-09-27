class_name PetHomeScreen
extends Control


@onready var environment_layer: Control = $EnvironmentLayer
@onready var actor_layer: Control = $ActorLayer
@onready var pet_anchor: Marker2D = $ActorLayer/PetAnchor
@onready var ui_layer: CanvasLayer = $UILayer


func get_pet_anchor() -> Marker2D:
	return pet_anchor


func get_actor_layer() -> Control:
	return actor_layer


func get_environment_layer() -> Control:
	return environment_layer
