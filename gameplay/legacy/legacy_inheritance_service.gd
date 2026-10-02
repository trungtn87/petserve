class_name LegacyInheritanceService
extends RefCounted


const SAVE_PATH: String = "user://legacy_inheritance_v1.json"
const CURRENT_SCHEMA: int = 3

const STATUS_PENDING: String = "pending"
const STATUS_BOUND: String = "bound"
const STATUS_CLAIMED: String = "claimed"


func prepare(
	source_identity: PetIdentity,
	items: Array = [],
	skill_id: StringName = &""
) -> Dictionary:
	if (
		source_identity == null
		or not source_identity.is_valid()
	):
		return _error(
			"Pet nguồn không hợp lệ."
		)

	var inherited_items: Array = []

	for raw_value in items:
		if typeof(raw_value) != TYPE_DICTIONARY:
			return _error(
				"Rương đồ kế thừa có vật phẩm không hợp lệ."
			)

		var item := (
			raw_value as Dictionary
		).duplicate(true)
		var uid := String(
			item.get(
				"uid",
				""
			)
		).strip_edges()
		var item_type := String(
			item.get(
				"item_type",
				""
			)
		).strip_edges()

		if uid.is_empty() or item_type.is_empty():
			return _error(
				"Rương đồ kế thừa có vật phẩm không hợp lệ."
			)

		inherited_items.append(
			item
		)

	var inherited_skill := String(
		skill_id
	).strip_edges()

	if (
		not inherited_skill.is_empty()
		and not PetSkillCatalog.is_valid(
			StringName(inherited_skill)
		)
	):
		return _error(
			"Kỹ năng kế thừa không hợp lệ."
		)

	var skill_token := (
		inherited_skill
		if not inherited_skill.is_empty()
		else "none"
	)
	var inheritance_id := (
		"%s:g%d:%ditems:%s"
		% [
			source_identity.pet_id(),
			source_identity.generation(),
			inherited_items.size(),
			skill_token,
		]
	)

	var data := {
		"schema": CURRENT_SCHEMA,
		"inheritance_id": inheritance_id,
		"status": STATUS_PENDING,
		"source_pet_id": source_identity.pet_id(),
		"source_generation": source_identity.generation(),
		"target_generation": source_identity.generation() + 1,
		"target_run_seed": 0,
		"items": inherited_items.duplicate(true),
		"skill_id": inherited_skill,
	}

	if not _save_data(
		data
	):
		return _error(
			"Không lưu được dữ liệu kế thừa."
		)

	return {
		"ok": true,
		"inheritance_id": inheritance_id,
		"target_generation": source_identity.generation() + 1,
		"has_items": not inherited_items.is_empty(),
		"has_item": not inherited_items.is_empty(),
		"item_count": inherited_items.size(),
		"items": inherited_items.duplicate(true),
		"item": (
			(inherited_items[0] as Dictionary).duplicate(true)
			if not inherited_items.is_empty()
			else {}
		),
		"has_skill": not inherited_skill.is_empty(),
		"skill_id": inherited_skill,
	}


func bind_to_run(
	run_seed: int
) -> Dictionary:
	if run_seed <= 0:
		return _error(
			"Run đời sau không hợp lệ."
		)

	var data := load_data()

	if data.is_empty():
		return {
			"ok": true,
			"has_legacy": false,
			"generation": 0,
		}

	var status := String(
		data.get(
			"status",
			""
		)
	)

	if status == STATUS_CLAIMED:
		return {
			"ok": true,
			"has_legacy": false,
			"generation": 0,
		}

	if status not in [
		STATUS_PENDING,
		STATUS_BOUND,
	]:
		return _error(
			"Trạng thái kế thừa không hợp lệ."
		)

	var bound_run := int(
		data.get(
			"target_run_seed",
			0
		)
	)

	if bound_run > 0 and bound_run != run_seed:
		return _error(
			"Dữ liệu kế thừa đã gắn với một đời khác."
		)

	data["status"] = STATUS_BOUND
	data["target_run_seed"] = run_seed

	if not _save_data(
		data
	):
		return _error(
			"Không gắn được kế thừa với đời mới."
		)

	var inherited_items := _items_from_data(
		data
	)
	var inherited_skill := String(
		data.get(
			"skill_id",
			""
		)
	)

	return {
		"ok": true,
		"has_legacy": true,
		"inheritance_id": String(
			data.get(
				"inheritance_id",
				""
			)
		),
		"generation": int(
			data.get(
				"target_generation",
				0
			)
		),
		"has_items": not inherited_items.is_empty(),
		"has_item": not inherited_items.is_empty(),
		"item_count": inherited_items.size(),
		"has_skill": (
			not inherited_skill.is_empty()
			and PetSkillCatalog.is_valid(
				StringName(inherited_skill)
			)
		),
		"skill_id": inherited_skill,
	}


