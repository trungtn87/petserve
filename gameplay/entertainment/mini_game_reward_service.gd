class_name MiniGameRewardService
extends RefCounted


const GAME_CARO_3X3: StringName = &"caro_3x3"
# Keep the legacy storage key so existing claims and chest IDs retain the shared cap.
const GAME_OBSTACLE_RUN: StringName = &"maze_hunt"
const GAME_SNAKE_HUNT: StringName = &"snake_hunt"

const MAX_INFANT_CARO_REWARDS: int = 4
const MAX_STAGE2_ACTIVITY_REWARDS: int = 4
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
	_ensure_run(
		run_id
	)


func snapshot(
	run_id: int
) -> Dictionary:
	_ensure_run(
		run_id
	)

	var state: Dictionary = _meta.get(
		META_KEY,
		{}
	)
	var caro: Dictionary = state.get(
		String(GAME_CARO_3X3),
		{}
	)
	var caro_claimed := clampi(
		int(
			caro.get(
				"claimed",
				0
			)
		),
		0,
		MAX_INFANT_CARO_REWARDS
	)
	var obstacle_claimed := _game_claimed(
		state,
		GAME_OBSTACLE_RUN
	)
	var snake_claimed := _game_claimed(
		state,
		GAME_SNAKE_HUNT
	)
	var stage2_claimed := mini(
		MAX_STAGE2_ACTIVITY_REWARDS,
		obstacle_claimed
		+ snake_claimed
	)

	return {
		"caro_rewards_claimed": caro_claimed,
		"caro_rewards_max": MAX_INFANT_CARO_REWARDS,
		"caro_rewards_remaining": (
			MAX_INFANT_CARO_REWARDS
			- caro_claimed
		),
		"obstacle_rewards_claimed": obstacle_claimed,
		"snake_rewards_claimed": snake_claimed,
		"stage2_activity_rewards_claimed": (
			stage2_claimed
		),
		"stage2_activity_rewards_max": (
			MAX_STAGE2_ACTIVITY_REWARDS
		),
		"stage2_activity_rewards_remaining": (
			MAX_STAGE2_ACTIVITY_REWARDS
			- stage2_claimed
		),
	}


