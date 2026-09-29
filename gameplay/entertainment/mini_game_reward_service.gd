class_name MiniGameRewardService
extends RefCounted


const GAME_CARO_3X3: StringName = &"caro_3x3"
const GAME_MAZE_HUNT: StringName = &"maze_hunt"
const MAX_INFANT_CARO_REWARDS: int = 4
const MAX_STAGE2_MAZE_REWARDS: int = 4
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
	var maze: Dictionary = state.get(String(GAME_MAZE_HUNT), {})
	var maze_claimed := clampi(
		int(maze.get("claimed", 0)),
		0,
		MAX_STAGE2_MAZE_REWARDS
	)

	return {
		"caro_rewards_claimed": claimed,
		"caro_rewards_max": MAX_INFANT_CARO_REWARDS,
		"caro_rewards_remaining": MAX_INFANT_CARO_REWARDS - claimed,
		"maze_rewards_claimed": maze_claimed,
		"maze_rewards_max": MAX_STAGE2_MAZE_REWARDS,
		"maze_rewards_remaining": MAX_STAGE2_MAZE_REWARDS - maze_claimed,
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
			"message": "Đã nhận đủ 4 Rương Ấu thể từ Caro.",
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
			"message": "Không thể tạo Rương Ấu thể.",
		}

	caro["claimed"] = reward_index
	caro["last_reward_at_unix"] = int(Time.get_unix_time_from_system())
	state[String(GAME_CARO_3X3)] = caro
	_meta[META_KEY] = state

	return {
		"ok": true,
		"rewarded": true,
		"message": "Thắng Caro • nhận 1 Rương Ấu thể.",
		"claimed": reward_index,
		"max": MAX_INFANT_CARO_REWARDS,
	}


func claim_maze_hunt(
	run_id: int,
	score: int
) -> Dictionary:
	_ensure_run(run_id)

	var state: Dictionary = _meta.get(META_KEY, {})
	var maze: Dictionary = state.get(String(GAME_MAZE_HUNT), {})
	var claimed := clampi(
		int(maze.get("claimed", 0)),
		0,
		MAX_STAGE2_MAZE_REWARDS
	)

	if claimed >= MAX_STAGE2_MAZE_REWARDS:
		return {
			"ok": false,
			"rewarded": false,
			"message": "Đã nhận đủ 4 Rương Maze Hunt ở Stage 2.",
		}

	var reward_index := claimed + 1
	var tier := maze_reward_tier(
		score
	)

	if not _chests.ensure_stage_activity_chest(
		run_id,
		2,
		String(GAME_MAZE_HUNT),
		reward_index,
		tier
	):
		return {
			"ok": false,
			"rewarded": false,
			"message": "Không thể tạo Rương Maze Hunt.",
		}

	maze["claimed"] = reward_index
	maze["best_score"] = maxi(
		int(
			maze.get(
				"best_score",
				0
			)
		),
		score
	)
	maze["last_reward_at_unix"] = int(
		Time.get_unix_time_from_system()
	)
	state[String(GAME_MAZE_HUNT)] = maze
	_meta[META_KEY] = state

	return {
		"ok": true,
		"rewarded": true,
		"message": (
			"Maze Hunt • nhận Rương Hoạt động Tier %d."
			% tier
		),
		"claimed": reward_index,
		"max": MAX_STAGE2_MAZE_REWARDS,
		"tier": tier,
		"score": score,
	}


func maze_reward_tier(
	score: int
) -> int:
	if score >= 3000:
		return 4
	if score >= 2000:
		return 3
	if score >= 1000:
		return 2
	return 1


func _ensure_run(run_id: int) -> void:
	var state: Dictionary = _meta.get(META_KEY, {})

	if int(state.get("run_id", -1)) == run_id:
		var changed := false
		if not state.has(String(GAME_CARO_3X3)):
			state[String(GAME_CARO_3X3)] = {"claimed": 0}
			changed = true
		if not state.has(String(GAME_MAZE_HUNT)):
			state[String(GAME_MAZE_HUNT)] = {"claimed": 0}
			changed = true
		if changed:
			_meta[META_KEY] = state
		return

	var new_state: Dictionary = {
		"run_id": run_id,
	}
	new_state[String(GAME_CARO_3X3)] = {
		"claimed": 0,
	}
	new_state[String(GAME_MAZE_HUNT)] = {
		"claimed": 0,
	}
	_meta[META_KEY] = new_state
