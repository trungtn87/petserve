class_name GameApp
extends RefCounted


var _egg: EggFacade
var _hatch: HatchFacade

var _main_screen: MainScreen

var _started: bool = false


func start(
	root: Control
) -> bool:
	if _started:
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
