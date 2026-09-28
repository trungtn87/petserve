class_name ChestService
extends RefCounted


const CHEST_HATCH: StringName = &"hatch"


var _meta: Dictionary = {}
var _generator: ItemGenerator


func setup(
	meta: Dictionary,
	generator: ItemGenerator
) -> void:
	_meta = meta
	_generator = generator

	if not _meta.has("chest_queue"):
		_meta["chest_queue"] = []


func ensure_hatch_chest(run_id: int) -> void:
	var queue: Array = _meta.get("chest_queue", [])

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if (
			StringName(chest.get("chest_type", "")) == CHEST_HATCH
			and int(chest.get("run_id", -1)) == run_id
		):
			return

	queue.append({
		"uid": "hatch_%s" % run_id,
		"chest_type": String(CHEST_HATCH),
		"run_id": run_id,
		"opened": false,
	})

	_meta["chest_queue"] = queue


func pending_count() -> int:
	var count := 0
	var queue: Array = _meta.get("chest_queue", [])

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if not bool(chest.get("opened", false)):
			count += 1

	return count


func peek_next() -> Dictionary:
	var queue: Array = _meta.get("chest_queue", [])

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if not bool(chest.get("opened", false)):
			return chest.duplicate(true)

	return {}


func open_next() -> Array[Dictionary]:
	var queue: Array = _meta.get("chest_queue", [])

	for index in range(queue.size()):
		var raw_chest = queue[index]

		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if bool(chest.get("opened", false)):
			continue

		var rewards := _roll_rewards(chest)

		chest["opened"] = true
		chest["opened_at_unix"] = int(Time.get_unix_time_from_system())
		chest["reward_uids"] = _reward_uids(rewards)
		queue[index] = chest
		_meta["chest_queue"] = queue

		return rewards

	return []


func _roll_rewards(chest: Dictionary) -> Array[Dictionary]:
	var chest_type := StringName(chest.get("chest_type", ""))

	match chest_type:
		CHEST_HATCH:
			return _roll_hatch_chest(chest)
		_:
			push_error("ChestService: unsupported chest: " + String(chest_type))
			return []


func _roll_hatch_chest(chest: Dictionary) -> Array[Dictionary]:
	var run_id := int(chest.get("run_id", 0))
	var channel := StringName("hatch_chest_%s" % run_id)
	var chest_seed := 0

	if RandomManager.current_seed > 0:
		chest_seed = RandomManager.derive_seed(channel)
	else:
		chest_seed = abs(hash("hatch:%s" % run_id))

	if chest_seed == 0:
		chest_seed = 1

	var slot_types: Array[StringName] = [
		ItemGenerator.TYPE_FOOD,
		ItemGenerator.TYPE_FOOD,
		ItemGenerator.TYPE_FOOD,
		ItemGenerator.TYPE_GROWTH,
		ItemGenerator.TYPE_GROWTH,
		ItemGenerator.TYPE_FUTURE_FRAGMENT,
	]

	var rewards: Array[Dictionary] = []

	for index in range(slot_types.size()):
		var slot_seed := abs(hash(
			"%s:%s" % [chest_seed, index]
		))

		if slot_seed == 0:
			slot_seed = index + 1

		var item := _generator.generate(
			slot_types[index],
			slot_seed
		)

		if not item.is_empty():
			rewards.append(item)

	return rewards


func _reward_uids(rewards: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []

	for reward in rewards:
		result.append(String(reward.get("uid", "")))

	return result
