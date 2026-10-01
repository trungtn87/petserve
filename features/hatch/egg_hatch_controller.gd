class_name EggHatchController
extends RefCounted


signal hatch_completed
signal next_phase_requested


var _egg: EggFacade
var _hatch: HatchFacade
var _egg_view: Control

var _is_hatching: bool = false
var _next_phase_entered: bool = false


func _init(
	egg_facade: EggFacade,
	hatch_facade: HatchFacade,
	egg_view: Control
) -> void:
	_egg = egg_facade
	_hatch = hatch_facade
	_egg_view = egg_view


# =========================================================
# SETUP
# =========================================================

func setup() -> bool:
	if _egg_view == null:
		push_error(
			"EggHatchController: EggView không tồn tại."
		)
		return false

	return true


# =========================================================
# INPUT
# =========================================================

func try_hatch() -> bool:
	if _is_hatching:
		return true

	if not _egg.is_ready_to_hatch():
		return false

	if not _hatch.is_name_confirmed():
		return false

	_is_hatching = true
	_next_phase_entered = false

	# Không chạy hatch flash/whiteout nữa.
	# Bấm nở sẽ chuyển ngay sang EvolutionTransitionScreen.
	_hide_egg_presentation()
	hatch_completed.emit()

	if not _next_phase_entered:
		_next_phase_entered = true
		_enter_next_phase()

	return true


# =========================================================
# NEXT PHASE
# =========================================================

func _enter_next_phase() -> void:
	next_phase_requested.emit()


func _hide_egg_presentation() -> void:
	if _egg_view == null or not is_instance_valid(_egg_view):
		return

	if _egg_view.has_method("clear_egg"):
		_egg_view.call("clear_egg")

	_egg_view.visible = false
	_egg_view.mouse_filter = Control.MOUSE_FILTER_IGNORE


# =========================================================
# QUERY
# =========================================================

func is_hatching() -> bool:
	return _is_hatching
