class_name PetSkillService
extends RefCounted


const META_KEY: String = "pet_skill_state"
const SCHEMA: int = 1
const MAX_SLOTS: int = PetSkillCatalog.MAX_SLOTS
const FOOD_PREFERENCES: Array[String] = ["fish", "meat", "fruit", "milk_nectar"]
const REBOUND_DELAY_SECONDS: int = 2 * 60 * 60


var _meta: Dictionary = {}
var _state: Dictionary = {}
var _run_id: int = 0
var _egg_stage: int = 1


func setup(meta: Dictionary, run_id: int, egg_stage: int = 1) -> void:
	_meta = meta
	_run_id = run_id
	_egg_stage = clampi(egg_stage, 1, 4)
	reload()

	if (
		_state.is_empty()
		or int(_state.get("run_id", -1)) != _run_id
	):
		_state = {
			"schema": SCHEMA,
			"run_id": _run_id,
			"egg_stage": _egg_stage,
			"slots": [],
			"roll_counters": {},
			"survival_used_stages": [],
			"rebound_queue": [],
			"first_meal_day": "",
			"food_preference": "",
		}
	else:
		_state["schema"] = SCHEMA
		_state["egg_stage"] = maxi(
			int(_state.get("egg_stage", 1)),
			_egg_stage
		)
		_sanitize_state()

	_sync()


func reload() -> void:
	var value: Variant = _meta.get(META_KEY, {})
	if typeof(value) != TYPE_DICTIONARY:
		_state = {}
		return
	_state = (value as Dictionary).duplicate(true)
	_sanitize_state()


func ensure_for_stage(stage_index: int) -> bool:
	var changed := false

	changed = _ensure_slot(1, "stage1") or changed

	if stage_index >= 2:
		changed = _ensure_slot(2, "stage2") or changed

	if stage_index >= 3:
		changed = _ensure_slot(3, "stage3") or changed

	if int(_state.get("egg_stage", _egg_stage)) >= 4:
		changed = _ensure_slot(4, "egg_stage4") or changed

	if changed:
		_sync()

	return changed


func snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []

	for slot_value in _slot_entries():
		var skill_id := StringName(
			slot_value.get("skill_id", "")
		)
		var definition := PetSkillCatalog.definition(skill_id)
		if definition.is_empty():
			continue
		entries.append({
			"slot": int(slot_value.get("slot", 0)),
			"skill_id": String(skill_id),
			"source": String(slot_value.get("source", "")),
			"display_name": String(definition.get("name", "")),
			"description": String(definition.get("description", "")),
		})

	return {
		"max_slots": MAX_SLOTS,
		"unlocked_slots": entries.size(),
		"egg_stage4_bonus": int(_state.get("egg_stage", 1)) >= 4,
		"food_preference": String(_state.get("food_preference", "")),
		"night_window_start_hour": _night_window_start_hour(),
		"skills": entries,
	}


func skill_ids() -> Array[String]:
	var result: Array[String] = []
	for entry in _slot_entries():
		var skill_id := String(entry.get("skill_id", ""))
		if (
			not skill_id.is_empty()
			and not result.has(skill_id)
		):
			result.append(skill_id)
	return result


func has_skill(skill_id: StringName) -> bool:
	return skill_ids().has(String(skill_id))


func display_name(skill_id: StringName) -> String:
	return PetSkillCatalog.display_name(skill_id)


func item_influence_multiplier() -> float:
	return 0.90 if has_skill(&"fast_grower") else 1.0


func direct_growth_multiplier() -> float:
	return 0.80 if has_skill(&"long_childhood") else 1.0


func food_depletion_multiplier(food_ratio: float) -> float:
	var multiplier := 1.0

	if has_skill(&"slow_digestion"):
		multiplier *= 0.80

	if has_skill(&"fast_metabolism"):
		multiplier *= 1.20

	if (
		has_skill(&"frugal_life")
		and food_ratio >= 0.30
	):
		multiplier *= 0.75

	if (
		has_skill(&"energy_burner")
		and food_ratio >= 0.80
	):
		multiplier *= 1.25

	if (
		has_skill(&"hibernation")
		and food_ratio > 0.0
		and food_ratio <= 0.15
	):
		multiplier *= 0.15

	return maxf(0.01, multiplier)


