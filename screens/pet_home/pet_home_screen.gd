class_name PetHomeScreen
extends Control


const DEFAULT_HOME: HomeDefinition = preload("res://data/home/default_room.tres")
const REFERENCE_PET: PetDefinition = preload("res://data/pet/dark_pet.tres")


@onready var environment_slot: Control = $EnvironmentSlot
@onready var decoration_layer: Control = $DecorationLayer
@onready var actor_layer: Control = $ActorLayer
@onready var pet_anchor: Marker2D = $ActorLayer/PetAnchor
@onready var effect_layer: Control = $EffectLayer
@onready var ui_layer: CanvasLayer = $UILayer


var _home_host: HomeHost = HomeHost.new()
var _pet_actor_host: PetActorHost = PetActorHost.new()
var _pet_state: PetState = PetState.new()
var _behavior: PetBehaviorController = PetBehaviorController.new()


func _ready() -> void:
	apply_home(DEFAULT_HOME)
	var actor: PetActor = spawn_pet(REFERENCE_PET)
	if actor != null:
		actor.tapped.connect(_on_pet_tapped)
		actor.present_state(_pet_state)


func _process(delta: float) -> void:
	var next_state: StringName = _behavior.tick(delta)
	if not next_state.is_empty():
		_present_state(next_state)


func apply_home(definition: HomeDefinition) -> bool:
	return _home_host.apply(definition, environment_slot, pet_anchor)


func spawn_pet(definition: PetDefinition) -> PetActor:
	return _pet_actor_host.spawn(definition, pet_anchor)


func clear_pet() -> void:
	_pet_actor_host.clear()


func clear_home() -> void:
	_home_host.clear()


func get_pet_actor() -> PetActor:
	return _pet_actor_host.get_actor()


func get_pet_anchor() -> Marker2D:
	return pet_anchor


func get_actor_layer() -> Control:
	return actor_layer


func get_environment_slot() -> Control:
	return environment_slot


func _on_pet_tapped() -> void:
	_present_state(_behavior.react_to_tap())


func _present_state(state_id: StringName) -> void:
	_pet_state.set_primary(state_id)
	var actor: PetActor = get_pet_actor()
	if actor != null:
		actor.present_state(_pet_state)
