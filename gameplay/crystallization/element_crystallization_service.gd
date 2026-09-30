class_name ElementCrystallizationService
extends RefCounted


const STATE_KEY: String = "element_crystallization"
const CYCLE_KEY: String = "element_crystallization_cycles"

const STATUS_IDLE: StringName = &"idle"
const STATUS_RUNNING: StringName = &"running"

const STAGE_ONE: int = 1
const STAGE_TWO: int = 2
const STAGE_THREE: int = 3

const STAGE_DURATIONS: Dictionary = {
	STAGE_ONE: 60 * 60,
	STAGE_TWO: 3 * 60 * 60,
	STAGE_THREE: 8 * 60 * 60,
}
const ADVANCE_CHANCE: float = 0.30
const SEED_MODULUS: int = 2147483647


var _meta: Dictionary = {}
var _generator: ItemGenerator
var _gene_definitions: Array[GeneDefinition] = []
var _gene_policy: StageGenePolicy
var _run_id: int = 0
var _pet_stage: int = 1
var _element_id: StringName = &"neutral"


func setup(
	meta: Dictionary,
	generator: ItemGenerator,
	gene_definitions: Array[GeneDefinition],
	gene_policy: StageGenePolicy,
	run_id: int,
	pet_stage: int,
	element_id: StringName
) -> void:
	_meta = meta
	_generator = generator
	_gene_policy = gene_policy
	_run_id = run_id
	_pet_stage = maxi(1, pet_stage)
	_element_id = _normalize_element(element_id)

	_gene_definitions.clear()
	for definition in gene_definitions:
		if definition != null and definition.is_valid():
			_gene_definitions.append(definition)

	_ensure_state()


func update_context(
	pet_stage: int,
	element_id: StringName
) -> void:
	_pet_stage = maxi(1, pet_stage)
	_element_id = _normalize_element(element_id)


func start(
	now_unix: int = -1
) -> Dictionary:
	_ensure_state()
	var state := _state()

	if StringName(state.get("status", "")) == STATUS_RUNNING:
		return {
			"ok": false,
			"message": "Đã có một lượt kết tinh đang chạy.",
		}

	var now := _now(now_unix)
	var cycle := int(_meta.get(CYCLE_KEY, 0)) + 1
	_meta[CYCLE_KEY] = cycle

	var last_result := _last_result(state)
	state = {
		"status": String(STATUS_RUNNING),
		"stage": STAGE_ONE,
		"element_id": String(_element_id),
		"pet_stage_at_start": _pet_stage,
		"started_at_unix": now,
		"stage_started_at_unix": now,
		"finish_at_unix": now + _stage_duration(STAGE_ONE),
		"roll_seed": _seed_for_cycle(cycle, now),
		"cycle": cycle,
		"last_result": last_result,
	}
	_meta[STATE_KEY] = state

	return {
		"ok": true,
		"message": "Đã bắt đầu kết tinh nguyên tố.",
		"state": snapshot(now),
	}


func cancel(
	now_unix: int = -1
) -> Dictionary:
	_ensure_state()
	var state := _state()

	if StringName(state.get("status", "")) != STATUS_RUNNING:
		return {
			"ok": false,
			"message": "Không có lượt kết tinh để hủy.",
		}

	var last_result := _last_result(state)
	var cycle := int(state.get("cycle", _meta.get(CYCLE_KEY, 0)))
	_meta[STATE_KEY] = _idle_state(
		last_result,
		cycle
	)
	var idle := _state()
	idle["cancelled_at_unix"] = _now(now_unix)
	_meta[STATE_KEY] = idle

	return {
		"ok": true,
		"message": "Đã hủy kết tinh. Tiến độ lượt này bị mất.",
		"state": snapshot(now_unix),
	}


