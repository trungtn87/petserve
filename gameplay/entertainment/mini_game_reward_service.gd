class_name MiniGameRewardService
extends RefCounted


const GAME_CARO_3X3: StringName = &"caro_3x3"
const MAX_INFANT_CARO_REWARDS: int = 4
const META_KEY: String = "mini_game_rewards"


var _meta: Dictionary = {}
var _chests: ChestService


func setup(
	meta: Dictionary,
	chests: ChestService,
	run_id: int
) -> void:
	_meta = meta
	_chests = chests
	_ensure_run(run_id)


func snapshot(run_id: int) -> Dictionary:
	_ensure_run(run_id)

	var state: Dictionary = _meta.get(META_KEY, {})
	var caro: Dictionary = state.get(String(GAME_CARO_3X3), {})
	var claimed := clampi(
		int(caro.get("claimed", 0)),
		0,
		MAX_INFANT_CARO_REWARDS
	)

	return {
		"caro_rewards_claimed": claimed,
		"caro_rewards_max": MAX_INFANT_CARO_REWARDS,
		"caro_rewards_remaining": MAX_INFANT_CARO_REWARDS - claimed,
	}


func claim_caro_win(run_id: int) -> Dictionary:
	_ensure_run(run_id)

	var state: Dictionary = _meta.get(META_KEY, {})
	var caro: Dictionary = state.get(String(GAME_CARO_3X3), {})
	var claimed := clampi(
		int(caro.get("claimed", 0)),
		0,
		MAX_INFANT_CARO_REWARDS
	)

	if claimed >= MAX_INFANT_CARO_REWARDS:
		return {
			"ok": false,
			"rewarded": false,
			"message": LocalizationManager.text(
				"CARO_REWARD_LIMIT",
				"All 4 Infant Chests from Tic-Tac-Toe have been claimed."
			),
		}

	var reward_index := claimed + 1

	if not _chests.ensure_infant_activity_chest(
		run_id,
		String(GAME_CARO_3X3),
		reward_index
	):
		return {
			"ok": false,
			"rewarded": false,
			"message": LocalizationManager.text(
				"CARO_REWARD_CREATE_ERROR",
				"Could not create an Infant Chest."
			),
		}

	caro["claimed"] = reward_index
	caro["last_reward_at_unix"] = int(Time.get_unix_time_from_system())
	state[String(GAME_CARO_3X3)] = caro
	_meta[META_KEY] = state

	return {
		"ok": true,
		"rewarded": true,
		"message": LocalizationManager.text(
			"CARO_REWARD_GAINED",
			"Tic-Tac-Toe win • received 1 Infant Chest."
		),
		"claimed": reward_index,
		"max": MAX_INFANT_CARO_REWARDS,
	}


func _ensure_run(run_id: int) -> void:
	var state: Dictionary = _meta.get(META_KEY, {})

	if int(state.get("run_id", -1)) == run_id:
		if not state.has(String(GAME_CARO_3X3)):
			state[String(GAME_CARO_3X3)] = {"claimed": 0}
			_meta[META_KEY] = state
		return

	var new_state: Dictionary = {
		"run_id": run_id,
	}
	new_state[String(GAME_CARO_3X3)] = {
		"claimed": 0,
	}
	_meta[META_KEY] = new_state
