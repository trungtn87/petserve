class_name ElementCrystallizationService
extends RefCounted

const STATE_KEY: String = "element_crystallization"
const CYCLE_KEY: String = "element_crystallization_cycles"
const STATUS_IDLE: StringName = &"idle"
const STATUS_RUNNING: StringName = &"running"
const STAGE_ONE: int = 1
const STAGE_TWO: int = 2
const STAGE_THREE: int = 3
const MAX_SLOTS: int = 4
const STAGE_DURATIONS: Dictionary = {STAGE_ONE: 60 * 60, STAGE_TWO: 3 * 60 * 60, STAGE_THREE: 8 * 60 * 60}
const ADVANCE_CHANCE: float = 0.30
const SEED_MODULUS: int = 2147483647

var _meta: Dictionary = {}
var _generator: ItemGenerator
var _gene_definitions: Array[GeneDefinition] = []
var _gene_policy: StageGenePolicy
var _run_id: int = 0
var _pet_stage: int = 1
var _element_id: StringName = &"neutral"

func setup(meta: Dictionary, generator: ItemGenerator, gene_definitions: Array[GeneDefinition], gene_policy: StageGenePolicy, run_id: int, pet_stage: int, element_id: StringName) -> void:
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

func update_context(pet_stage: int, element_id: StringName) -> void:
    # Chỉ cập nhật số slot có thể dùng cho lượt MỚI.
    # Các slot đang chạy giữ nguyên pet_stage_at_start/element_id/timing.
    _pet_stage = maxi(1, pet_stage)
    _element_id = _normalize_element(element_id)
    _ensure_state()

func unlocked_slots() -> int:
    return clampi(_pet_stage, 1, MAX_SLOTS)

func start(now_unix: int = -1) -> Dictionary:
    _ensure_state()
    var state := _state()
    var slots := _slots(state)
    var capacity := unlocked_slots()
    var now := _now(now_unix)
    var started_slots: Array[int] = []
    for slot_index in range(mini(capacity, slots.size())):
        if StringName((slots[slot_index] as Dictionary).get("status", "")) != STATUS_IDLE:
            continue
        var cycle := int(_meta.get(CYCLE_KEY, 0)) + 1
        _meta[CYCLE_KEY] = cycle
        slots[slot_index] = _running_slot(slot_index, cycle, now)
        started_slots.append(slot_index)
    if started_slots.is_empty():
        return {"ok": false, "message": "Tất cả ô kết tinh đang chạy.", "state": snapshot(now)}
    state["slots"] = slots
    _meta[STATE_KEY] = state
    return {"ok": true, "started_slots": started_slots, "message": "Đã bắt đầu %d ô kết tinh." % started_slots.size(), "state": snapshot(now)}

func cancel(now_unix: int = -1, slot_index: int = -1) -> Dictionary:
    _ensure_state()
    var state := _state()
    var slots := _slots(state)
    var target := slot_index
    if target < 0:
        target = _first_running_slot(slots)
    if target < 0 or target >= slots.size() or StringName((slots[target] as Dictionary).get("status", "")) != STATUS_RUNNING:
        return {"ok": false, "message": "Không có lượt kết tinh để hủy.", "state": snapshot(now_unix)}
    var slot := slots[target] as Dictionary
    var last_result := _last_result(slot)
    var cycle := int(slot.get("cycle", 0))
    var idle := _idle_slot(target, last_result, cycle)
    idle["cancelled_at_unix"] = _now(now_unix)
    slots[target] = idle
    state["slots"] = slots
    _meta[STATE_KEY] = state
    return {"ok": true, "slot_index": target, "message": "Đã hủy kết tinh ở ô %d. Tiến độ lượt này bị mất." % (target + 1), "state": snapshot(now_unix)}

