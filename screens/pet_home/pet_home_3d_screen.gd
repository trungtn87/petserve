class_name PetHome3DScreen
extends Control


signal action_requested(action_id: StringName)


const DEFAULT_HOME: HomeDefinition3D = preload("res://data/home/default_room_3d.tres")
const REFERENCE_PET: PetDefinition = preload("res://data/pet/dark_pet_3d.tres")


@onready var background: TextureRect = $Background
@onready var viewport: SubViewport = $ViewportContainer/SubViewport
@onready var environment_slot: Node3D = $ViewportContainer/SubViewport/WorldRoot/EnvironmentSlot
@onready var pet_anchor: Node3D = $ViewportContainer/SubViewport/WorldRoot/PetAnchor
@onready var camera: Camera3D = $ViewportContainer/SubViewport/WorldRoot/Camera3D
@onready var ui_layer: CanvasLayer = $UILayer
@onready var gameplay_ui: PetHomeGameplayUI = $UILayer/GameplayUI
@onready var home_menu: PetHomeMenu = $UILayer/MenuOverlay
@onready var entertainment_ui: EntertainmentHubUI = $UILayer/EntertainmentUI


var _home_host: HomeHost3D = HomeHost3D.new()
var _pet_actor_host: PetActor3DHost = PetActor3DHost.new()
var _pet_state: PetState = PetState.new()
var _behavior: PetBehaviorController = PetBehaviorController.new()

var _infant_game: InfantGameFacade = InfantGameFacade.new()
var _hud_accumulator: float = 0.0


func _ready() -> void:
	if home_menu != null and not home_menu.action_requested.is_connected(
		_on_menu_action_requested
	):
		home_menu.action_requested.connect(
			_on_menu_action_requested
		)

	if gameplay_ui != null:
		gameplay_ui.chest_open_requested.connect(
			_on_chest_open_requested
		)
		gameplay_ui.item_use_requested.connect(
			_on_item_use_requested
		)
		gameplay_ui.entertainment_requested.connect(
			_on_entertainment_requested
		)

	if entertainment_ui != null:
		entertainment_ui.caro_win_reward_requested.connect(
			_on_caro_win_reward_requested
		)
		entertainment_ui.match_finished.connect(
			_on_caro_match_finished
		)

	var run_snapshot := RunManager.get_snapshot()
	var run_id := int(run_snapshot.get("run_id", 0))

	if run_id <= 0:
		var meta := SaveManager.load_meta()
		var infant_state: Dictionary = meta.get("infant_state", {})
		run_id = int(infant_state.get("run_id", 0))

	if run_id <= 0:
		run_id = int(Time.get_unix_time_from_system())

	if not _infant_game.setup(run_id):
		push_error("PetHome3DScreen: infant gameplay save setup failed.")

	if gameplay_ui != null:
		gameplay_ui.bind(_infant_game)
		gameplay_ui.set_pet_identity(
			REFERENCE_PET.display_name
		)

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

	_infant_game.tick(delta)

	_hud_accumulator += delta

	if _hud_accumulator >= 0.5:
		_hud_accumulator = 0.0

		if gameplay_ui != null:
			gameplay_ui.refresh_status(
				_infant_game.snapshot()
			)

	_update_pet_look_target()


func _exit_tree() -> void:
	_infant_game.save()


func _unhandled_input(event: InputEvent) -> void:
	if entertainment_ui != null and entertainment_ui.is_open():
		return

	if home_menu != null and home_menu.is_open():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_react_to_touch()

	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch

		if touch_event.pressed:
			_react_to_touch()


func apply_home(definition: HomeDefinition3D) -> bool:
	if definition == null:
		return false

	background.texture = definition.background_texture

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


func _on_chest_open_requested() -> void:
	var rewards := _infant_game.open_next_chest()

	if rewards.is_empty():
		gameplay_ui.show_message("Không có rương để mở.")
		return

	gameplay_ui.show_chest_rewards(rewards)


func _on_item_use_requested(uid: String) -> void:
	var result := _infant_game.use_item(uid)
	gameplay_ui.show_message(
		String(result.get("message", ""))
	)
	gameplay_ui.refresh_status(
		_infant_game.snapshot()
	)

	if bool(result.get("ok", false)):
		gameplay_ui.open_inventory()


func _on_entertainment_requested() -> void:
	if entertainment_ui == null:
		return

	var state := _infant_game.snapshot()

	entertainment_ui.open_hub(
		int(state.get("caro_rewards_claimed", 0)),
		int(state.get("caro_rewards_max", 4)),
		not bool(state.get("ready_to_evolve", false))
	)


func _on_caro_win_reward_requested() -> void:
	var result := _infant_game.claim_caro_win_reward()
	var state := _infant_game.snapshot()

	entertainment_ui.set_reward_status(
		int(state.get("caro_rewards_claimed", 0)),
		int(state.get("caro_rewards_max", 4)),
		not bool(state.get("ready_to_evolve", false))
	)
	entertainment_ui.show_reward_message(
		String(result.get("message", ""))
	)

	gameplay_ui.refresh_status(state)


func _on_caro_match_finished(result: StringName) -> void:
	match result:
		TicTacToeGame.RESULT_PLAYER:
			_present_state(&"surprised")
		TicTacToeGame.RESULT_PET:
			_present_state(&"happy")
		TicTacToeGame.RESULT_DRAW:
			_present_state(&"curious")


func _on_menu_action_requested(action_id: StringName) -> void:
	match action_id:
		&"food":
			gameplay_ui.open_inventory(
				ItemGenerator.TYPE_FOOD
			)
		&"items":
			gameplay_ui.open_inventory()
		_:
			action_requested.emit(action_id)
			print("PetHome3D action requested: ", action_id)