func process(
	now_unix: int = -1
) -> Dictionary:
	_ensure_state()
	var now := _now(now_unix)
	var state := _state()
	var rewards: Array[Dictionary] = []
	var changed := false
	var transitions := 0

	while (
		StringName(state.get("status", "")) == STATUS_RUNNING
		and now >= int(state.get("finish_at_unix", 0))
		and transitions < 3
	):
		transitions += 1
		var stage := int(state.get("stage", STAGE_ONE))
		var stage_finished_at := int(state.get("finish_at_unix", now))

		if stage < STAGE_THREE:
			if _should_advance(state, stage):
				var next_stage := stage + 1
				state["stage"] = next_stage
				state["stage_started_at_unix"] = stage_finished_at
				state["finish_at_unix"] = (
					stage_finished_at
					+ _stage_duration(next_stage)
				)
				changed = true
				continue

			var item_type := (
				ItemGenerator.TYPE_FOOD
				if stage == STAGE_ONE
				else ItemGenerator.TYPE_GROWTH
			)
			var reward := _generator.generate_for_stage(
				item_type,
				_reward_seed(state, stage),
				_reward_pet_stage(state)
			)

			if reward.is_empty():
				break

			_annotate_reward(
				reward,
				stage,
				state
			)
			rewards.append(reward)
			_complete(
				state,
				reward,
				stage,
				stage_finished_at
			)
			changed = true
			break

		var gene_reward := _generate_gene_reward(
			state,
			stage
		)

		if gene_reward.is_empty():
			break

		_annotate_reward(
			gene_reward,
			STAGE_THREE,
			state
		)
		rewards.append(gene_reward)
		_complete(
			state,
			gene_reward,
			STAGE_THREE,
			stage_finished_at
		)
		changed = true
		break

	_meta[STATE_KEY] = state

	var message := ""
	if not rewards.is_empty():
		message = (
			"Kết tinh hoàn tất: "
			+ String(
				rewards[0].get(
					"display_name",
					"Vật phẩm"
				)
			)
		)
	elif changed:
		message = (
			"Kết tinh đã tiến sang giai đoạn "
			+ str(state.get("stage", STAGE_ONE))
			+ "."
		)

	return {
		"changed": changed,
		"rewards": rewards,
		"message": message,
		"state": snapshot(now),
	}


func snapshot(
	now_unix: int = -1
) -> Dictionary:
	_ensure_state()
	var now := _now(now_unix)
	var state := _state()
	var running := (
		StringName(state.get("status", ""))
		== STATUS_RUNNING
	)
	var stage := int(
		state.get(
			"stage",
			0
		)
	)
	var finish_at := int(
		state.get(
			"finish_at_unix",
			0
		)
	)
	var remaining := (
		maxi(0, finish_at - now)
		if running
		else 0
	)

	return {
		"status": String(
			state.get(
				"status",
				String(STATUS_IDLE)
			)
		),
		"running": running,
		"stage": stage,
		"element_id": (
			String(
				_state_element(state)
			)
			if running
			else String(_element_id)
		),
		"started_at_unix": int(
			state.get(
				"started_at_unix",
				0
			)
		),
		"stage_started_at_unix": int(
			state.get(
				"stage_started_at_unix",
				0
			)
		),
		"finish_at_unix": finish_at,
		"remaining_seconds": remaining,
		"stage_duration_seconds": (
			_stage_duration(stage)
			if running
			else 0
		),
		"cycle": int(
			state.get(
				"cycle",
				_meta.get(CYCLE_KEY, 0)
			)
		),
		"last_result": _last_result(state),
	}