func process(now_unix: int = -1) -> Dictionary:
    _ensure_state()
    var now := _now(now_unix)
    var state := _state()
    var slots := _slots(state)
    var rewards: Array[Dictionary] = []
    var changed := false
    for index in range(slots.size()):
        var slot := slots[index] as Dictionary
        var result := _process_slot(slot, now)
        if bool(result.get("changed", false)):
            changed = true
        var reward_value: Variant = result.get("reward", {})
        if typeof(reward_value) == TYPE_DICTIONARY and not (reward_value as Dictionary).is_empty():
            rewards.append((reward_value as Dictionary).duplicate(true))
        slots[index] = slot
    state["slots"] = slots
    _meta[STATE_KEY] = state
    var message := ""
    if not rewards.is_empty():
        message = "Kết tinh hoàn tất: %d vật phẩm." % rewards.size()
    elif changed:
        message = "Kết tinh đã chuyển giai đoạn."
    return {"changed": changed, "rewards": rewards, "message": message, "state": snapshot(now)}

func snapshot(now_unix: int = -1) -> Dictionary:
    _ensure_state()
    var now := _now(now_unix)
    var state := _state()
    var slots := _slots(state)
    var slot_snapshots: Array[Dictionary] = []
    var running_count := 0
    var primary: Dictionary = {}
    var last_result: Dictionary = {}
    for index in range(slots.size()):
        var slot := slots[index] as Dictionary
        var snap := _slot_snapshot(slot, now)
        slot_snapshots.append(snap)
        if bool(snap.get("running", false)):
            running_count += 1
            if primary.is_empty():
                primary = snap
        var candidate := _last_result(slot)
        if not candidate.is_empty() and (last_result.is_empty() or int(candidate.get("completed_at_unix", 0)) > int(last_result.get("completed_at_unix", 0))):
            last_result = candidate
    var capacity := unlocked_slots()
    var result := {
        "unlocked_slots": capacity,
        "max_slots": MAX_SLOTS,
        "running_count": running_count,
        "available_slots": maxi(0, capacity - running_count),
        "slots": slot_snapshots,
        "last_result": last_result,
        "element_id": String(_element_id),
        "running": running_count > 0,
        "status": String(STATUS_RUNNING if running_count > 0 else STATUS_IDLE),
        "stage": 0,
        "started_at_unix": 0,
        "stage_started_at_unix": 0,
        "finish_at_unix": 0,
        "remaining_seconds": 0,
        "stage_duration_seconds": 0,
        "cycle": int(_meta.get(CYCLE_KEY, 0)),
    }
    if not primary.is_empty():
        for key in ["status", "running", "stage", "element_id", "started_at_unix", "stage_started_at_unix", "finish_at_unix", "remaining_seconds", "stage_duration_seconds", "cycle"]:
            result[key] = primary.get(key, result.get(key))
    return result

func _process_slot(slot: Dictionary, now: int) -> Dictionary:
    var changed := false
    var transitions := 0
    while StringName(slot.get("status", "")) == STATUS_RUNNING and now >= int(slot.get("finish_at_unix", 0)) and transitions < 3:
        transitions += 1
        var stage := int(slot.get("stage", STAGE_ONE))
        var stage_finished_at := int(slot.get("finish_at_unix", now))
        if stage < STAGE_THREE:
            if _should_advance(slot, stage):
                var next_stage := stage + 1
                slot["stage"] = next_stage
                slot["stage_started_at_unix"] = stage_finished_at
                slot["finish_at_unix"] = stage_finished_at + _stage_duration(next_stage)
                changed = true
                continue
            var item_type := ItemGenerator.TYPE_FOOD if stage == STAGE_ONE else ItemGenerator.TYPE_GROWTH
            var reward := _generator.generate_for_stage(item_type, _reward_seed(slot, stage), _reward_pet_stage(slot))
            if reward.is_empty():
                break
            _annotate_reward(reward, stage, slot)
            _complete(slot, reward, stage, stage_finished_at)
            return {"changed": true, "reward": reward}
        var gene_reward := _generate_gene_reward(slot, stage)
        if gene_reward.is_empty():
            break
        _annotate_reward(gene_reward, STAGE_THREE, slot)
        _complete(slot, gene_reward, STAGE_THREE, stage_finished_at)
        return {"changed": true, "reward": gene_reward}
    return {"changed": changed, "reward": {}}

