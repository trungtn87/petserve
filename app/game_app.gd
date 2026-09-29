class_name GameApp
extends RefCounted


const NEXT_PHASE_SCENE: PackedScene = preload(
	"res://scenes/evolution_transition.tscn"
)
const PETHOME_SCENE: PackedScene = preload(
	"res://scenes/pet/pet_home.tscn"
)


var _root: Control

var _egg: EggFacade
var _hatch: HatchFacade

var _main_screen: MainScreen

var _started: bool = false


func start(
	root: Control
) -> bool:
	if _started:
		return true

	_root = root

	var visual_state := _current_pet_visual_state()

	if visual_state == &"current":
		_started = true
		call_deferred(
			"_resume_pet_home"
		)
		return true

	if visual_state == &"stale":
		_started = true
		call_deferred(
			"_resume_render_transition"
		)
		return true


	# =====================================================
	# FEATURES
	# =====================================================

	_egg = EggFacade.new()

	_hatch = HatchFacade.new()


	# =====================================================
	# UI
	# =====================================================

	_main_screen = MainScreen.new(
		root,
		_egg,
		_hatch
	)


	if not _main_screen.setup():
		push_error(
			"GameApp: MainScreen setup thất bại."
		)

		return false

	if not _main_screen.next_phase_requested.is_connected(
		_enter_next_phase
	):
		_main_screen.next_phase_requested.connect(
			_enter_next_phase
		)


	# =====================================================
	# LOAD EGG
	# =====================================================

	var load_event: String = _egg.load()

	if load_event == EggFacade.EVENT_NONE:
		_egg.start_new_life()
	# =====================================================
	# FIRST DRAW
	# =====================================================

	_main_screen.refresh()


	_started = true

	return true


func tick(
	delta: float
) -> void:
	if not _started:
		return


	if _main_screen == null:
		return


	_main_screen.tick(
		delta
	)


func shutdown() -> void:
	if not _started:
		return


	if _egg != null:
		if _egg.has_active_life():
			_egg.save()


	_started = false


func get_egg() -> EggFacade:
	return _egg


func get_hatch() -> HatchFacade:
	return _hatch


func _current_pet_visual_state() -> StringName:
	var data := EvolutionSaveService.new().load_data()

	if data.is_empty():
		return &"none"

	var visual_value: Variant = data.get(
		"current_visual",
		{}
	)

	if typeof(visual_value) != TYPE_DICTIONARY:
		return &"none"

	var visual := PetVisualRecord.from_dict(
		visual_value as Dictionary
	)

	if (
		visual == null
		or not FileAccess.file_exists(
			visual.image_path
		)
	):
		return &"none"

	if (
		visual.source_mode in [
			&"initial_pethome_v5_text_to_image",
			&"initial_pethome_v6_text_to_image",
			&"initial_pethome_v7_text_to_image",
			&"evolution_pethome_v5_image_edit",
			&"evolution_pethome_v7_full_regenerate",
			&"evolution_pethome_v7_image_edit",
			&"evolution_pethome_v8_full_regenerate",
			&"evolution_pethome_v8_image_edit",
		]
	):
		return &"current"

	return &"stale"


func _resume_pet_home() -> void:
	if _root == null:
		return

	var tree := _root.get_tree()

	if tree == null:
		return

	var error := tree.change_scene_to_packed(
		PETHOME_SCENE
	)

	if error != OK:
		push_error(
			"GameApp: Không chuyển được sang PetHome."
		)


func _resume_render_transition() -> void:
	if _root == null:
		return

	var tree := _root.get_tree()

	if tree == null:
		return

	var error := tree.change_scene_to_packed(
		NEXT_PHASE_SCENE
	)

	if error != OK:
		push_error(
			"GameApp: Không chuyển được sang render transition."
		)


func _enter_next_phase() -> void:
	if _root == null:
		push_error(
			"GameApp: Root không tồn tại khi vào EvolutionTransition."
		)
		return

	var tree: SceneTree = _root.get_tree()

	if tree == null:
		push_error(
			"GameApp: SceneTree không tồn tại."
		)
		return

	var error: Error = tree.change_scene_to_packed(
		NEXT_PHASE_SCENE
	)

	if error != OK:
		push_error(
			"GameApp: Không chuyển được sang EvolutionTransition."
		)
