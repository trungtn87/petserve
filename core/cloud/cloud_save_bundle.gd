class_name CloudSaveBundle
extends RefCounted


const CURRENT_SCHEMA: int = 1

const KEY_RUN: String = "run"
const KEY_META: String = "meta"
const KEY_EGG: String = "egg"
const KEY_HATCH: String = "hatch"
const KEY_EVOLUTION: String = "evolution"
const KEY_LEGACY: String = "legacy"
const KEY_VISUAL: String = "visual"

const STATE_KEYS := [
	KEY_RUN,
	KEY_META,
	KEY_EGG,
	KEY_HATCH,
	KEY_EVOLUTION,
	KEY_LEGACY,
]


static func capture() -> Dictionary:
	var evolution := EvolutionSaveService.new().load_data()

	return {
		"schema": CURRENT_SCHEMA,
		"captured_at_unix": int(
			Time.get_unix_time_from_system()
		),
		KEY_RUN: SaveManager.load_run().duplicate(true),
		KEY_META: SaveManager.load_meta().duplicate(true),
		KEY_EGG: SaveService.new().load_game().duplicate(true),
		KEY_HATCH: HatchSaveService.new().load_data().duplicate(true),
		KEY_EVOLUTION: evolution.duplicate(true),
		KEY_LEGACY: LegacyInheritanceService.new().load_data().duplicate(true),
		KEY_VISUAL: _visual_manifest(evolution),
	}


static func is_valid(
	snapshot: Dictionary
) -> bool:
	if int(
		snapshot.get(
			"schema",
			0
		)
	) != CURRENT_SCHEMA:
		return false

	for key in STATE_KEYS:
		var value: Variant = snapshot.get(
			key,
			{}
		)

		if typeof(value) != TYPE_DICTIONARY:
			return false

	var visual_value: Variant = snapshot.get(
		KEY_VISUAL,
		{}
	)

	return typeof(
		visual_value
	) == TYPE_DICTIONARY


static func has_game_data(
	snapshot: Dictionary
) -> bool:
	if not is_valid(snapshot):
		return false

	for key in STATE_KEYS:
		var value := snapshot.get(
			key,
			{}
		) as Dictionary

		if not value.is_empty():
			return true

	return false


static func current_visual_path(
	snapshot: Dictionary
) -> String:
	if not is_valid(snapshot):
		return ""

	var visual := snapshot.get(
		KEY_VISUAL,
		{}
	) as Dictionary

	return String(
		visual.get(
			"image_path",
			""
		)
	)


static func restore(
	snapshot: Dictionary
) -> bool:
	if not is_valid(snapshot):
		return false

	var before := capture()

	if _apply_snapshot(snapshot):
		return true

	# Best-effort rollback so a failed cloud restore does not
	# leave half of the local save set replaced.
	_apply_snapshot(before)
	return false


static func empty_snapshot() -> Dictionary:
	return {
		"schema": CURRENT_SCHEMA,
		"captured_at_unix": int(
			Time.get_unix_time_from_system()
		),
		KEY_RUN: {},
		KEY_META: {},
		KEY_EGG: {},
		KEY_HATCH: {},
		KEY_EVOLUTION: {},
		KEY_LEGACY: {},
		KEY_VISUAL: {},
	}


static func _apply_snapshot(
	snapshot: Dictionary
) -> bool:
	var run_data := (
		snapshot.get(
			KEY_RUN,
			{}
		) as Dictionary
	)
	var meta_data := (
		snapshot.get(
			KEY_META,
			{}
		) as Dictionary
	)
	var egg_data := (
		snapshot.get(
			KEY_EGG,
			{}
		) as Dictionary
	)
	var hatch_data := (
		snapshot.get(
			KEY_HATCH,
			{}
		) as Dictionary
	)
	var evolution_data := (
		snapshot.get(
			KEY_EVOLUTION,
			{}
		) as Dictionary
	)
	var legacy_data := (
		snapshot.get(
			KEY_LEGACY,
			{}
		) as Dictionary
	)

	if run_data.is_empty():
		SaveManager.delete_save()
	elif not SaveManager.save_run(
		run_data.duplicate(true)
	):
		return false

	if meta_data.is_empty():
		SaveManager.delete_meta()
	elif not SaveManager.save_meta(
		meta_data.duplicate(true)
	):
		return false

	var egg_save := SaveService.new()

	if egg_data.is_empty():
		if not egg_save.delete_save():
			return false
	elif not egg_save.save_game(
		egg_data.duplicate(true)
	):
		return false

	var hatch_save := HatchSaveService.new()

	if hatch_data.is_empty():
		if not hatch_save.delete_save():
			return false
	elif not hatch_save.save_data(
		hatch_data.duplicate(true)
	):
		return false

	var evolution_save := EvolutionSaveService.new()

	if evolution_data.is_empty():
		if not evolution_save.delete_data():
			return false
	elif not evolution_save.save_data(
		evolution_data.duplicate(true)
	):
		return false

	var legacy_save := LegacyInheritanceService.new()

	if legacy_data.is_empty():
		if not legacy_save.clear():
			return false
	elif not AtomicJson.write(
		LegacyInheritanceService.SAVE_PATH,
		legacy_data.duplicate(true)
	):
		return false

	return true


static func _visual_manifest(
	evolution: Dictionary
) -> Dictionary:
	var current_value: Variant = evolution.get(
		"current_visual",
		{}
	)

	if typeof(
		current_value
	) != TYPE_DICTIONARY:
		return {}

	var current := current_value as Dictionary
	var image_path := String(
		current.get(
			"image_path",
			""
		)
	)

	if image_path.is_empty():
		return {}

	return {
		"pet_id": String(
			current.get(
				"pet_id",
				""
			)
		),
		"visual_index": int(
			current.get(
				"visual_index",
				0
			)
		),
		"image_path": image_path,
		"file_exists": FileAccess.file_exists(
			image_path
		),
	}
