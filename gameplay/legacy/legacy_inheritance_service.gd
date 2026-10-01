class_name LegacyInheritanceService
extends RefCounted


const SAVE_PATH: String = "user://legacy_inheritance_v1.json"
const CURRENT_SCHEMA: int = 2

const STATUS_PENDING: String = "pending"
const STATUS_BOUND: String = "bound"
const STATUS_CLAIMED: String = "claimed"


func prepare(
	source_identity: PetIdentity,
	item: Dictionary = {},
	skill_id: StringName = &""
) -> Dictionary:
	if (
		source_identity == null
		or not source_identity.is_valid()
	):
		return _error(
			"Pet nguồn không hợp lệ."
		)

	var inherited_item: Dictionary = {}

	if not item.is_empty():
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
				"Item kế thừa không hợp lệ."
			)

		inherited_item = item.duplicate(
			true
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

	var item_uid := String(
		inherited_item.get(
			"uid",
			"none"
		)
	)
	var skill_token := (
		inherited_skill
		if not inherited_skill.is_empty()
		else "none"
	)
	var inheritance_id := (
		"%s:g%d:%s:%s"
		% [
			source_identity.pet_id(),
			source_identity.generation(),
			item_uid,
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
		"item": inherited_item,
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
		"has_item": not inherited_item.is_empty(),
		"item": inherited_item.duplicate(
			true
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

	var item_value: Variant = data.get(
		"item",
		{}
	)
	var has_item := (
		typeof(item_value) == TYPE_DICTIONARY
		and not (item_value as Dictionary).is_empty()
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
		"has_item": has_item,
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
		return {
			"applied": true,
			"already_present": true,
			"inheritance_id": inheritance_id,
			"has_skill": not inherited_skill.is_empty(),
			"skill_id": inherited_skill,
		}

	var item_value: Variant = data.get(
		"item",
		{}
	)
	var inherited_item: Dictionary = {}

	if typeof(
		item_value
	) == TYPE_DICTIONARY:
		inherited_item = (
			item_value as Dictionary
		).duplicate(
			true
		)

	if not inherited_item.is_empty():
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

		var stored: Array = meta.get(
			"inventory",
			[]
		)
		stored.append(
			inherited_item
		)
		meta["inventory"] = stored
		meta["legacy_inherited_item"] = inherited_item.duplicate(
			true
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
		"has_item": not inherited_item.is_empty(),
		"item": inherited_item.duplicate(
			true
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
	if not FileAccess.file_exists(
		SAVE_PATH
	):
		return {}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var data := (
		parsed as Dictionary
	).duplicate(true)
	var schema := int(
		data.get(
			"schema",
			0
		)
	)

	if schema == 1:
		data["schema"] = CURRENT_SCHEMA
		data["skill_id"] = ""
	elif schema != CURRENT_SCHEMA:
		return {}

	return data


func clear() -> bool:
	if not FileAccess.file_exists(
		SAVE_PATH
	):
		return true

	return (
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				SAVE_PATH
			)
		) == OK
	)


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
