class_name ChestService
extends RefCounted


const CHEST_HATCH: StringName = &"hatch"
const CHEST_DAILY: StringName = &"daily"
const CHEST_EVOLUTION: StringName = &"evolution"
const CHEST_INFANT_ACTIVITY: StringName = &"infant_activity"
const CHEST_STAGE_ACTIVITY: StringName = &"stage_activity"

const STAGE2_ACTIVITY_REWARD_COUNT: int = 4


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


func ensure_daily_chest(
	stage_index: int = 1
) -> bool:
	var date := Time.get_date_dict_from_system()
	var day_key := (
		"%04d-%02d-%02d"
		% [
			int(date.get("year", 0)),
			int(date.get("month", 0)),
			int(date.get("day", 0)),
		]
	)
	var uid := "daily_%s" % day_key
	var queue: Array = _meta.get(
		"chest_queue",
		[]
	)

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest := raw_chest as Dictionary

		if String(
			chest.get(
				"uid",
				""
			)
		) == uid:
			return true

	queue.append({
		"uid": uid,
		"chest_type": String(CHEST_DAILY),
		"day_key": day_key,
		"stage_index": clampi(
			stage_index,
			1,
			StageLifecycle.FINAL_STAGE
		),
		"opened": false,
	})
	_meta["chest_queue"] = queue
	return true


func ensure_evolution_chest(
	run_id: int,
	from_stage: int,
	to_stage: int
) -> bool:
	if (
		from_stage < 1
		or to_stage != from_stage + 1
		or to_stage > StageLifecycle.FINAL_STAGE
	):
		return false

	var uid := (
		"evolution_%s_%s_%s"
		% [
			run_id,
			from_stage,
			to_stage,
		]
	)
	var queue: Array = _meta.get(
		"chest_queue",
		[]
	)

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest := raw_chest as Dictionary

		if String(
			chest.get(
				"uid",
				""
			)
		) == uid:
			return true

	queue.append({
		"uid": uid,
		"chest_type": String(CHEST_EVOLUTION),
		"run_id": run_id,
		"from_stage": from_stage,
		"to_stage": to_stage,
		"opened": false,
	})
	_meta["chest_queue"] = queue
	return true


func ensure_infant_activity_chest(
	run_id: int,
	game_id: String,
	reward_index: int
) -> bool:
	if reward_index <= 0:
		return false

	var queue: Array = _meta.get("chest_queue", [])
	var uid := "infant_activity_%s_%s_%s" % [
		run_id,
		game_id,
		reward_index,
	]

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if String(chest.get("uid", "")) == uid:
			return true

	queue.append({
		"uid": uid,
		"chest_type": String(CHEST_INFANT_ACTIVITY),
		"run_id": run_id,
		"game_id": game_id,
		"reward_index": reward_index,
		"opened": false,
	})

	_meta["chest_queue"] = queue
	return true


func ensure_stage_activity_chest(
	run_id: int,
	stage_index: int,
	game_id: String,
	reward_index: int,
	reward_tier: int
) -> bool:
	if (
		stage_index < 2
		or reward_index <= 0
	):
		return false

	var queue: Array = _meta.get("chest_queue", [])
	var tier := clampi(reward_tier, 1, 4)
	var uid := "stage_activity_%s_%s_%s_%s" % [
		run_id,
		stage_index,
		game_id,
		reward_index,
	]

	for raw_chest in queue:
		if typeof(raw_chest) != TYPE_DICTIONARY:
			continue

		var chest: Dictionary = raw_chest

		if String(chest.get("uid", "")) == uid:
			return true

	queue.append({
		"uid": uid,
		"chest_type": String(CHEST_STAGE_ACTIVITY),
		"run_id": run_id,
		"stage_index": stage_index,
		"game_id": game_id,
		"reward_index": reward_index,
		"reward_tier": tier,
		"guaranteed_gene": (
			stage_index == 2
			and reward_index
				== _guaranteed_stage_gene_reward_index(
					run_id,
					stage_index
				)
		),
		"opened": false,
	})

	_meta["chest_queue"] = queue
	return true


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
		CHEST_DAILY:
			return _roll_daily_chest(chest)
		CHEST_EVOLUTION:
			return _roll_evolution_chest(chest)
		CHEST_INFANT_ACTIVITY:
			return _roll_infant_activity_chest(chest)
		CHEST_STAGE_ACTIVITY:
			return _roll_stage_activity_chest(chest)
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
		ItemGenerator.TYPE_GENE,
	]

	var rewards: Array[Dictionary] = []

	for index in range(slot_types.size()):
		var slot_seed := absi(hash(
			"%s:%s" % [chest_seed, index]
		))

		if slot_seed == 0:
			slot_seed = index + 1

		var item := (
			_generate_gene_for_stage(
				1,
				slot_seed
			)
			if slot_types[index] == ItemGenerator.TYPE_GENE
			else _generator.generate(
				slot_types[index],
				slot_seed
			)
		)

		if not item.is_empty():
			rewards.append(item)

	return rewards