func _generate_gene_reward(
	state: Dictionary,
	stage: int
) -> Dictionary:
	if (
		_generator == null
		or _gene_definitions.is_empty()
	):
		return {}

	var candidates: Array[GeneDefinition] = []

	for definition in _gene_definitions:
		if (
			_gene_policy == null
			or _gene_policy.can_accept_gene(
				_reward_pet_stage(state),
				definition.locus()
			)
		):
			candidates.append(definition)

	if candidates.is_empty():
		for definition in _gene_definitions:
			candidates.append(definition)

	var seed_value := _reward_seed(
		state,
		stage
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var definition := candidates[
		rng.randi_range(
			0,
			candidates.size() - 1
		)
	]

	var reward := _generator.generate_gene(
		definition,
		seed_value
	)

	if reward.is_empty():
		return {}

	var tags_value: Variant = reward.get(
		"influence_tags",
		{}
	)
	var tags: Dictionary = (
		(tags_value as Dictionary).duplicate(true)
		if typeof(tags_value) == TYPE_DICTIONARY
		else {}
	)
	tags[
		"element_" + String(
			_state_element(state)
		)
	] = 1.0
	reward["influence_tags"] = tags

	return reward


func _annotate_reward(
	item: Dictionary,
	stage: int,
	state: Dictionary
) -> void:
	item["source"] = "element_crystallization"
	item["crystallization_stage"] = stage
	item["crystallization_element"] = String(
		_state_element(state)
	)


func _complete(
	state: Dictionary,
	item: Dictionary,
	stage: int,
	completed_at_unix: int
) -> void:
	var reward_element := _state_element(state)
	state["status"] = String(STATUS_IDLE)
	state["stage"] = 0
	state["element_id"] = String(_element_id)
	state["pet_stage_at_start"] = 0
	state["stage_started_at_unix"] = 0
	state["finish_at_unix"] = 0
	state["last_result"] = {
		"uid": String(item.get("uid", "")),
		"display_name": String(
			item.get(
				"display_name",
				"Vật phẩm"
			)
		),
		"item_type": String(
			item.get(
				"item_type",
				""
			)
		),
		"element_id": String(reward_element),
		"crystallization_stage": stage,
		"completed_at_unix": completed_at_unix,
	}


func _should_advance(
	state: Dictionary,
	stage: int
) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = _mix_text(
		int(state.get("roll_seed", 1)),
		"advance:" + str(stage)
	)
	return rng.randf() < ADVANCE_CHANCE


func _reward_seed(
	state: Dictionary,
	stage: int
) -> int:
	return _mix_text(
		int(state.get("roll_seed", 1)),
		"reward:" + str(stage)
	)


func _seed_for_cycle(
	cycle: int,
	now_unix: int
) -> int:
	var value := maxi(
		1,
		posmod(
			_run_id,
			SEED_MODULUS
		)
	)
	value = _mix_int(value, cycle)
	value = _mix_int(value, now_unix)
	value = _mix_text(
		value,
		String(_element_id)
	)
	return maxi(1, value)


func _mix_int(
	current: int,
	input_value: int
) -> int:
	return posmod(
		current * 1103515245
		+ input_value * 12345
		+ 1013904223,
		SEED_MODULUS
	)


func _mix_text(
	current: int,
	value: String
) -> int:
	var result := maxi(
		1,
		posmod(
			current,
			SEED_MODULUS
		)
	)

	for index in range(value.length()):
		result = _mix_int(
			result,
			value.unicode_at(index)
		)

	return maxi(1, result)


func _reward_pet_stage(
	state: Dictionary
) -> int:
	return maxi(
		1,
		int(
			state.get(
				"pet_stage_at_start",
				_pet_stage
			)
		)
	)


func _state_element(
	state: Dictionary
) -> StringName:
	var value := StringName(
		state.get(
			"element_id",
			String(_element_id)
		)
	)

	if String(value).is_empty():
		return _element_id

	return value


func _stage_duration(
	stage: int
) -> int:
	return int(
		STAGE_DURATIONS.get(
			stage,
			0
		)
	)


func _now(
	now_unix: int
) -> int:
	if now_unix >= 0:
		return now_unix

	return int(
		Time.get_unix_time_from_system()
	)


func _normalize_element(
	element_id: StringName
) -> StringName:
	var normalized := StringName(
		String(element_id)
			.strip_edges()
			.to_lower()
			.replace(" ", "_")
	)

	if String(normalized).is_empty():
		return &"neutral"

	return normalized


func _ensure_state() -> void:
	var value: Variant = _meta.get(
		STATE_KEY,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		_meta[STATE_KEY] = _idle_state()
		return

	var state := value as Dictionary
	var status := StringName(
		state.get(
			"status",
			""
		)
	)

	if (
		status != STATUS_IDLE
		and status != STATUS_RUNNING
	):
		_meta[STATE_KEY] = _idle_state(
			_last_result(state),
			int(
				state.get(
					"cycle",
					_meta.get(CYCLE_KEY, 0)
				)
			)
		)
		return

	if status == STATUS_RUNNING:
		var stage := int(
			state.get(
				"stage",
				0
			)
		)

		if (
			stage < STAGE_ONE
			or stage > STAGE_THREE
			or int(
				state.get(
					"finish_at_unix",
					0
				)
			) <= 0
			or int(
				state.get(
					"roll_seed",
					0
				)
			) <= 0
		):
			_meta[STATE_KEY] = _idle_state(
				_last_result(state),
				int(
					state.get(
						"cycle",
						_meta.get(CYCLE_KEY, 0)
					)
				)
			)


func _state() -> Dictionary:
	var value: Variant = _meta.get(
		STATE_KEY,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return value as Dictionary


func _last_result(
	state: Dictionary
) -> Dictionary:
	var value: Variant = state.get(
		"last_result",
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func _idle_state(
	last_result: Dictionary = {},
	cycle: int = 0
) -> Dictionary:
	return {
		"status": String(STATUS_IDLE),
		"stage": 0,
		"element_id": String(_element_id),
		"pet_stage_at_start": 0,
		"started_at_unix": 0,
		"stage_started_at_unix": 0,
		"finish_at_unix": 0,
		"roll_seed": 0,
		"cycle": maxi(
			cycle,
			int(
				_meta.get(
					CYCLE_KEY,
					0
				)
			)
		),
		"last_result": last_result.duplicate(true),
	}
