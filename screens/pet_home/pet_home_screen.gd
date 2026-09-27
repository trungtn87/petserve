class_name PetHomeScreen
extends Control


@onready var environment_slot: Control = $EnvironmentSlot
@onready var decoration_layer: Control = $DecorationLayer
@onready var actor_layer: Control = $ActorLayer
@onready var pet_anchor: Marker2D = $ActorLayer/PetAnchor
@onready var effect_layer: Control = $EffectLayer
@onready var ui_layer: CanvasLayer = $UILayer


var _home_host: HomeHost = HomeHost.new()


func apply_home(definition: HomeDefinition) -> bool:
	return _home_host.apply(
		definition,
		environment_slot,
		pet_anchor
	)


func clear_home() -> void:
	_home_host.clear()


func get_pet_anchor() -> Marker2D:
	return pet_anchor


func get_actor_layer() -> Control:
	return actor_layer


func get_environment_slot() -> Control:
	return environment_slot
