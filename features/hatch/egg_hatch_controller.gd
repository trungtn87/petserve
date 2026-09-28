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


	if not _egg_view.has_signal(
		"hatch_effect_finished"
	):
		push_error(
			"EggHatchController: EggView thiếu signal hatch_effect_finished."
		)
		return false


	if not _egg_view.has_signal(
		"hatch_whiteout"
	):
		push_error(
			"EggHatchController: EggView thiếu signal hatch_whiteout."
		)
		return false


	if not _egg_view.has_method(
		"play_hatch_effect"
	):
		push_error(
			"EggHatchController: EggView thiếu play_hatch_effect()."
		)
		return false


	if not _egg_view.hatch_whiteout.is_connected(
		_on_hatch_whiteout
	):
		_egg_view.hatch_whiteout.connect(
			_on_hatch_whiteout
		)


	if not _egg_view.hatch_effect_finished.is_connected(
		_on_hatch_effect_finished
	):
		_egg_view.hatch_effect_finished.connect(
			_on_hatch_effect_finished
		)


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


	_egg_view.call(
		"play_hatch_effect"
	)


	return true


# =========================================================
# WHITEOUT
# =========================================================

func _on_hatch_whiteout() -> void:
	# Whiteout vẫn thuộc hiệu ứng của EggView.
	# Không đổi scene ở đây vì EggView còn tiếp tục await/tween.
	return


# =========================================================
# NEXT PHASE
# =========================================================

func _enter_next_phase() -> void:
	# Không tạo Egg mới ở đây nữa.
	# App layer sẽ nhận signal và chuyển sang phase gameplay kế tiếp.
	next_phase_requested.emit()


# =========================================================
# EFFECT COMPLETE
# =========================================================

func _on_hatch_effect_finished() -> void:
	if not _is_hatching:
		return


	_is_hatching = false

	_hide_egg_presentation()

	hatch_completed.emit()


	# Chỉ chuyển gameplay sau khi EggView đã hoàn tất toàn bộ
	# timer/tween của hiệu ứng nở và không còn coroutine dang dở.
	if not _next_phase_entered:
		_next_phase_entered = true
		_enter_next_phase()


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