func claim_caro_win(
	run_id: int
) -> Dictionary:
	_ensure_run(
		run_id
	)

	var state: Dictionary = _meta.get(
		META_KEY,
		{}
	)
	var caro: Dictionary = state.get(
		String(GAME_CARO_3X3),
		{}
	)
	var claimed := clampi(
		int(
			caro.get(
				"claimed",
				0
			)
		),
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
	caro["last_reward_at_unix"] = int(
		Time.get_unix_time_from_system()
	)
	state[String(GAME_CARO_3X3)] = caro
	_meta[META_KEY] = state

	return {
		"ok": true,
		"rewarded": true,
		"message": "Thắng Caro • nhận 1 Rương Ấu thể.",
		"claimed": reward_index,
		"max": MAX_INFANT_CARO_REWARDS,
	}


func claim_obstacle_run(
	run_id: int,
	score: int,
	match_id: String
) -> Dictionary:
	return _claim_stage2_activity(
		run_id,
		GAME_OBSTACLE_RUN,
		"Né vật rơi",
		score,
		obstacle_reward_tier(
			score
		),
		match_id
	)


func claim_snake_hunt(
	run_id: int,
	score: int,
	match_id: String
) -> Dictionary:
	return _claim_stage2_activity(
		run_id,
		GAME_SNAKE_HUNT,
		"Snake Hunt",
		score,
		snake_reward_tier(
			score
		),
		match_id
	)


func obstacle_reward_tier(
	score: int
) -> int:
	if score >= 3000:
		return 4
	if score >= 2000:
		return 3
	if score >= 1000:
		return 2
	return 1


func snake_reward_tier(
	score: int
) -> int:
	if score >= 1900:
		return 4
	if score >= 1400:
		return 3
	if score >= 1000:
		return 2
	return 1


func _claim_stage2_activity(
	run_id: int,
	game_id: StringName,
	game_label: String,
	score: int,
	tier: int,
	match_id: String
) -> Dictionary:
	_ensure_run(
		run_id
	)

	var normalized_match_id := match_id.strip_edges()

	if normalized_match_id.is_empty():
		return {
			"ok": false,
			"rewarded": false,
			"message": "Ván chơi không có mã hợp lệ.",
		}

	var state: Dictionary = _meta.get(
		META_KEY,
		{}
	)
	var total_claimed := _stage2_total_claimed(
		state
	)

	if total_claimed >= MAX_STAGE2_ACTIVITY_REWARDS:
		return {
			"ok": false,
			"rewarded": false,
			"message": (
				"Đã nhận đủ 4 Rương Hoạt động ở Stage 2."
			),
		}

	var game: Dictionary = state.get(
		String(game_id),
		{}
	)
	var game_claimed := maxi(
		0,
		int(
			game.get(
				"claimed",
				0
			)
		)
	)
	var ids_value: Variant = game.get(
		"claimed_match_ids",
		[]
	)
	var claimed_match_ids: Array = (
		(ids_value as Array).duplicate(true)
		if typeof(ids_value) == TYPE_ARRAY
		else []
	)

	if claimed_match_ids.has(
		normalized_match_id
	):
		return {
			"ok": false,
			"rewarded": false,
			"message": "Phần thưởng của ván này đã được nhận.",
		}

	var reward_index := total_claimed + 1

	if not _chests.ensure_stage_activity_chest(
		run_id,
		2,
		String(game_id),
		reward_index,
		clampi(
			tier,
			1,
			4
		)
	):
		return {
			"ok": false,
			"rewarded": false,
			"message": (
				"Không thể tạo Rương Hoạt động Stage 2."
			),
		}

	game["claimed"] = game_claimed + 1
	claimed_match_ids.append(
		normalized_match_id
	)
	game["claimed_match_ids"] = claimed_match_ids
	game["best_score"] = maxi(
		int(
			game.get(
				"best_score",
				0
			)
		),
		maxi(
			0,
			score
		)
	)
	game["last_reward_at_unix"] = int(
		Time.get_unix_time_from_system()
	)
	state[String(game_id)] = game
	_meta[META_KEY] = state

	return {
		"ok": true,
		"rewarded": true,
		"message": (
			"%s • nhận Rương Hoạt động Tier %d."
			% [
				game_label,
				clampi(
					tier,
					1,
					4
				),
			]
		),
		"claimed": reward_index,
		"max": MAX_STAGE2_ACTIVITY_REWARDS,
		"tier": clampi(
			tier,
			1,
			4
		),
		"score": maxi(
			0,
			score
		),
	}


func _stage2_total_claimed(
	state: Dictionary
) -> int:
	return mini(
		MAX_STAGE2_ACTIVITY_REWARDS,
		_game_claimed(
			state,
			GAME_OBSTACLE_RUN
		)
		+ _game_claimed(
			state,
			GAME_SNAKE_HUNT
		)
	)


func _game_claimed(
	state: Dictionary,
	game_id: StringName
) -> int:
	var game: Dictionary = state.get(
		String(game_id),
		{}
	)
	return maxi(
		0,
		int(
			game.get(
				"claimed",
				0
			)
		)
	)


func _ensure_run(
	run_id: int
) -> void:
	var state: Dictionary = _meta.get(
		META_KEY,
		{}
	)

	if int(
		state.get(
			"run_id",
			-1
		)
	) == run_id:
		var changed := false

		for game_id in [
			GAME_CARO_3X3,
			GAME_OBSTACLE_RUN,
			GAME_SNAKE_HUNT,
		]:
			if not state.has(
				String(game_id)
			):
				state[String(game_id)] = {
					"claimed": 0,
					"claimed_match_ids": [],
				}
				changed = true

		if changed:
			_meta[META_KEY] = state
		return

	var new_state: Dictionary = {
		"run_id": run_id,
	}

	for game_id in [
		GAME_CARO_3X3,
		GAME_OBSTACLE_RUN,
		GAME_SNAKE_HUNT,
	]:
		new_state[String(game_id)] = {
			"claimed": 0,
			"claimed_match_ids": [],
		}

	_meta[META_KEY] = new_state


# Only the currently saved, finished session is eligible. Its settled flag is
# committed in the same metadata save as the fragments/chests by the facade.
func claim_energy_2048(run_id: int, stage_index: int, match_id: String) -> Dictionary:
	var data: Dictionary = _meta.get("energy_2048", {})
	var session := Energy2048Session.new()
	if int(data.get("run_id", -1)) != run_id or not session.restore(data):
		return {"ok": false, "message": "Không tìm thấy ván 2048 hợp lệ."}
	if session.match_id != match_id or session.status == "playing" or session.settled:
		return {"ok": false, "message": "Ván chưa kết thúc hoặc đã nhận thưởng."}
	var amount := Energy2048Rules.fragments(Energy2048Rules.largest(session.board))
	var crafted := _chests.add_salvage_fragments(amount, run_id, stage_index)
	session.settled = true
	var stored := session.snapshot()
	stored["run_id"] = run_id
	_meta["energy_2048"] = stored
	return {"ok": true, "rewarded": amount > 0, "fragments": amount, "crafted": crafted,
		"message": ("Nhận %d mảnh rương." % amount if amount > 0 else "Chưa đạt ô 128. Thử lại nhé!")
			+ (" Đã ghép %d rương — mở trong Kho." % crafted if crafted > 0 else "")}
