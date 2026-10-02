class_name MiniGameRewardService
extends RefCounted

const GAME_CARO_3X3: StringName = &"caro_3x3"
const GAME_OBSTACLE_RUN: StringName = &"maze_hunt"
const MAX_INFANT_CARO_REWARDS := 1
const MAX_STAGE2_ACTIVITY_REWARDS := 1
const MAX_DAILY_FRAGMENTS := 10
const META_KEY := "daily_game_rewards_v2"
var _meta: Dictionary = {}
var _chests: ChestService

func setup(meta: Dictionary, chests: ChestService, _run_id: int) -> void:
	_meta = meta
	_chests = chests

func _day() -> String:
	return Time.get_date_string_from_system()

func _game_state(game_id: String) -> Dictionary:
	var state: Dictionary = _meta.get(META_KEY, {})
	var game: Dictionary = state.get(game_id, {})
	# Do not reset quotas when the device clock moves backwards.
	if _day() > str(game.get("day", "")):
		return {"day": _day(), "chest": false, "fragments": 0, "ids": []}
	return game.duplicate(true)

func claim_game(run_id: int, stage: int, game_id: String, match_id: String) -> Dictionary:
	if match_id.strip_edges().is_empty():
		return {"ok": false, "rewarded": false, "message": "Ván chơi không hợp lệ."}
	var game := _game_state(game_id)
	var ids: Array = game.get("ids", [])
	if ids.has(match_id):
		return {"ok": false, "rewarded": false, "message": "Ván này đã nhận thưởng."}
	var result := {"ok": true, "rewarded": true, "chests": 0, "fragments": 0, "crafted": 0, "bonus_chests": 0}
	if not bool(game.get("chest", false)):
		_chests.ensure_game_daily_chest(game_id, str(game.day), stage)
		game["chest"] = true
		result["chests"] = 1
		result["reward_type"] = "chest"
		result["message"] = "Nhận 1 rương hôm nay • Các chế độ dùng chung phần thưởng."
	elif int(game.get("fragments", 0)) < MAX_DAILY_FRAGMENTS:
		game["fragments"] = int(game.get("fragments", 0)) + 1
		result["fragments"] = 1
		result["crafted"] = _chests.add_salvage_fragments(1, run_id, stage)
		result["reward_type"] = "fragment"
		result["message"] = "Nhận 1 mảnh rương • %d/10 mảnh hôm nay." % int(game.fragments)
	else:
		result["rewarded"] = false
		result["message"] = "Game này đã nhận 1 rương và 10 mảnh hôm nay."
	# Store only rewarded match IDs; capped matches cannot produce rewards anyway.
	if bool(result.rewarded):
		ids.append(match_id)
	game["ids"] = ids
	var state: Dictionary = _meta.get(META_KEY, {})
	state[game_id] = game
	_meta[META_KEY] = state
	result["claimed"] = 1
	result["max"] = 1
	return result

func snapshot(_run_id: int) -> Dictionary:
	var caro := int(bool(_game_state("caro_3x3").get("chest", false)))
	var obstacle := int(bool(_game_state("maze_hunt").get("chest", false)))
	return {"caro_rewards_claimed": caro, "caro_rewards_max": 1, "caro_rewards_remaining": 1-caro,
		"obstacle_rewards_claimed": obstacle,
		"stage2_activity_rewards_claimed": obstacle, "stage2_activity_rewards_max": 1,
		"stage2_activity_rewards_remaining": 1-obstacle, "daily_game_rewards": _meta.get(META_KEY, {}).duplicate(true)}

func claim_caro_win(run_id: int, stage_index: int = 1, _enabled: bool = true, match_id: String = "") -> Dictionary:
	return claim_game(run_id, stage_index, "caro_3x3", match_id)

func claim_obstacle_run(run_id: int, _score: int, match_id: String, stage_index: int = 2) -> Dictionary:
	return claim_game(run_id, stage_index, "maze_hunt", match_id)

func obstacle_reward_tier(score: int) -> int:
	return clampi(1 + score / 1000, 1, 4)

func claim_energy_2048(run_id: int, stage_index: int, match_id: String) -> Dictionary:
	var data: Dictionary = _meta.get("energy_2048", {})
	var session := Energy2048Session.new()
	if int(data.get("run_id", -1)) != run_id or not session.restore(data):
		return {"ok": false, "message": "Không tìm thấy ván 2048 hợp lệ."}
	if session.match_id != match_id or session.status == "playing" or session.settled:
		return {"ok": false, "message": "Ván chưa kết thúc hoặc đã nhận thưởng."}
	var result := claim_game(run_id, stage_index, "2048", match_id)
	if not bool(result.get("ok", false)):
		return result
	session.settled = true
	var stored := session.snapshot()
	stored["run_id"] = run_id
	_meta["energy_2048"] = stored
	return result