func natural_growth_multiplier(
	food_ratio: float,
	growth_ratio: float,
	stage_index: int,
	unix_time: int = -1
) -> float:
	var multiplier := 1.0

	if has_skill(&"fast_metabolism"):
		multiplier *= 1.15

	if has_skill(&"long_childhood"):
		multiplier *= 0.80

	if has_skill(&"fast_grower"):
		multiplier *= 1.25

	if (
		has_skill(&"growth_spurt")
		and growth_ratio >= 0.80
	):
		multiplier *= 1.50

	if (
		has_skill(&"strong_start")
		and growth_ratio < 0.25
	):
		multiplier *= 1.30

	if has_skill(&"late_bloomer"):
		multiplier *= (
			1.35
			if growth_ratio >= 0.70
			else 0.85
		)

	if (
		has_skill(&"energy_burner")
		and food_ratio >= 0.80
	):
		multiplier *= 1.25

	if has_skill(&"full_belly_growth"):
		if food_ratio >= 0.80:
			multiplier *= 1.20
		elif food_ratio < 0.40:
			multiplier *= 0.60

	if (
		has_skill(&"hungry_growth")
		and food_ratio > 0.0
		and food_ratio < 0.30
	):
		multiplier *= 1.25

	if (
		has_skill(&"hibernation")
		and food_ratio > 0.0
		and food_ratio <= 0.15
	):
		multiplier *= 0.10

	if (
		has_skill(&"night_eater")
		and is_night_window(unix_time)
	):
		multiplier *= 1.15

	if (
		has_skill(&"growth_window")
		and _in_growth_window(
			stage_index,
			growth_ratio
		)
	):
		multiplier *= 2.0

	return maxf(0.0, multiplier)


func adjust_food_item(
	item: Dictionary,
	food_seconds: float,
	growth_seconds: float
) -> Dictionary:
	var adjusted_food := food_seconds
	var adjusted_growth := growth_seconds
	var notes: Array[String] = []

	if has_skill(&"hearty_eater"):
		adjusted_food *= 1.20
		notes.append("Ăn Khỏe")

	if has_skill(&"efficient_absorption"):
		adjusted_growth *= 1.10
		notes.append("Hấp Thu Tốt")

	if has_skill(&"frugal_life"):
		adjusted_growth *= 0.90

	adjusted_growth *= direct_growth_multiplier()

	if has_skill(&"picky_eater"):
		var category := food_category(item)
		var preferred := _food_preference()
		if category == preferred:
			adjusted_food *= 1.30
			adjusted_growth *= 1.30
			notes.append("Kén Ăn: món ưa thích")
		elif (
			not category.is_empty()
			and not has_skill(&"omnivore")
		):
			adjusted_food *= 0.70
			adjusted_growth *= 0.70
			notes.append("Kén Ăn: không hợp khẩu vị")

	if (
		has_skill(&"first_meal_genius")
		and _consume_first_meal_bonus()
	):
		adjusted_growth *= 2.0
		notes.append("Một Bữa Thành Tài")

	if (
		has_skill(&"night_eater")
		and is_night_window(
			int(Time.get_unix_time_from_system())
		)
	):
		adjusted_growth *= 1.15
		notes.append("Ăn Đêm")

	var mutant_outcome := ""
	if has_skill(&"mutant_metabolism"):
		var roll := _roll_percent(
			"mutant_metabolism",
			String(item.get("uid", ""))
		)
		if roll < 6:
			adjusted_growth = (
				maxf(adjusted_growth, adjusted_food)
				* 3.0
			)
			adjusted_food = 0.0
			mutant_outcome = "growth"
			notes.append("Đột Biến Chuyển Hóa: Growth x3")
		elif roll < 12:
			adjusted_food *= 3.0
			adjusted_growth = 0.0
			mutant_outcome = "fullness"
			notes.append("Đột Biến Chuyển Hóa: No x3")

	return {
		"food_seconds": adjusted_food,
		"growth_seconds": adjusted_growth,
		"notes": notes,
		"mutant_outcome": mutant_outcome,
	}


func should_preserve_food_item(item_uid: String) -> bool:
	if not has_skill(&"perfect_conversion"):
		return false

	return (
		_roll_percent(
			"perfect_conversion",
			item_uid
		) < 10
	)


func schedule_rebound(
	item_uid: String,
	food_seconds: float
) -> bool:
	if (
		not has_skill(&"rumination")
		or food_seconds <= 0.0
	):
		return false

	if (
		_roll_percent(
			"rumination",
			item_uid
		) >= 20
	):
		return false

	var queue: Array = _state.get("rebound_queue", [])
	queue.append({
		"due_unix": int(Time.get_unix_time_from_system()) + REBOUND_DELAY_SECONDS,
		"food_seconds": int(round(food_seconds * 0.25)),
	})
	_state["rebound_queue"] = queue
	_sync()
	return true


