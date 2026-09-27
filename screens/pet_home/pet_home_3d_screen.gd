class_name PetHome3DScreen
extends Control


const DEFAULT_HOME: HomeDefinition3D = preload("res://data/home/default_room_3d.tres")
const REFERENCE_PET: PetDefinition = preload("res://data/pet/dark_pet_rigged.tres")


@onready var viewport: SubViewport = $ViewportContainer/SubViewport
@onready var environment_slot: Node3D = $ViewportContainer/SubViewport/WorldRoot/EnvironmentSlot
@onready var pet_anchor: Node3D = $ViewportContainer/SubViewport/WorldRoot/PetAnchor
@onready var camera: Camera3D = $ViewportContainer/SubViewport/WorldRoot/Camera3D
@onready var ui_layer: CanvasLayer = $UILayer


var _home_host: HomeHost3D = HomeHost3D.new()
var _pet_actor_host: PetActor3DHost = PetActor3DHost.new()
var _pet_state: PetState = PetState.new()
var _behavior: PetBehaviorController = PetBehaviorController.new()


func _ready() -> void:
	if not apply_home(DEFAULT_HOME):
		push_error("PetHome3DScreen: default home could not be applied.")
		return

	var actor: PetActor3D = spawn_pet(REFERENCE_PET)
	if actor == null:
		push_error("PetHome3DScreen: reference pet could not be spawned.")
		return

	actor.tapped.connect(_on_pet_tapped)
	actor.present_state(_pet_state)


func _process(delta: float) -> void:
	var next_state: StringName = _behavior.tick(delta)
	if not next_state.is_empty():
		_present_state(next_state)

	_update_pet_look_target()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_react_to_touch()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_react_to_touch()


func apply_home(definition: HomeDefinition3D) -> bool:
	return _home_host.apply(
		definition,
		environment_slot,
		pet_anchor,
		camera
	)


func spawn_pet(definition: PetDefinition) -> PetActor3D:
	return _pet_actor_host.spawn(definition, pet_anchor)


func clear_pet() -> void:
	_pet_actor_host.clear()


func clear_home() -> void:
	_home_host.clear()


func get_pet_actor() -> PetActor3D:
	return _pet_actor_host.get_actor()


func _update_pet_look_target() -> void:
	var actor: PetActor3D = get_pet_actor()
	if actor == null or not actor.has_capability(&"look_target"):
		return

	var pointer: Vector2 = viewport.get_mouse_position()
	var origin: Vector3 = camera.project_ray_origin(pointer)
	var direction: Vector3 = camera.project_ray_normal(pointer)
	var target = Plane(Vector3.FORWARD, 0.0).intersects_ray(origin, direction)

	if target != null:
		actor.set_look_target(target)


func _react_to_touch() -> void:
	var actor: PetActor3D = get_pet_actor()
	if actor == null or not actor.has_capability(&"tap_reaction"):
		return

	actor.react_to_touch()


func _on_pet_tapped() -> void:
	_present_state(_behavior.react_to_tap())


func _present_state(state_id: StringName) -> void:
	_pet_state.set_primary(state_id)

	var actor: PetActor3D = get_pet_actor()
	if actor != null:
		actor.present_state(_pet_state)