func apply_pending_to_meta(
	meta: Dictionary,
	run_seed: int
) -> Dictionary:
	if run_seed <= 0:
		return {
			"applied": false,
		}

	var data := load_data()

	if (
		data.is_empty()
		or String(
			data.get(
				"status",
				""
			)
		) != STATUS_BOUND
		or int(
			data.get(
				"target_run_seed",
				0
			)
		) != run_seed
	):
		return {
			"applied": false,
		}

	var inheritance_id := String(
		data.get(
			"inheritance_id",
			""
		)
	)

	if inheritance_id.is_empty():
		return {
			"applied": false,
		}

	var inherited_skill := String(
		data.get(
			"skill_id",
			""
		)
	)

	if String(
		meta.get(
			"legacy_inheritance_id",
			""
		)
	) == inheritance_id:
		var existing_items_value: Variant = meta.get(
			"legacy_inherited_items",
			[]
		)
		var existing_count := 0

		if typeof(existing_items_value) == TYPE_ARRAY:
			existing_count = (
				existing_items_value as Array
			).size()
		elif typeof(
			meta.get(
				"legacy_inherited_item",
				{}
			)
		) == TYPE_DICTIONARY:
			var old_item := meta.get(
				"legacy_inherited_item",
				{}
			) as Dictionary
			if not old_item.is_empty():
				existing_count = 1

		return {
			"applied": true,
			"already_present": true,
			"inheritance_id": inheritance_id,
			"has_items": existing_count > 0,
			"has_item": existing_count > 0,
			"item_count": existing_count,
			"has_skill": not inherited_skill.is_empty(),
			"skill_id": inherited_skill,
		}

	var inherited_items := _items_from_data(
		data
	)
	var decorated_items: Array = []
	var stored_value: Variant = meta.get(
		"inventory",
		[]
	)
	var stored: Array = (
		(stored_value as Array).duplicate(true)
		if typeof(stored_value) == TYPE_ARRAY
		else []
	)

	for raw_value in inherited_items:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue

		var inherited_item := (
			raw_value as Dictionary
		).duplicate(true)

		inherited_item["legacy_inherited"] = true
		inherited_item["legacy_source_pet_id"] = String(
			data.get(
				"source_pet_id",
				""
			)
		)
		inherited_item["legacy_source_generation"] = int(
			data.get(
				"source_generation",
				0
			)
		)
		inherited_item["legacy_target_generation"] = int(
			data.get(
				"target_generation",
				0
			)
		)

		stored.append(
			inherited_item
		)
		decorated_items.append(
			inherited_item.duplicate(true)
		)

	meta["inventory"] = stored
	meta["legacy_inherited_items"] = (
		decorated_items.duplicate(true)
	)
	meta["legacy_inherited_item"] = (
		(decorated_items[0] as Dictionary).duplicate(true)
		if not decorated_items.is_empty()
		else {}
	)

	if (
		not inherited_skill.is_empty()
		and PetSkillCatalog.is_valid(
			StringName(inherited_skill)
		)
	):
		meta["legacy_inherited_skill_id"] = inherited_skill

	meta["legacy_inheritance_id"] = inheritance_id
	meta["legacy_source_pet_id"] = String(
		data.get(
			"source_pet_id",
			""
		)
	)
	meta["legacy_source_generation"] = int(
		data.get(
			"source_generation",
			0
		)
	)
	meta["legacy_generation"] = int(
		data.get(
			"target_generation",
			0
		)
	)

	return {
		"applied": true,
		"already_present": false,
		"inheritance_id": inheritance_id,
		"has_items": not decorated_items.is_empty(),
		"has_item": not decorated_items.is_empty(),
		"item_count": decorated_items.size(),
		"items": decorated_items.duplicate(true),
		"item": (
			(decorated_items[0] as Dictionary).duplicate(true)
			if not decorated_items.is_empty()
			else {}
		),
		"has_skill": not inherited_skill.is_empty(),
		"skill_id": inherited_skill,
	}


func mark_claimed(
	inheritance_id: String,
	run_seed: int
) -> bool:
	var data := load_data()

	if (
		data.is_empty()
		or inheritance_id.is_empty()
		or String(
			data.get(
				"inheritance_id",
				""
			)
		) != inheritance_id
		or int(
			data.get(
				"target_run_seed",
				0
			)
		) != run_seed
	):
		return false

	data["status"] = STATUS_CLAIMED
	data["claimed_run_seed"] = run_seed
	data["claimed_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	return _save_data(
		data
	)


func load_data() -> Dictionary:
	var data := AtomicJson.read(SAVE_PATH).duplicate(true)
	if data.is_empty():
		return {}
	var schema := int(
		data.get(
			"schema",
			0
		)
	)

	if schema == 1:
		data["skill_id"] = ""
		data = _migrate_single_item_schema(
			data
		)
	elif schema == 2:
		data = _migrate_single_item_schema(
			data
		)
	elif schema != CURRENT_SCHEMA:
		return {}

	if not data.has(
		"items"
	):
		data["items"] = []

	return data


func clear() -> bool:
	return AtomicJson.erase(SAVE_PATH)


func _migrate_single_item_schema(
	data: Dictionary
) -> Dictionary:
	var migrated := data.duplicate(true)
	var items: Array = []
	var item_value: Variant = migrated.get(
		"item",
		{}
	)

	if (
		typeof(item_value) == TYPE_DICTIONARY
		and not (
			item_value as Dictionary
		).is_empty()
	):
		items.append(
			(item_value as Dictionary).duplicate(true)
		)

	migrated.erase(
		"item"
	)
	migrated["items"] = items
	migrated["schema"] = CURRENT_SCHEMA
	return migrated


func _items_from_data(
	data: Dictionary
) -> Array:
	var result: Array = []
	var items_value: Variant = data.get(
		"items",
		[]
	)

	if typeof(items_value) != TYPE_ARRAY:
		return result

	for raw_value in items_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue
		result.append(
			(raw_value as Dictionary).duplicate(true)
		)

	return result


func _save_data(
	data: Dictionary
) -> bool:
	return AtomicJson.write(
		SAVE_PATH,
		data
	)


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