func next_rebound_due_between(
	start_unix: int,
	end_unix: int
) -> int:
	var result := 0
	var queue_value: Variant = _state.get("rebound_queue", [])

	if typeof(queue_value) != TYPE_ARRAY:
		return 0

	for raw in queue_value as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var due := int((raw as Dictionary).get("due_unix", 0))
		if due <= start_unix or due > end_unix:
			continue
		if result == 0 or due < result:
			result = due

	return result


func claim_due_rebounds(unix_time: int) -> int:
	var queue_value: Variant = _state.get("rebound_queue", [])
	if typeof(queue_value) != TYPE_ARRAY:
		return 0

	var kept: Array = []
	var total := 0

	for raw in queue_value as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var event := raw as Dictionary
		if int(event.get("due_unix", 0)) <= unix_time:
			total += maxi(
				0,
				int(event.get("food_seconds", 0))
			)
		else:
			kept.append(event.duplicate(true))

	if total > 0 or kept.size() != (queue_value as Array).size():
		_state["rebound_queue"] = kept
		_sync()

	return total


func try_survival_refill(
	stage_index: int,
	food_capacity_seconds: float
) -> float:
	if (
		not has_skill(&"survival_instinct")
		or food_capacity_seconds <= 0.0
	):
		return 0.0

	var used: Array = _state.get("survival_used_stages", [])
	if used.has(stage_index):
		return 0.0

	used.append(stage_index)
	_state["survival_used_stages"] = used
	_sync()
	return food_capacity_seconds * 0.25


func bottomless_buffer_capacity(
	food_capacity_seconds: float
) -> float:
	if not has_skill(&"bottomless_stomach"):
		return 0.0
	return maxf(0.0, food_capacity_seconds * 0.50)


func converts_overflow_to_growth() -> bool:
	return has_skill(&"energy_storage")


func is_hibernating_at_ratio(food_ratio: float) -> bool:
	return (
		food_ratio <= 0.0
		or (
			has_skill(&"hibernation")
			and food_ratio <= 0.15
		)
	)


func is_night_window(unix_time: int = -1) -> bool:
	if not has_skill(&"night_eater"):
		return false

	var timestamp := (
		unix_time
		if unix_time >= 0
		else int(Time.get_unix_time_from_system())
	)
	var zone := Time.get_time_zone_from_system()
	var local_timestamp := (
		timestamp
		+ int(zone.get("bias", 0)) * 60
	)
	var date := Time.get_datetime_dict_from_unix_time(
		local_timestamp
	)
	var hour := int(date.get("hour", 0))
	var start := _night_window_start_hour()
	var offset := posmod(hour - start, 24)
	return offset < 6


func food_category(item: Dictionary) -> String:
	var definition_id := String(
		item.get(
			"definition_id",
			item.get("uid", "")
		)
	).to_lower()

	if "fish" in definition_id:
		return "fish"
	if "meat" in definition_id:
		return "meat"
	if (
		"fruit" in definition_id
		or "berries" in definition_id
		or "root" in definition_id
	):
		return "fruit"
	if (
		"milk" in definition_id
		or "nectar" in definition_id
	):
		return "milk_nectar"

	return ""


func _ensure_slot(slot: int, source: String) -> bool:
	if _slot_entry(slot) != null:
		return false

	var selected := ""

	if slot == 1:
		var inherited := String(
			_meta.get(
				"legacy_inherited_skill_id",
				""
			)
		)
		if (
			not inherited.is_empty()
			and PetSkillCatalog.is_valid(
				StringName(inherited)
			)
			and not _has_selected(inherited)
		):
			selected = inherited
			source = "legacy"

	if selected.is_empty():
		var available := PetSkillCatalog.all_ids()
		for used in skill_ids():
			available.erase(used)

		if available.is_empty():
			return false

		var seed_key := "%d:%d:%s" % [
			_run_id,
			slot,
			source,
		]
		selected = available[
			posmod(
				_stable_string_hash(seed_key),
				available.size()
			)
		]

	var slots: Array = _state.get("slots", [])
	slots.append({
		"slot": slot,
		"skill_id": selected,
		"source": source,
	})
	_state["slots"] = slots
	_sort_slots()

	if (
		selected == "picky_eater"
		and String(
			_state.get(
				"food_preference",
				""
			)
		).is_empty()
	):
		_state["food_preference"] = FOOD_PREFERENCES[
			posmod(
				_stable_string_hash(
					"%d:food_preference"
					% _run_id
				),
				FOOD_PREFERENCES.size()
			)
		]

	return true