func _roll_daily_chest(
	chest: Dictionary
) -> Array[Dictionary]:
	var uid := String(
		chest.get(
			"uid",
			"daily"
		)
	)
	var seed_value := absi(
		hash(uid)
	)

	if seed_value == 0:
		seed_value = 1

	var rewards: Array[Dictionary] = []

	for index in range(2):
		var item_type: StringName = (
			ItemGenerator.TYPE_FOOD
			if index == 0
			else ItemGenerator.TYPE_GROWTH
		)
		var item_seed := absi(
			hash(
				"%s:%s"
				% [
					seed_value,
					index,
				]
			)
		)

		if item_seed == 0:
			item_seed = seed_value + index + 1

		var item := _generator.generate_for_stage(
			item_type,
			item_seed,
			int(
				chest.get(
					"stage_index",
					1
				)
			)
		)

		if not item.is_empty():
			rewards.append(
				item
			)

	return rewards


func _roll_evolution_chest(
	chest: Dictionary
) -> Array[Dictionary]:
	var uid := String(
		chest.get(
			"uid",
			"evolution"
		)
	)
	var to_stage := int(
		chest.get(
			"to_stage",
			1
		)
	)
	var seed_value := absi(
		hash(uid)
	)

	if seed_value == 0:
		seed_value = 1

	var rewards: Array[Dictionary] = []
	var item_types: Array[StringName] = [
		ItemGenerator.TYPE_FOOD,
		ItemGenerator.TYPE_GROWTH,
		ItemGenerator.TYPE_GENE,
	]

	for index in range(
		item_types.size()
	):
		var item_seed := absi(
			hash(
				"%s:%s:%s"
				% [
					seed_value,
					to_stage,
					index,
				]
			)
		)

		if item_seed == 0:
			item_seed = seed_value + index + 1

		var item_type := item_types[index]
		var item := (
			_generate_gene_for_stage(
				to_stage,
				item_seed
			)
			if item_type == ItemGenerator.TYPE_GENE
			else _generator.generate_for_stage(
				item_type,
				item_seed,
				to_stage
			)
		)

		if (
			item.is_empty()
			and item_type == ItemGenerator.TYPE_GENE
		):
			item = _generator.generate(
				ItemGenerator.TYPE_FUTURE_FRAGMENT,
				item_seed
			)

		if not item.is_empty():
			rewards.append(
				item
			)

	return rewards


func _roll_infant_activity_chest(
	chest: Dictionary
) -> Array[Dictionary]:
	var uid := String(chest.get("uid", "infant_activity"))
	var channel := StringName("activity_%s" % uid)
	var chest_seed := 0

	if RandomManager.current_seed > 0:
		chest_seed = RandomManager.derive_seed(channel)
	else:
		chest_seed = abs(hash(uid))

	if chest_seed == 0:
		chest_seed = 1

	var rng := RandomNumberGenerator.new()
	rng.seed = chest_seed

	var item_type: StringName = (
		ItemGenerator.TYPE_FOOD
		if rng.randf() <= 0.72
		else ItemGenerator.TYPE_GROWTH
	)

	var item_seed := absi(hash("%s:item" % chest_seed))

	if item_seed == 0:
		item_seed = chest_seed + 1

	var item := _generator.generate_basic_infant(
		item_type,
		item_seed
	)

	if item.is_empty():
		return []

	return [item]


