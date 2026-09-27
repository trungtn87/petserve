class_name HatchState
extends RefCounted


const GAME_VERSION: String = "1.1"

const STATUS_WAITING_NAME: String = "waiting_name"
const STATUS_NAME_CONFIRMED: String = "name_confirmed"


var game_version: String = GAME_VERSION

var run_seed: int = 0

var status: String = STATUS_WAITING_NAME

var pet_name: String = ""
var name_confirmed: bool = false


func reset() -> void:
	game_version = GAME_VERSION

	run_seed = 0

	status = STATUS_WAITING_NAME

	pet_name = ""
	name_confirmed = false


func is_valid() -> bool:
	return run_seed > 0


func to_save_dict() -> Dictionary:
	return {
		"game_version": game_version,
		"run_seed": run_seed,
		"status": status,
		"pet_name": pet_name,
		"name_confirmed": name_confirmed
	}


static func from_save_dict(
	data: Dictionary
) -> HatchState:
	var state: HatchState = HatchState.new()

	state.game_version = str(
		data.get(
			"game_version",
			GAME_VERSION
		)
	)

	state.run_seed = int(
		data.get(
			"run_seed",
			0
		)
	)

	state.status = str(
		data.get(
			"status",
			STATUS_WAITING_NAME
		)
	)

	state.pet_name = str(
		data.get(
			"pet_name",
			""
		)
	)

	state.name_confirmed = bool(
		data.get(
			"name_confirmed",
			false
		)
	)

	return state