func _generate_gene_reward(state: Dictionary, stage: int) -> Dictionary:
    if _generator == null or _gene_definitions.is_empty():
        return {}
    var candidates: Array[GeneDefinition] = []
    for definition in _gene_definitions:
        if _gene_policy == null or _gene_policy.can_accept_gene(_reward_pet_stage(state), definition.locus()):
            candidates.append(definition)
    if candidates.is_empty():
        for definition in _gene_definitions:
            candidates.append(definition)
    var seed_value := _reward_seed(state, stage)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var definition := candidates[rng.randi_range(0, candidates.size() - 1)]
    var reward := _generator.generate_gene(definition, seed_value)
    if reward.is_empty():
        return {}
    var tags_value: Variant = reward.get("influence_tags", {})
    var tags: Dictionary = (tags_value as Dictionary).duplicate(true) if typeof(tags_value) == TYPE_DICTIONARY else {}
    tags["element_" + String(_state_element(state))] = 1.0
    reward["influence_tags"] = tags
    return reward

func _annotate_reward(item: Dictionary, stage: int, state: Dictionary) -> void:
    item["source"] = "element_crystallization"
    item["crystallization_stage"] = stage
    item["crystallization_element"] = String(_state_element(state))
    item["crystallization_slot"] = int(state.get("slot_index", 0))

func _complete(state: Dictionary, item: Dictionary, stage: int, completed_at_unix: int) -> void:
    var reward_element := _state_element(state)
    var slot_index := int(state.get("slot_index", 0))
    var cycle := int(state.get("cycle", 0))
    var last := {"uid": String(item.get("uid", "")), "display_name": String(item.get("display_name", "Vật phẩm")), "item_type": String(item.get("item_type", "")), "element_id": String(reward_element), "crystallization_stage": stage, "crystallization_slot": slot_index, "completed_at_unix": completed_at_unix}
    state.clear()
    state.merge(_idle_slot(slot_index, last, cycle), true)

func _should_advance(state: Dictionary, stage: int) -> bool:
    var rng := RandomNumberGenerator.new()
    rng.seed = _mix_text(int(state.get("roll_seed", 1)), "advance:" + str(stage))
    return rng.randf() < ADVANCE_CHANCE

func _reward_seed(state: Dictionary, stage: int) -> int:
    return _mix_text(int(state.get("roll_seed", 1)), "reward:" + str(stage))

func _seed_for_cycle(cycle: int, now_unix: int, slot_index: int) -> int:
    var value := maxi(1, posmod(_run_id, SEED_MODULUS))
    value = _mix_int(value, cycle)
    value = _mix_int(value, now_unix)
    value = _mix_int(value, slot_index + 1)
    value = _mix_text(value, String(_element_id))
    return maxi(1, value)

func _mix_int(current: int, input_value: int) -> int:
    return posmod(current * 1103515245 + input_value * 12345 + 1013904223, SEED_MODULUS)

func _mix_text(current: int, value: String) -> int:
    var result := maxi(1, posmod(current, SEED_MODULUS))
    for index in range(value.length()):
        result = _mix_int(result, value.unicode_at(index))
    return maxi(1, result)

func _reward_pet_stage(state: Dictionary) -> int:
    return maxi(1, int(state.get("pet_stage_at_start", _pet_stage)))

func _state_element(state: Dictionary) -> StringName:
    var value := StringName(state.get("element_id", String(_element_id)))
    return _element_id if String(value).is_empty() else value

func _stage_duration(stage: int) -> int:
    return int(STAGE_DURATIONS.get(stage, 0))

func _now(now_unix: int) -> int:
    return now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())

func _normalize_element(element_id: StringName) -> StringName:
    var normalized := StringName(String(element_id).strip_edges().to_lower().replace(" ", "_"))
    return &"neutral" if String(normalized).is_empty() else normalized