func _roll_stage_activity_chest(
	chest: Dictionary
) -> Array[Dictionary]:
	var uid := String(
		chest.get(
			"uid",
			"stage_activity"
		)
	)
	var stage_index := int(
		chest.get(
			"stage_index",
			2
		)
	)
	var run_id := int(
		chest.get(
			"run_id",
			0
		)
	)
	var reward_index := int(
		chest.get(
			"reward_index",
			0
		)
	)
	var guaranteed_gene := bool(
		chest.get(
			"guaranteed_gene",
			(
				stage_index == 2
				and reward_index
					== _guaranteed_stage_gene_reward_index(
						run_id,
						stage_index
					)
			)
		)
	)
	var tier := clampi(
		int(
			chest.get(
				"reward_tier",
				1
			)
		),
		1,
		4
	)
	var channel := StringName(
		"stage_activity_%s"
		% uid
	)
	var chest_seed := 0

	if RandomManager.current_seed > 0:
		chest_seed = RandomManager.derive_seed(
			channel
		)
	else:
		chest_seed = abs(
			hash(uid)
		)

	if chest_seed == 0:
		chest_seed = 1

	var rng := RandomNumberGenerator.new()
	rng.seed = chest_seed

	var reward_count := (
		2
		if tier >= 3
		else 1
	)
	var fragment_chance: float = float({
		1: 0.00,
		2: 0.08,
		3: 0.16,
		4: 0.24,
	}.get(
		tier,
		0.0
	))
	var rewards: Array[Dictionary] = []
	var guaranteed_gene_slot := -1

	if guaranteed_gene:
		guaranteed_gene_slot = (
			0
			if reward_count <= 1
			else rng.randi_range(
				0,
				reward_count - 1
			)
		)

	for index in range(
		reward_count
	):
		var item_type: StringName

		if index == guaranteed_gene_slot:
			item_type = ItemGenerator.TYPE_GENE
		else:
			var roll := rng.randf()

			if roll <= fragment_chance:
				item_type = (
					ItemGenerator.TYPE_FUTURE_FRAGMENT
				)
			elif roll <= fragment_chance + 0.42:
				item_type = (
					ItemGenerator.TYPE_GROWTH
				)
			else:
				item_type = (
					ItemGenerator.TYPE_FOOD
				)

		var item_seed := absi(
			hash(
				"%s:%s:%s"
				% [
					chest_seed,
					tier,
					index,
				]
			)
		)

		if item_seed == 0:
			item_seed = (
				chest_seed
				+ index
				+ 1
			)

		var item := (
			_generate_gene_for_stage(
				stage_index,
				item_seed
			)
			if item_type == ItemGenerator.TYPE_GENE
			else _generator.generate_for_stage(
				item_type,
				item_seed,
				stage_index
			)
		)

		if (
			item_type == ItemGenerator.TYPE_GENE
			and item.is_empty()
		):
			push_error(
				"ChestService: Stage 2 guaranteed Gene generation failed."
			)
			return []

		if not item.is_empty():
			rewards.append(
				item
			)

	return rewards


func _guaranteed_stage_gene_reward_index(
	run_id: int,
	stage_index: int
) -> int:
	if stage_index != 2:
		return -1

	# Stable for the same life, varied across lineage seeds.
	# Do not use the current clock or chest-open order: reload must not reroll it.
	var mixed_seed := (
		run_id * 1103515245
		+ stage_index * 12345
		+ 1013904223
	)

	return (
		posmod(
			mixed_seed,
			STAGE2_ACTIVITY_REWARD_COUNT
		)
		+ 1
	)


func _generate_gene_for_stage(
	stage_index: int,
	seed_value: int
) -> Dictionary:
	var policy := StageGenePolicy.load_default()

	if policy == null:
		return {}

	var definitions := GeneCatalog.new().load_default()
	var candidates: Array[GeneDefinition] = []

	for definition in definitions:
		if (
			definition != null
			and policy.can_accept_gene(
				stage_index,
				definition.locus()
			)
		):
			candidates.append(
				definition
			)

	if candidates.is_empty():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = max(
		1,
		abs(
			seed_value
		)
	)
	var definition := candidates[
		rng.randi_range(
			0,
			candidates.size() - 1
		)
	]

	return _generator.generate_gene(
		definition,
		seed_value
	)


func _reward_uids(rewards: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []

	for reward in rewards:
		result.append(String(reward.get("uid", "")))

	return result
