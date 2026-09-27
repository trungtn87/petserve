class_name EggHatchController
extends RefCounted


signal hatch_completed


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
	if not _is_hatching:
		return


	if _next_phase_entered:
		return


	_next_phase_entered = true

	_enter_next_phase()


# =========================================================
# NEXT PHASE
# =========================================================

func _enter_next_phase() -> void:
	# =====================================================
	# TEMPORARY — V1.1
	#
	# Hiện tại:
	# Egg nở -> tạo đời Egg mới.
	#
	# Sau này khi có Pet:
	# Chỉ thay nội dung hàm này bằng luồng tạo Pet /
	# chuyển sang Pet gameplay.
	# =====================================================


	# Xóa HatchState của đời vừa kết thúc.
	if not _hatch.reset():
		push_error(
			"EggHatchController: Không reset được Hatch save."
		)


	# Tạm thời bắt đầu đời Egg mới.
	_egg.start_new_life()


# =========================================================
# EFFECT COMPLETE
# =========================================================

func _on_hatch_effect_finished() -> void:
	if not _is_hatching:
		return


	_is_hatching = false
	_next_phase_entered = false


	hatch_completed.emit()


# =========================================================
# QUERY
# =========================================================

func is_hatching() -> bool:
	return _is_hatching