func _ensure_state() -> void:
    var value: Variant = _meta.get(STATE_KEY, {})
    if typeof(value) != TYPE_DICTIONARY:
        _meta[STATE_KEY] = _new_state()
        return
    var state := value as Dictionary
    # Migration từ save cũ chỉ có một lượt kết tinh.
    if not state.has("slots"):
        var migrated := _new_state()
        var slots := _slots(migrated)
        var status := StringName(state.get("status", ""))
        if status == STATUS_RUNNING:
            var old := state.duplicate(true)
            old["slot_index"] = 0
            slots[0] = old
        else:
            slots[0] = _idle_slot(0, _last_result(state), int(state.get("cycle", _meta.get(CYCLE_KEY, 0))))
        migrated["slots"] = slots
        _meta[STATE_KEY] = migrated
        return
    var slots := _slots(state)
    while slots.size() < MAX_SLOTS:
        slots.append(_idle_slot(slots.size()))
    if slots.size() > MAX_SLOTS:
        slots.resize(MAX_SLOTS)
    for index in range(slots.size()):
        var slot := slots[index] as Dictionary
        slot["slot_index"] = index
        var status := StringName(slot.get("status", ""))
        if status != STATUS_IDLE and status != STATUS_RUNNING:
            slots[index] = _idle_slot(index, _last_result(slot), int(slot.get("cycle", 0)))
            continue
        if status == STATUS_RUNNING:
            var stage := int(slot.get("stage", 0))
            if stage < STAGE_ONE or stage > STAGE_THREE or int(slot.get("finish_at_unix", 0)) <= 0 or int(slot.get("roll_seed", 0)) <= 0:
                slots[index] = _idle_slot(index, _last_result(slot), int(slot.get("cycle", 0)))
    state["slots"] = slots
    _meta[STATE_KEY] = state

func _state() -> Dictionary:
    var value: Variant = _meta.get(STATE_KEY, {})
    return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

func _slots(state: Dictionary) -> Array:
    var value: Variant = state.get("slots", [])
    if typeof(value) != TYPE_ARRAY:
        return []
    return value as Array

func _last_result(state: Dictionary) -> Dictionary:
    var value: Variant = state.get("last_result", {})
    return (value as Dictionary).duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}

func _new_state() -> Dictionary:
    var slots: Array[Dictionary] = []
    for index in range(MAX_SLOTS):
        slots.append(_idle_slot(index))
    return {"version": 2, "slots": slots}

func _idle_slot(slot_index: int, last_result: Dictionary = {}, cycle: int = 0) -> Dictionary:
    return {"slot_index": slot_index, "status": String(STATUS_IDLE), "stage": 0, "element_id": String(_element_id), "pet_stage_at_start": 0, "started_at_unix": 0, "stage_started_at_unix": 0, "finish_at_unix": 0, "roll_seed": 0, "cycle": cycle, "last_result": last_result.duplicate(true)}

func _running_slot(slot_index: int, cycle: int, now: int) -> Dictionary:
    return {"slot_index": slot_index, "status": String(STATUS_RUNNING), "stage": STAGE_ONE, "element_id": String(_element_id), "pet_stage_at_start": _pet_stage, "started_at_unix": now, "stage_started_at_unix": now, "finish_at_unix": now + _stage_duration(STAGE_ONE), "roll_seed": _seed_for_cycle(cycle, now, slot_index), "cycle": cycle, "last_result": {}}

func _slot_snapshot(slot: Dictionary, now: int) -> Dictionary:
    var running := StringName(slot.get("status", "")) == STATUS_RUNNING
    var stage := int(slot.get("stage", 0))
    var finish_at := int(slot.get("finish_at_unix", 0))
    return {"slot_index": int(slot.get("slot_index", 0)), "status": String(slot.get("status", String(STATUS_IDLE))), "running": running, "stage": stage, "element_id": String(_state_element(slot)), "pet_stage_at_start": int(slot.get("pet_stage_at_start", 0)), "started_at_unix": int(slot.get("started_at_unix", 0)), "stage_started_at_unix": int(slot.get("stage_started_at_unix", 0)), "finish_at_unix": finish_at, "remaining_seconds": maxi(0, finish_at - now) if running else 0, "stage_duration_seconds": _stage_duration(stage) if running else 0, "cycle": int(slot.get("cycle", 0)), "last_result": _last_result(slot)}

func _first_idle_slot(slots: Array, capacity: int) -> int:
    for index in range(mini(capacity, slots.size())):
        if StringName((slots[index] as Dictionary).get("status", "")) == STATUS_IDLE:
            return index
    return -1

func _first_running_slot(slots: Array) -> int:
    for index in range(slots.size()):
        if StringName((slots[index] as Dictionary).get("status", "")) == STATUS_RUNNING:
            return index
    return -1
