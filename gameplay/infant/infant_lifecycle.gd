class_name InfantLifecycle
extends RefCounted


const DURATION_SECONDS: int = 2 * 60 * 60
const START_FOOD_SECONDS: int = 15 * 60
const STARVED_GROWTH_MULTIPLIER: float = 0.75
const SAVE_INTERVAL: float = 5.0


var _meta: Dictionary = {}
var _state: Dictionary = {}
var _save_accumulator: float = 0.0


func setup(
	meta: Dictionary,
	run_id: int
) -> void:
	_meta = meta

	var current: Dictionary = _meta.get("infant_state", {})

	if (
		current.is_empty()
		or int(current.get("run_id", -1)) != run_id
	):
		current = {
			"run_id": run_id,
			"started_at_unix": int(Time.get_unix_time_from_system()),
			"last_update_unix": int(Time.get_unix_time_from_system()),
			"duration_seconds": DURATION_SECONDS,
			"growth_elapsed_seconds": 0.0,
			"food_seconds": START_FOOD_SECONDS,
			"ready_to_evolve": false,
			"tutorial_protected": true,
		}

	_state = current
	_apply_offline_progress()
	_sync_meta()


func tick(delta: float) -> bool:
	if _state.is_empty():
		return false

	if bool(_state.get("ready_to_evolve", false)):
		return false

	var food_seconds := float(_state.get("food_seconds", 0.0))
	var growth_elapsed := float(_state.get("growth_elapsed_seconds", 0.0))

	var fed_delta := min(delta, max(0.0, food_seconds))
	var hungry_delta := max(0.0, delta - fed_delta)

	food_seconds = max(0.0, food_seconds - delta)
	growth_elapsed += fed_delta
	growth_elapsed += hungry_delta * STARVED_GROWTH_MULTIPLIER

	_state["food_seconds"] = food_seconds
	_state["growth_elapsed_seconds"] = growth_elapsed
	_state["last_update_unix"] = int(Time.get_unix_time_from_system())

	_update_ready()
	_sync_meta()

	_save_accumulator += delta

	if _save_accumulator >= SAVE_INTERVAL:
		_save_accumulator = 0.0
		return true

	return false


func apply_item(item: Dictionary) -> Dictionary:
	var item_type := StringName(item.get("item_type", ""))

	match item_type:
		ItemGenerator.TYPE_FOOD:
			var food_delta := int(item.get("main_value_seconds", 0))
			var growth_delta := int(item.get("growth_delta_seconds", 0))

			_state["food_seconds"] = max(
				0.0,
				float(_state.get("food_seconds", 0.0)) + food_delta
			)

			_state["growth_elapsed_seconds"] = max(
				0.0,
				float(_state.get("growth_elapsed_seconds", 0.0)) + growth_delta
			)

		ItemGenerator.TYPE_GROWTH:
			var growth_delta := int(item.get("main_value_seconds", 0))
			var food_delta := int(item.get("food_delta_seconds", 0))

			_state["growth_elapsed_seconds"] = max(
				0.0,
				float(_state.get("growth_elapsed_seconds", 0.0)) + growth_delta
			)

			_state["food_seconds"] = max(
				0.0,
				float(_state.get("food_seconds", 0.0)) + food_delta
			)

		_:
			return {
				"ok": false,
				"message": "Vật phẩm này chưa dùng được ở giai đoạn Ấu thể.",
			}

	_update_ready()
	_sync_meta()

	return {
		"ok": true,
		"message": "Đã sử dụng " + String(item.get("display_name", "vật phẩm")),
	}


func snapshot() -> Dictionary:
	var duration := max(
		1.0,
		float(_state.get("duration_seconds", DURATION_SECONDS))
	)
	var elapsed := clampf(
		float(_state.get("growth_elapsed_seconds", 0.0)),
		0.0,
		duration
	)
	var remaining := max(0.0, duration - elapsed)

	return {
		"stage": "infant",
		"growth_ratio": elapsed / duration,
		"growth_percent": int(round(elapsed / duration * 100.0)),
		"growth_remaining_seconds": int(round(remaining)),
		"food_seconds": int(round(float(_state.get("food_seconds", 0.0)))),
		"ready_to_evolve": bool(_state.get("ready_to_evolve", false)),
		"tutorial_protected": bool(_state.get("tutorial_protected", true)),
	}


func _apply_offline_progress() -> void:
	var now := int(Time.get_unix_time_from_system())
	var last_update := int(_state.get("last_update_unix", now))
	var elapsed := max(0, now - last_update)

	if elapsed <= 0:
		_state["last_update_unix"] = now
		return

	var food_seconds := float(_state.get("food_seconds", 0.0))
	var growth_elapsed := float(_state.get("growth_elapsed_seconds", 0.0))

	var fed_seconds := min(float(elapsed), max(0.0, food_seconds))
	var hungry_seconds := max(0.0, float(elapsed) - fed_seconds)

	food_seconds = max(0.0, food_seconds - elapsed)
	growth_elapsed += fed_seconds
	growth_elapsed += hungry_seconds * STARVED_GROWTH_MULTIPLIER

	_state["food_seconds"] = food_seconds
	_state["growth_elapsed_seconds"] = growth_elapsed
	_state["last_update_unix"] = now

	_update_ready()


func _update_ready() -> void:
	var duration := float(_state.get("duration_seconds", DURATION_SECONDS))
	var elapsed := float(_state.get("growth_elapsed_seconds", 0.0))

	if elapsed >= duration:
		_state["growth_elapsed_seconds"] = duration
		_state["ready_to_evolve"] = true


func _sync_meta() -> void:
	_meta["infant_state"] = _state.duplicate(true)
