class_name InventoryService
extends RefCounted


var _meta: Dictionary = {}


func setup(
	meta: Dictionary
) -> void:
	_meta = meta

	if not _meta.has(
		"inventory"
	):
		_meta["inventory"] = []


func add_items(
	items: Array[Dictionary]
) -> void:
	var stored: Array = _meta.get(
		"inventory",
		[]
	)

	for item in items:
		if item.is_empty():
			continue

		stored.append(
			item.duplicate(true)
		)

	_meta["inventory"] = stored


func list_items(
	filter_type: StringName = &""
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Array = _meta.get(
		"inventory",
		[]
	)

	for raw_item in stored:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item

		if not filter_type.is_empty():
			if StringName(
				item.get(
					"item_type",
					""
				)
			) != filter_type:
				continue

		result.append(
			item.duplicate(true)
		)

	result.reverse()
	return result


func get_item(
	uid: String
) -> Dictionary:
	var stored: Array = _meta.get(
		"inventory",
		[]
	)

	for raw_item in stored:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item

		if String(
			item.get(
				"uid",
				""
			)
		) == uid:
			return item.duplicate(true)

	return {}


func remove_item(
	uid: String
) -> bool:
	var stored: Array = _meta.get(
		"inventory",
		[]
	)

	for index in range(
		stored.size()
	):
		var raw_item = stored[index]

		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = raw_item

		if String(
			item.get(
				"uid",
				""
			)
		) != uid:
			continue

		stored.remove_at(
			index
		)
		_meta["inventory"] = stored
		return true

	return false


func count() -> int:
	var stored: Array = _meta.get(
		"inventory",
		[]
	)
	return stored.size()


func can_use_in_stage(
	item: Dictionary,
	stage_index: int
) -> bool:
	if stage_index < 1 or stage_index >= StageLifecycle.FINAL_STAGE:
		return false

	var item_type := StringName(
		item.get(
			"item_type",
			""
		)
	)

	if item_type == ItemGenerator.TYPE_GENE:
		if gene_policy == null:
			return false

		return gene_policy.can_accept_gene(
			stage_index,
			StringName(
				item.get(
					"gene_locus",
					""
				)
			)
		)

	if (
		item_type != ItemGenerator.TYPE_FOOD
		and item_type != ItemGenerator.TYPE_GROWTH
	):
		return false

	var usable_stage := String(
		item.get(
			"usable_stage",
			""
		)
	)

	# "infant" is the legacy M7 value. Food/Growth already represent
	# general growth resources, so old saved items remain usable in M8.
	return usable_stage in [
		"infant",
		"growth",
		"post_infant",
		"",
	]


func can_use_in_infant(
	item: Dictionary
) -> bool:
	return can_use_in_stage(
		item,
		1
	)
