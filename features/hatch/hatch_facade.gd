class_name HatchFacade
extends RefCounted


const EVENT_NONE: String = "none"

const EVENT_WAITING_NAME: String = "waiting_name"

const EVENT_NAME_CONFIRMED: String = (
	"name_confirmed"
)

const EVENT_INVALID_NAME: String = (
	"invalid_name"
)

const EVENT_SAVE_FAILED: String = (
	"save_failed"
)

const EVENT_ALREADY_CONFIRMED: String = (
	"already_confirmed"
)


var _save_service: HatchSaveService
var _validator: PetNameValidator

var _state: HatchState = null

var _last_error: String = ""


func _init() -> void:
	_save_service = HatchSaveService.new()

	_validator = PetNameValidator.new()


# =========================================================
# PREPARE
# =========================================================

func prepare_for_run(
	run_seed: int
) -> String:
	if run_seed <= 0:
		return EVENT_NONE


	# Đúng run đang nằm trong RAM.
	if (
		_state != null
		and _state.run_seed == run_seed
	):
		if _state.name_confirmed:
			return EVENT_NAME_CONFIRMED

		return EVENT_WAITING_NAME


	# Thử khôi phục save.
	var saved_data: Dictionary = (
		_save_service.load_data()
	)


	if not saved_data.is_empty():
		var loaded: HatchState = (
			HatchState.from_save_dict(
				saved_data
			)
		)


		# Chỉ chấp nhận save thuộc đúng đời hiện tại.
		if loaded.run_seed == run_seed:
			_state = loaded


			if _state.name_confirmed:
				return EVENT_NAME_CONFIRMED


			return EVENT_WAITING_NAME


	# Không có save đúng đời.
	_state = HatchState.new()

	_state.run_seed = run_seed
	_state.status = (
		HatchState.STATUS_WAITING_NAME
	)

	_state.pet_name = ""
	_state.name_confirmed = false


	if not _save():
		return EVENT_SAVE_FAILED


	return EVENT_WAITING_NAME


# =========================================================
# NAME
# =========================================================

func submit_name(
	raw_name: String
) -> String:
	_last_error = ""


	if _state == null:
		_last_error = (
			"Hatch Flow chưa được khởi tạo."
		)

		return EVENT_INVALID_NAME


	if _state.name_confirmed:
		return EVENT_ALREADY_CONFIRMED


	var validation: Dictionary = (
		_validator.validate(
			raw_name
		)
	)


	if not bool(
		validation.get(
			"ok",
			false
		)
	):
		_last_error = str(
			validation.get(
				"error",
				"Tên không hợp lệ."
			)
		)

		return EVENT_INVALID_NAME


	var valid_name: String = str(
		validation.get(
			"name",
			""
		)
	)


	# Ghi state trước.
	_state.pet_name = valid_name

	_state.name_confirmed = true

	_state.status = (
		HatchState.STATUS_NAME_CONFIRMED
	)


	# SAVE PHẢI thành công trước khi
	# cho phép chuyển sang Hatch.
	if not _save():
		_state.pet_name = ""

		_state.name_confirmed = false

		_state.status = (
			HatchState.STATUS_WAITING_NAME
		)

		_last_error = (
			"Không lưu được tên. Hãy thử lại."
		)

		return EVENT_SAVE_FAILED


	return EVENT_NAME_CONFIRMED


# =========================================================
# QUERY
# =========================================================

func is_prepared() -> bool:
	return (
		_state != null
		and _state.is_valid()
	)


func is_name_confirmed() -> bool:
	if _state == null:
		return false

	return _state.name_confirmed


func get_pet_name() -> String:
	if _state == null:
		return ""

	return _state.pet_name


func get_run_seed() -> int:
	if _state == null:
		return 0

	return _state.run_seed


func get_last_error() -> String:
	return _last_error


func get_display_data() -> Dictionary:
	if _state == null:
		return {}


	return {
		"run_seed": _state.run_seed,
		"status": _state.status,
		"pet_name": _state.pet_name,
		"name_confirmed": (
			_state.name_confirmed
		)
	}


# =========================================================
# RESET
# =========================================================

func reset() -> bool:
	_state = null

	_last_error = ""

	return _save_service.delete_save()


# =========================================================
# SAVE
# =========================================================

func _save() -> bool:
	if _state == null:
		return false


	return _save_service.save_data(
		_state.to_save_dict()
	)
