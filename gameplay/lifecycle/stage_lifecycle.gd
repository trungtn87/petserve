class_name StageLifecycle
extends RefCounted


const SAVE_INTERVAL: float = 5.0
const FINAL_STAGE: int = 4


var _meta: Dictionary = {}
var _state: Dictionary = {}
var _policy: StageLifecyclePolicy
var _save_accumulator: float = 0.0


func setup(
	meta: Dictionary,
	run_id: int,
	current_stage: int = 1
) -> void:
	_meta = meta
	_policy = StageLifecyclePolicy.load_default()

	if _policy == null:
		push_error(
			"StageLifecycle: không load được policy."
		)
		return

	var current := _load_saved_state(
		current_stage
	)

	if (
		current.is_empty()
		or int(
			current.get(
				"run_id",
				-1
			)
		) != run_id
	):
		current = _new_stage_state(
			run_id,
			current_stage,
			0.0
		)
	elif int(
		current.get(
			"stage_index",
			1
		)
	) != current_stage:
		current = _new_stage_state(
			run_id,
			current_stage,
			maxf(
				0.0,
				float(
					current.get(
						"food_seconds",
						0.0
					)
				)
			)
		)

	_state = current
	_apply_offline_progress()
	_sync_meta()


func tick(
	delta: float
) -> bool:
	delta = maxf(
		delta,
		0.0
	)

	if (
		_state.is_empty()
		or not _can_progress()
		or bool(
			_state.get(
				"ready_to_evolve",
				false
			)
		)
	):
		return false

	_apply_progress(
		delta
	)

	_state["last_update_unix"] = int(
		Time.get_unix_time_from_system()
	)

	_update_ready()
	_sync_meta()

	_save_accumulator += delta

	if _save_accumulator >= SAVE_INTERVAL:
		_save_accumulator = 0.0
		return true

	return false


func apply_item(
	item: Dictionary
) -> Dictionary:
	if not _can_progress():
		return {
			"ok": false,
			"message": "Hình thái cuối không còn thanh trưởng thành.",
		}

	if bool(
		_state.get(
			"ready_to_evolve",
			false
		)
	):
		return {
			"ok": false,
			"message": "Pet đã sẵn sàng tiến hóa. Vật phẩm được giữ trong kho.",
		}

	var item_type := StringName(
		item.get(
			"item_type",
			""
		)
	)

	match item_type:
		ItemGenerator.TYPE_FOOD:
			var food_delta := int(
				item.get(
					"main_value_seconds",
					0
				)
			)
			var growth_delta := int(
				item.get(
					"growth_delta_seconds",
					0
				)
			)

			_state["food_seconds"] = maxf(
				0.0,
				float(
					_state.get(
						"food_seconds",
						0.0
					)
				) + food_delta
			)
			_state["growth_elapsed_seconds"] = maxf(
				0.0,
				float(
					_state.get(
						"growth_elapsed_seconds",
						0.0
					)
				) + growth_delta
			)

		ItemGenerator.TYPE_GROWTH:
			var growth_delta := int(
				item.get(
					"main_value_seconds",
					0
				)
			)
			var food_delta := int(
				item.get(
					"food_delta_seconds",
					0
				)
			)

			_state["growth_elapsed_seconds"] = maxf(
				0.0,
				float(
					_state.get(
						"growth_elapsed_seconds",
						0.0
					)
				) + growth_delta
			)
			_state["food_seconds"] = maxf(
				0.0,
				float(
					_state.get(
						"food_seconds",
						0.0
					)
				) + food_delta
			)

		_:
			return {
				"ok": false,
				"message": "Vật phẩm này chưa tác động vào tăng trưởng.",
			}

	_update_ready()
	_sync_meta()

	return {
		"ok": true,
		"message": (
			"Đã sử dụng "
			+ String(
				item.get(
					"display_name",
					"vật phẩm"
				)
			)
		),
	}


func snapshot() -> Dictionary:
	var stage_index := int(
		_state.get(
			"stage_index",
			1
		)
	)
	var duration := maxf(
		0.0,
		float(
			_state.get(
				"duration_seconds",
				0.0
			)
		)
	)
	var elapsed := clampf(
		float(
			_state.get(
				"growth_elapsed_seconds",
				0.0
			)
		),
		0.0,
		duration
	)
	var remaining := maxf(
		0.0,
		duration - elapsed
	)
	var ratio := (
		elapsed / duration
		if duration > 0.0
		else 1.0
	)

	return {
		"stage_index": stage_index,
		"duration_seconds": int(
			round(
				duration
			)
		),
		"growth_ratio": ratio,
		"growth_percent": int(
			round(
				ratio * 100.0
			)
		),
		"growth_remaining_seconds": int(
			round(
				remaining
			)
		),
		"food_seconds": int(
			round(
				float(
					_state.get(
						"food_seconds",
						0.0
					)
				)
			)
		),
		"ready_to_evolve": bool(
			_state.get(
				"ready_to_evolve",
				false
			)
		),
		"tutorial_protected": bool(
			_state.get(
				"tutorial_protected",
				true
			)
		),
		"final_form": stage_index >= FINAL_STAGE,
	}


func advance_to_stage(
	stage_index: int
) -> void:
	if _state.is_empty():
		return

	_state = _new_stage_state(
		int(
			_state.get(
				"run_id",
				0
			)
		),
		stage_index,
		maxf(
			0.0,
			float(
				_state.get(
					"food_seconds",
					0.0
				)
			)
		)
	)
	_sync_meta()


