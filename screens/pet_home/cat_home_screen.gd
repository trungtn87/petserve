class_name CatHomeScreen
extends Control
signal action_requested(action_id: StringName)
@export var home_definition: HomeDefinition = preload("res://data/home/cat_room.tres")
@export var pet_definition: PetDefinition = preload("res://data/pet/cat/dark/pet.tres")
@onready var pet_anchor: Marker2D = $ActorLayer/PetAnchor
@onready var menu: PetHomeMenu = $UILayer/MenuOverlay
var _home := HomeHost.new()
var _host := PetActorHost.new()
var _state := PetState.new()
var _behavior := PetBehaviorController.new()

func _ready() -> void:
	if not _home.apply(home_definition, $EnvironmentSlot, pet_anchor):
		push_error("CatHomeScreen: invalid home definition.")
		return
	_layout_actor()
	resized.connect(_layout_actor)
	var actor: PetActor = _host.spawn(pet_definition, pet_anchor)
	if actor != null:
		actor.tapped.connect(_on_tapped)
		actor.present_state(_state)
	menu.action_requested.connect(_on_action)

func _process(delta: float) -> void:
	var actor: PetActor = get_pet_actor()
	if actor == null:
		return
	if actor is CatPet2D and actor.action != &"idle":
		return
	var next: StringName = _behavior.tick(delta)
	if not next.is_empty():
		_state.set_primary(next)
		actor.present_state(_state)

func get_pet_actor() -> PetActor:
	return _host.get_actor()

func _layout_actor() -> void:
	if home_definition != null:
		pet_anchor.position = home_definition.pet_anchor * size / Vector2(360, 640)

func _on_tapped() -> void:
	_behavior.reset()
	_state.set_primary(_behavior.react_to_tap())
	get_pet_actor().present_state(_state)

func _on_action(action_id: StringName) -> void:
	action_requested.emit(action_id)
	var actor := get_pet_actor() as CatPet2D
	if actor == null:
		return
	if action_id == &"food":
		actor.play_action(&"eat")
	elif action_id in [&"lie", &"sleep", &"wake"]:
		actor.play_action(action_id)
	_behavior.reset()
