class_name StageLifecycle
extends RefCounted


const SAVE_INTERVAL: float = 5.0
const FINAL_STAGE: int = 5

const FULL_SPEED_FOOD_RATIO: float = 0.50
const LOW_SPEED_FOOD_RATIO: float = 0.25
const MID_FOOD_GROWTH_MULTIPLIER: float = 0.75
const LOW_FOOD_GROWTH_MULTIPLIER: float = 0.50


var _meta: Dictionary = {}
var _state: Dictionary = {}
var _policy: StageLifecyclePolicy
var _skills: PetSkillService
var _save_accumulator: float = 0.0


func setup(
	meta: Dictionary,
	run_id: int,
	current_stage: int = 1,
	skills: PetSkillService = null
) -> void:
	_meta = meta
	_skills = skills
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

	_migrate_stage_age(
		current
	)
	_migrate_food_capacity(
		current
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

	var now := int(
		Time.get_unix_time_from_system()
	)
	var skill_changed := _apply_due_skill_rebounds(
		now
	)

	_apply_progress(
		delta,
		now - int(ceil(delta))
	)

	_state["last_update_unix"] = now

	_update_ready()
	_sync_meta()

	_save_accumulator += delta

	if (
		skill_changed
		or _save_accumulator >= SAVE_INTERVAL
	):
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

	if (
		item_type == ItemGenerator.TYPE_GROWTH
		and _has_no_food()
	):
		return {
			"ok": false,
			"message": "Độ no đã hết. Hãy cho ăn trước khi dùng vật phẩm tăng trưởng.",
		}

	var notes: Array[String] = []

	match item_type:
		ItemGenerator.TYPE_FOOD:
			var food_delta := float(
				item.get(
					"main_value_seconds",
					0
				)
			)
			var growth_delta := float(
				item.get(
					"growth_delta_seconds",
					0
				)
			)

			if _skills != null:
				var adjusted := _skills.adjust_food_item(
					item,
					food_delta,
					growth_delta
				)
				food_delta = float(
					adjusted.get(
						"food_seconds",
						food_delta
					)
				)
				growth_delta = float(
					adjusted.get(
						"growth_seconds",
						growth_delta
					)
				)
				var adjusted_notes: Variant = adjusted.get(
					"notes",
					[]
				)
				if typeof(adjusted_notes) == TYPE_ARRAY:
					for note in adjusted_notes as Array:
						notes.append(String(note))

			var overflow := _add_food_seconds(
				food_delta
			)

			if (
				_skills != null
				and _skills.converts_overflow_to_growth()
				and overflow > 0.0
			):
				growth_delta += overflow * 0.20
				notes.append("Tích Trữ Năng Lượng")

			_state["growth_elapsed_seconds"] = maxf(
				0.0,
				float(
					_state.get(
						"growth_elapsed_seconds",
						0.0
					)
				) + growth_delta
			)

			if (
				_skills != null
				and _skills.schedule_rebound(
					String(item.get("uid", "")),
					maxf(0.0, food_delta)
				)
			):
				notes.append("Phản Sô đã tích trữ một lần hồi No")

		ItemGenerator.TYPE_GROWTH:
			var growth_delta := float(
				item.get(
					"main_value_seconds",
					0
				)
			)
			var food_delta := float(
				item.get(
					"food_delta_seconds",
					0
				)
			)

			if (
				growth_delta > 0.0
				and _skills != null
			):
				growth_delta *= (
					_skills.direct_growth_multiplier()
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

			if food_delta != 0.0:
				_add_food_seconds(
					food_delta
				)

		_:
			return {
				"ok": false,
				"message": "Vật phẩm này chưa tác động vào tăng trưởng.",
			}

	_update_ready()
	_sync_meta()

	var message := (
		"Đã sử dụng "
		+ String(
			item.get(
				"display_name",
				"vật phẩm"
			)
		)
	)

	if not notes.is_empty():
		message += " • " + " • ".join(notes)

	return {
		"ok": true,
		"message": message,
		"skill_notes": notes,
	}

func apply_growth_bonus_percent(
	percent: float
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
			"message": "Pet đã sẵn sàng tiến hóa.",
		}

	if _has_no_food():
		return {
			"ok": false,
			"message": "Độ no đã hết. Hãy cho ăn trước.",
		}

	var normalized_percent := maxf(
		0.0,
		percent
	)

	if normalized_percent <= 0.0:
		return {
			"ok": false,
			"message": "Growth bonus không hợp lệ.",
		}

	if _skills != null:
		normalized_percent *= (
			_skills.direct_growth_multiplier()
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

	if duration <= 0.0:
		return {
			"ok": false,
			"message": "Giai đoạn hiện tại không có Growth.",
		}

	var before_growth := maxf(
		0.0,
		float(
			_state.get(
				"growth_elapsed_seconds",
				0.0
			)
		)
	)
	var requested_delta := (
		duration
		* normalized_percent
		/ 100.0
	)

	_state["growth_elapsed_seconds"] = (
		before_growth
		+ requested_delta
	)
	_update_ready()
	_sync_meta()

	var after_growth := maxf(
		0.0,
		float(
			_state.get(
				"growth_elapsed_seconds",
				0.0
			)
		)
	)

	return {
		"ok": true,
		"growth_bonus_percent": normalized_percent,
		"growth_delta_seconds": int(
			round(
				maxf(
					0.0,
					after_growth - before_growth
				)
			)
		),
		"ready_to_evolve": bool(
			_state.get(
				"ready_to_evolve",
				false
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
	var age_elapsed := clampf(
		float(
			_state.get(
				"age_elapsed_seconds",
				0.0
			)
		),
		0.0,
		duration
	)
	var age_remaining := maxf(
		0.0,
		duration - age_elapsed
	)
	var ratio := (
		elapsed / duration
		if duration > 0.0
		else 1.0
	)
	var food_seconds := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var food_capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)
	var food_ratio := _food_ratio(
		food_seconds,
		food_capacity
	)
	var growth_multiplier := (
		_growth_multiplier_for_ratio(
			food_ratio
		)
	)
	var food_depletion_multiplier := 1.0

	if _skills != null:
		growth_multiplier *= (
			_skills.natural_growth_multiplier(
				food_ratio,
				ratio,
				stage_index,
				int(Time.get_unix_time_from_system())
			)
		)
		food_depletion_multiplier = (
			_skills.food_depletion_multiplier(
				food_ratio
			)
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
		"age_elapsed_seconds": int(
			round(
				age_elapsed
			)
		),
		"age_remaining_seconds": int(
			round(
				age_remaining
			)
		),
		"age_percent": int(
			round(
				(
					age_elapsed / duration
					if duration > 0.0
					else 1.0
				) * 100.0
			)
		),
		"deadline_reached": (
			duration > 0.0
			and age_elapsed >= duration
		),
		"food_seconds": int(
			round(
				food_seconds
			)
		),
		"food_capacity_seconds": int(
			round(
				food_capacity
			)
		),
		"food_buffer_seconds": int(
			round(
				maxf(
					0.0,
					float(
						_state.get(
							"food_buffer_seconds",
							0.0
						)
					)
				)
			)
		),
		"food_ratio": food_ratio,
		"food_percent": int(
			round(
				food_ratio * 100.0
			)
		),
		"food_depletion_multiplier": food_depletion_multiplier,
		"growth_speed_multiplier": growth_multiplier,
		"growth_speed_percent": int(
			round(
				growth_multiplier * 100.0
			)
		),
		"hibernating": _is_hibernating(),
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

	var run_id := int(
		_state.get(
			"run_id",
			0
		)
	)
	var carry_food := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var carry_buffer := maxf(
		0.0,
		float(
			_state.get(
				"food_buffer_seconds",
				0.0
			)
		)
	)

	_state = _new_stage_state(
		run_id,
		stage_index,
		carry_food
	)

	if (
		_skills != null
		and carry_buffer > 0.0
	):
		_state["food_buffer_seconds"] = minf(
			carry_buffer,
			_skills.bottomless_buffer_capacity(
				float(
					_state.get(
						"food_capacity_seconds",
						1.0
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
	_migrate_stage_age(
		_state
	)
	_migrate_food_capacity(
		_state
	)
	_update_ready()


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
			"age_elapsed_seconds": 0.0,
			"food_seconds": carry_food_seconds,
			"food_capacity_seconds": maxf(
				1.0,
				carry_food_seconds
			),
			"food_buffer_seconds": 0.0,
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
		"age_elapsed_seconds": 0.0,
		"food_seconds": minf(
			float(
				config.get(
					"food_capacity_seconds",
					1
				)
			),
			(
				carry_food_seconds
				if carry_food_seconds > 0.0
				else float(
					config.get(
						"starting_food_seconds",
						0
					)
				)
			)
		),
		"food_capacity_seconds": maxf(
			1.0,
			float(
				config.get(
					"food_capacity_seconds",
					1
				)
			)
		),
		"food_buffer_seconds": 0.0,
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
	delta: float,
	start_unix: int = -1
) -> void:
	var progress_delta := maxf(
		0.0,
		delta
	)

	if progress_delta <= 0.0:
		return

	var food_seconds := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var food_capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)
	var growth_elapsed := maxf(
		0.0,
		float(
			_state.get(
				"growth_elapsed_seconds",
				0.0
			)
		)
	)
	var age_elapsed := maxf(
		0.0,
		float(
			_state.get(
				"age_elapsed_seconds",
				0.0
			)
		)
	)

	age_elapsed += progress_delta

	if (
		_skills == null
		or _skills.skill_ids().is_empty()
	):
		growth_elapsed += _growth_from_food_window(
			food_seconds,
			food_capacity,
			progress_delta
		)
		food_seconds = maxf(
			0.0,
			food_seconds - progress_delta
		)
		_state["food_seconds"] = food_seconds
		_state["growth_elapsed_seconds"] = growth_elapsed
		_state["age_elapsed_seconds"] = age_elapsed
		return

	var duration := maxf(
		1.0,
		float(
			_state.get(
				"duration_seconds",
				1.0
			)
		)
	)
	var remaining := progress_delta
	var progressed := 0.0
	const STEP_SECONDS: float = 300.0

	while remaining > 0.0:
		_refill_from_food_buffer()
		food_seconds = maxf(
			0.0,
			float(
				_state.get(
					"food_seconds",
					0.0
				)
			)
		)

		if food_seconds <= 0.0:
			var rescue := _skills.try_survival_refill(
				int(
					_state.get(
						"stage_index",
						1
					)
				),
				food_capacity
			)
			if rescue <= 0.0:
				break
			_add_food_seconds(rescue)
			food_seconds = float(
				_state.get(
					"food_seconds",
					0.0
				)
			)

		var food_ratio := _food_ratio(
			food_seconds,
			food_capacity
		)
		var growth_ratio := clampf(
			growth_elapsed / duration,
			0.0,
			1.0
		)
		var depletion_multiplier := (
			_skills.food_depletion_multiplier(
				food_ratio
			)
		)
		var step := minf(
			remaining,
			STEP_SECONDS
		)

		if depletion_multiplier > 0.0:
			step = minf(
				step,
				food_seconds / depletion_multiplier
			)

		if step <= 0.0:
			break

		var sample_unix := (
			start_unix + int(progressed)
			if start_unix >= 0
			else int(Time.get_unix_time_from_system())
		)
		var growth_multiplier := (
			_growth_multiplier_for_ratio(
				food_ratio
			)
			* _skills.natural_growth_multiplier(
				food_ratio,
				growth_ratio,
				int(
					_state.get(
						"stage_index",
						1
					)
				),
				sample_unix
			)
		)

		growth_elapsed += (
			step * growth_multiplier
		)
		food_seconds = maxf(
			0.0,
			food_seconds
			- step * depletion_multiplier
		)
		_state["food_seconds"] = food_seconds

		remaining -= step
		progressed += step

	_state["growth_elapsed_seconds"] = growth_elapsed
	_state["age_elapsed_seconds"] = age_elapsed

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
	var cursor := last_update

	while cursor < now:
		var next_due := 0
		if _skills != null:
			next_due = _skills.next_rebound_due_between(
				cursor,
				now
			)

		var segment_end := (
			next_due
			if next_due > 0
			else now
		)

		if segment_end > cursor:
			_apply_progress(
				float(segment_end - cursor),
				cursor
			)

		cursor = segment_end

		if next_due > 0:
			_apply_due_skill_rebounds(
				cursor
			)
		else:
			break

	_state["last_update_unix"] = now
	_update_ready()

func _update_ready() -> void:
	if not _can_progress():
		_state["ready_to_evolve"] = false
		return

	var duration := maxf(
		0.0,
		float(
			_state.get(
				"duration_seconds",
				0.0
			)
		)
	)
	var growth_elapsed := maxf(
		0.0,
		float(
			_state.get(
				"growth_elapsed_seconds",
				0.0
			)
		)
	)

	if duration <= 0.0:
		_state["ready_to_evolve"] = true
		return

	if growth_elapsed >= duration:
		_state["growth_elapsed_seconds"] = duration
		_state["ready_to_evolve"] = true
		return

	_state["ready_to_evolve"] = false


func _migrate_stage_age(
	state: Dictionary
) -> void:
	if (
		state.is_empty()
		or state.has(
			"age_elapsed_seconds"
		)
	):
		return

	var duration := maxf(
		0.0,
		float(
			state.get(
				"duration_seconds",
				0.0
			)
		)
	)
	var now := int(
		Time.get_unix_time_from_system()
	)
	var last_update := int(
		state.get(
			"last_update_unix",
			now
		)
	)
	var started := int(
		state.get(
			"started_at_unix",
			last_update
		)
	)
	var age_elapsed := maxf(
		0.0,
		float(
			maxi(
				0,
				last_update - started
			)
		)
	)

	if duration > 0.0:
		age_elapsed = minf(
			age_elapsed,
			duration
		)

	state["age_elapsed_seconds"] = age_elapsed


func _migrate_food_capacity(
	state: Dictionary
) -> void:
	if state.is_empty():
		return

	var stage_index := int(
		state.get(
			"stage_index",
			1
		)
	)
	var config := (
		_policy.stage(
			stage_index
		)
		if _policy != null
		else {}
	)
	var existing_food := maxf(
		0.0,
		float(
			state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var configured_capacity := float(
		config.get(
			"food_capacity_seconds",
			0
		)
	)
	var capacity := maxf(
		1.0,
		(
			configured_capacity
			if configured_capacity > 0.0
			else float(
				state.get(
					"food_capacity_seconds",
					existing_food
				)
			)
		)
	)

	state["food_capacity_seconds"] = capacity
	state["food_seconds"] = minf(
		existing_food,
		capacity
	)

	var buffer_capacity := (
		_skills.bottomless_buffer_capacity(
			capacity
		)
		if _skills != null
		else 0.0
	)
	state["food_buffer_seconds"] = clampf(
		float(
			state.get(
				"food_buffer_seconds",
				0.0
			)
		),
		0.0,
		buffer_capacity
	)

func _clamp_food_to_capacity() -> void:
	var capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)

	_state["food_seconds"] = clampf(
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		),
		0.0,
		capacity
	)

	var buffer_capacity := (
		_skills.bottomless_buffer_capacity(
			capacity
		)
		if _skills != null
		else 0.0
	)
	_state["food_buffer_seconds"] = clampf(
		float(
			_state.get(
				"food_buffer_seconds",
				0.0
			)
		),
		0.0,
		buffer_capacity
	)

func _has_no_food() -> bool:
	return float(
		_state.get(
			"food_seconds",
			0.0
		)
	) <= 0.0


func _is_hibernating() -> bool:
	if not _can_progress():
		return false

	var food_seconds := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)
	var ratio := _food_ratio(
		food_seconds,
		capacity
	)

	if _skills != null:
		return _skills.is_hibernating_at_ratio(
			ratio
		)

	return food_seconds <= 0.0

func _food_ratio(
	food_seconds: float,
	food_capacity: float
) -> float:
	if food_seconds <= 0.0:
		return 0.0

	return clampf(
		food_seconds / maxf(
			1.0,
			food_capacity
		),
		0.0,
		1.0
	)


func _growth_multiplier_for_ratio(
	food_ratio: float
) -> float:
	if food_ratio <= 0.0:
		return 0.0
	if food_ratio <= LOW_SPEED_FOOD_RATIO:
		return LOW_FOOD_GROWTH_MULTIPLIER
	if food_ratio <= FULL_SPEED_FOOD_RATIO:
		return MID_FOOD_GROWTH_MULTIPLIER
	return 1.0


func _growth_from_food_window(
	food_seconds: float,
	food_capacity: float,
	delta: float
) -> float:
	var remaining := maxf(
		0.0,
		delta
	)
	var cursor := maxf(
		0.0,
		food_seconds
	)
	var capacity := maxf(
		1.0,
		food_capacity
	)
	var growth_delta := 0.0
	var half_threshold := (
		capacity * FULL_SPEED_FOOD_RATIO
	)
	var quarter_threshold := (
		capacity * LOW_SPEED_FOOD_RATIO
	)

	if cursor > half_threshold and remaining > 0.0:
		var full_span := minf(
			remaining,
			cursor - half_threshold
		)
		growth_delta += full_span
		cursor -= full_span
		remaining -= full_span

	if cursor > quarter_threshold and remaining > 0.0:
		var mid_span := minf(
			remaining,
			cursor - quarter_threshold
		)
		growth_delta += (
			mid_span
			* MID_FOOD_GROWTH_MULTIPLIER
		)
		cursor -= mid_span
		remaining -= mid_span

	if cursor > 0.0 and remaining > 0.0:
		var low_span := minf(
			remaining,
			cursor
		)
		growth_delta += (
			low_span
			* LOW_FOOD_GROWTH_MULTIPLIER
		)

	return growth_delta


func _add_food_seconds(
	delta: float
) -> float:
	var capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)
	var current := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)

	if delta < 0.0:
		_state["food_seconds"] = maxf(
			0.0,
			current + delta
		)
		_refill_from_food_buffer()
		return 0.0

	var total := current + delta
	var overflow := maxf(
		0.0,
		total - capacity
	)
	_state["food_seconds"] = minf(
		capacity,
		total
	)

	if (
		overflow > 0.0
		and _skills != null
	):
		var buffer_capacity := (
			_skills.bottomless_buffer_capacity(
				capacity
			)
		)
		if buffer_capacity > 0.0:
			var buffer := maxf(
				0.0,
				float(
					_state.get(
						"food_buffer_seconds",
						0.0
					)
				)
			)
			var stored := minf(
				overflow,
				maxf(
					0.0,
					buffer_capacity - buffer
				)
			)
			buffer += stored
			overflow -= stored
			_state["food_buffer_seconds"] = buffer

	return overflow


func _refill_from_food_buffer() -> void:
	if _skills == null:
		return

	var capacity := maxf(
		1.0,
		float(
			_state.get(
				"food_capacity_seconds",
				1.0
			)
		)
	)
	var current := maxf(
		0.0,
		float(
			_state.get(
				"food_seconds",
				0.0
			)
		)
	)
	var buffer := maxf(
		0.0,
		float(
			_state.get(
				"food_buffer_seconds",
				0.0
			)
		)
	)

	if (
		buffer <= 0.0
		or current >= capacity
	):
		return

	var moved := minf(
		buffer,
		capacity - current
	)
	_state["food_seconds"] = current + moved
	_state["food_buffer_seconds"] = buffer - moved


func _apply_due_skill_rebounds(
	unix_time: int
) -> bool:
	if _skills == null:
		return false

	var amount := _skills.claim_due_rebounds(
		unix_time
	)

	if amount <= 0:
		return false

	_add_food_seconds(
		float(amount)
	)
	_sync_meta()
	return true


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