func _slot_entry(slot: int):
	for entry in _slot_entries():
		if int(entry.get("slot", 0)) == slot:
			return entry
	return null


func _slot_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = _state.get("slots", [])

	if typeof(value) != TYPE_ARRAY:
		return result

	for raw in value as Array:
		if typeof(raw) == TYPE_DICTIONARY:
			result.append(
				(raw as Dictionary).duplicate(true)
			)

	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("slot", 0)) < int(b.get("slot", 0))
	)
	return result


func _sort_slots() -> void:
	var slots := _slot_entries()
	_state["slots"] = slots


func _has_selected(skill_id: String) -> bool:
	return skill_ids().has(skill_id)


func _food_preference() -> String:
	var value := String(
		_state.get(
			"food_preference",
			""
		)
	)

	if not value.is_empty():
		return value

	var selected := FOOD_PREFERENCES[
		posmod(
			_stable_string_hash(
				"%d:food_preference"
				% _run_id
			),
			FOOD_PREFERENCES.size()
		)
	]
	_state["food_preference"] = selected
	_sync()
	return selected


func _consume_first_meal_bonus() -> bool:
	var day_key := _local_day_key()
	if String(_state.get("first_meal_day", "")) == day_key:
		return false

	_state["first_meal_day"] = day_key
	_sync()
	return true


func _local_day_key() -> String:
	var unix_time := int(Time.get_unix_time_from_system())
	var zone := Time.get_time_zone_from_system()
	var local_timestamp := (
		unix_time
		+ int(zone.get("bias", 0)) * 60
	)
	var date := Time.get_datetime_dict_from_unix_time(
		local_timestamp
	)
	return "%04d-%02d-%02d" % [
		int(date.get("year", 1970)),
		int(date.get("month", 1)),
		int(date.get("day", 1)),
	]


func _night_window_start_hour() -> int:
	return posmod(
		_stable_string_hash(
			"%d:night_window"
			% _run_id
		),
		24
	)


func _in_growth_window(
	stage_index: int,
	growth_ratio: float
) -> bool:
	var start_percent := (
		20
		+ posmod(
			_stable_string_hash(
				"%d:growth_window:%d"
				% [
					_run_id,
					stage_index,
				]
			),
			49
		)
	)
	var start := float(start_percent) / 100.0
	var finish := minf(1.0, start + 0.12)
	return growth_ratio >= start and growth_ratio < finish


func _roll_percent(
	channel: String,
	extra: String = ""
) -> int:
	var counters: Dictionary = _state.get(
		"roll_counters",
		{}
	)
	var counter := int(
		counters.get(
			channel,
			0
		)
	)
	counters[channel] = counter + 1
	_state["roll_counters"] = counters
	_sync()

	return posmod(
		_stable_string_hash(
			"%d:%s:%s:%d"
			% [
				_run_id,
				channel,
				extra,
				counter,
			]
		),
		100
	)


func _sanitize_state() -> void:
	if _state.is_empty():
		return

	if typeof(_state.get("slots", [])) != TYPE_ARRAY:
		_state["slots"] = []

	if typeof(_state.get("roll_counters", {})) != TYPE_DICTIONARY:
		_state["roll_counters"] = {}

	if typeof(_state.get("survival_used_stages", [])) != TYPE_ARRAY:
		_state["survival_used_stages"] = []

	if typeof(_state.get("rebound_queue", [])) != TYPE_ARRAY:
		_state["rebound_queue"] = []

	var sanitized: Array = []
	var seen: Array[String] = []
	var used_slots: Array[int] = []

	for raw in _state.get("slots", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry := raw as Dictionary
		var slot := int(entry.get("slot", 0))
		var skill_id := String(entry.get("skill_id", ""))
		if (
			slot < 1
			or slot > MAX_SLOTS
			or used_slots.has(slot)
			or seen.has(skill_id)
			or not PetSkillCatalog.is_valid(
				StringName(skill_id)
			)
		):
			continue
		used_slots.append(slot)
		seen.append(skill_id)
		sanitized.append({
			"slot": slot,
			"skill_id": skill_id,
			"source": String(entry.get("source", "")),
		})

	_state["slots"] = sanitized
	_sort_slots()


func _sync() -> void:
	_meta[META_KEY] = _state.duplicate(true)


static func _stable_string_hash(value: String) -> int:
	var result: int = 7
	for index in range(value.length()):
		result = posmod(
			result * 31 + value.unicode_at(index),
			2147483647
		)
	return maxi(1, result)
