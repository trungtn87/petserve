class_name InventoryService
extends RefCounted


var _meta: Dictionary = {}


func setup(meta: Dictionary) -> void:
	_meta = meta

	if not _meta.has("inventory"):
		_meta["inventory"] = []


func add_items(items: Array[Dictionary]) -> void:
	var stored: Array = _meta.get("inventory", [])

	for item in items:
		if item.is_empty():
			continue

		stored.append(item.duplicate(true))

	_meta["inventory"] = stored


func list_items(filter_type: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stored: Array = _meta.get("inventory", [])

	for raw_item in stored:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item := raw_item as Dictionary

		if not filter_type.is_empty():
			if StringName(item.get("item_type", "")) != filter_type:
				continue

		result.append(item.duplicate(true))

	result.reverse()

	return result


func get_item(uid: String) -> Dictionary:
	var stored: Array = _meta.get("inventory", [])

	for raw_item in stored:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item := raw_item as Dictionary

		if String(item.get("uid", "")) == uid:
			return item.duplicate(true)

	return {}


func remove_item(uid: String) -> bool:
	var stored: Array = _meta.get("inventory", [])

	for index in range(stored.size()):
		var raw_item = stored[index]

		if typeof(raw_item) != TYPE_DICTIONARY:
			continue

		var item := raw_item as Dictionary

		if String(item.get("uid", "")) != uid:
			continue

		stored.remove_at(index)
		_meta["inventory"] = stored
		return true

	return false


func count() -> int:
	return (_meta.get("inventory", []) as Array).size()


func can_use_in_infant(item: Dictionary) -> bool:
	if String(item.get("usable_stage", "")) != "infant":
		return false

	var item_type := StringName(item.get("item_type", ""))

	return (
		item_type == ItemGenerator.TYPE_FOOD
		or item_type == ItemGenerator.TYPE_GROWTH
	)