func restore_state() -> void:
	var stage_index := int(
		_state.get(
			"stage_index",
			1
		)
	)
	_state = _load_saved_state(
		stage_index
	)


func _load_saved_state(
	preferred_stage: int = -1
) -> Dictionary:
	# M7 tests and old saves may still mutate/read infant_state directly.
	if preferred_stage == 1:
		var legacy: Variant = _meta.get(
			"infant_state",
			{}
		)

		if (
			typeof(legacy) == TYPE_DICTIONARY
			and not (
				legacy as Dictionary
			).is_empty()
		):
			var migrated := (
				legacy as Dictionary
			).duplicate(true)

			if not migrated.has(
				"stage_index"
			):
				migrated["stage_index"] = 1

			return migrated

	var value: Variant = _meta.get(
		"life_state",
		{}
	)

	if (
		typeof(value) == TYPE_DICTIONARY
		and not (
			value as Dictionary
		).is_empty()
	):
		return (
			value as Dictionary
		).duplicate(true)

	var fallback: Variant = _meta.get(
		"infant_state",
		{}
	)

	if typeof(fallback) != TYPE_DICTIONARY:
		return {}

	var migrated_fallback := (
		fallback as Dictionary
	).duplicate(true)

	if migrated_fallback.is_empty():
		return {}

	if not migrated_fallback.has(
		"stage_index"
	):
		migrated_fallback["stage_index"] = 1

	return migrated_fallback


func _new_stage_state(
	run_id: int,
	stage_index: int,
	carry_food_seconds: float
) -> Dictionary:
	var now := int(
		Time.get_unix_time_from_system()
	)
	var config := _policy.stage(
		stage_index
	)

	if config.is_empty():
		return {
			"run_id": run_id,
			"stage_index": stage_index,
			"started_at_unix": now,
			"last_update_unix": now,
			"duration_seconds": 0,
			"growth_elapsed_seconds": 0.0,
			"food_seconds": carry_food_seconds,
			"ready_to_evolve": false,
			"tutorial_protected": true,
			"final_form": stage_index >= FINAL_STAGE,
		}

	return {
		"run_id": run_id,
		"stage_index": stage_index,
		"started_at_unix": now,
		"last_update_unix": now,
		"duration_seconds": int(
			config.get(
				"duration_seconds",
				0
			)
		),
		"growth_elapsed_seconds": 0.0,
		"food_seconds": (
			carry_food_seconds
			if carry_food_seconds > 0.0
			else float(
				config.get(
					"starting_food_seconds",
					0
				)
			)
		),
		"ready_to_evolve": false,
		"tutorial_protected": bool(
			config.get(
				"tutorial_protected",
				true
			)
		),
		"final_form": false,
	}


func _can_progress() -> bool:
	if _policy == null:
		return false

	return _policy.can_grow(
		int(
			_state.get(
				"stage_index",
				1
			)
		)
	)


func _apply_progress(
	delta: float
) -> void:
	var stage_index := int(
		_state.get(
			"stage_index",
			1
		)
	)
	var config := _policy.stage(
		stage_index
	)
	var multiplier := float(
		config.get(
			"starved_growth_multiplier",
			0.75
		)
	)

	var food_seconds := float(
		_state.get(
			"food_seconds",
			0.0
		)
	)
	var growth_elapsed := float(
		_state.get(
			"growth_elapsed_seconds",
			0.0
		)
	)

	var fed_delta := minf(
		delta,
		maxf(
			0.0,
			food_seconds
		)
	)
	var hungry_delta := maxf(
		0.0,
		delta - fed_delta
	)

	food_seconds = maxf(
		0.0,
		food_seconds - delta
	)
	growth_elapsed += fed_delta
	growth_elapsed += (
		hungry_delta * multiplier
	)

	_state["food_seconds"] = food_seconds
	_state["growth_elapsed_seconds"] = growth_elapsed


func _apply_offline_progress() -> void:
	if (
		_state.is_empty()
		or not _can_progress()
		or bool(
			_state.get(
				"ready_to_evolve",
				false
			)
		)
	):
		return

	var now := int(
		Time.get_unix_time_from_system()
	)
	var last_update := int(
		_state.get(
			"last_update_unix",
			now
		)
	)
	var elapsed := maxi(
		0,
		now - last_update
	)

	if elapsed > 0:
		_apply_progress(
			float(
				elapsed
			)
		)

	_state["last_update_unix"] = now
	_update_ready()


func _update_ready() -> void:
	if not _can_progress():
		_state["ready_to_evolve"] = false
		return

	var duration := float(
		_state.get(
			"duration_seconds",
			0.0
		)
	)
	var elapsed := float(
		_state.get(
			"growth_elapsed_seconds",
			0.0
		)
	)

	if elapsed >= duration:
		_state["growth_elapsed_seconds"] = duration
		_state["ready_to_evolve"] = true


func _sync_meta() -> void:
	_meta["life_state"] = _state.duplicate(
		true
	)

	# Keep the old field synchronized during migration so M7 tests/saves survive.
	if int(
		_state.get(
			"stage_index",
			1
		)
	) == 1:
		_meta["infant_state"] = _state.duplicate(
			true
	)
