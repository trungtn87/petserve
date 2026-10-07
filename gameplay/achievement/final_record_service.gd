class_name FinalRecordService
extends RefCounted


const ARCHIVE_PATH: String = "user://final_record_archive_v1.json"
const RECORD_MEDIA_ROOT: String = "user://final_record_media"
const ARCHIVE_SCHEMA: int = 1
const CARD_STAGE_COUNT: int = 4


func ensure_current_record() -> Dictionary:
	var data := EvolutionSaveService.new().load_data()

	if data.is_empty():
		return _error("Không có dữ liệu pet hiện tại.")

	var built := build_record_from_evolution(data)

	if not bool(built.get("ok", false)):
		return built

	return register_record(
		built.get("record", {}) as Dictionary
	)


func build_record_from_evolution(
	data: Dictionary,
	completed_at_unix: int = 0
) -> Dictionary:
	var identity := PetIdentity.from_dict(
		data.get("identity", {})
	)
	var genome := PetGenome.from_dict(
		data.get("genome", {})
	)
	var current_visual := PetVisualRecord.from_dict(
		data.get("current_visual", {})
	)

	if (
		identity == null
		or genome == null
		or current_visual == null
	):
		return _error(
			"Không đọc được Identity/Genome/Visual để tạo thành tích."
		)

	if genome.stage() < StageLifecycle.FINAL_STAGE:
		return _error(
			"Pet chưa đạt hình thái cuối."
		)

	var snapshots := _collect_snapshots(
		data,
		genome,
		current_visual
	)

	if snapshots.size() < CARD_STAGE_COUNT:
		return _error(
			"Cần ít nhất %d ảnh tiến hóa để tạo Final Record."
			% CARD_STAGE_COUNT
		)

	var completed_at := completed_at_unix

	if completed_at <= 0:
		completed_at = int(
			Time.get_unix_time_from_system()
		)

	var record_id := (
		identity.pet_id()
		+ ":g%d" % identity.generation()
	)
	var final_form_id := _final_form_id(
		identity,
		genome
	)
	var record := {
		"schema": ARCHIVE_SCHEMA,
		"record_id": record_id,
		"pet_id": identity.pet_id(),
		"generation": identity.generation(),
		"species_id": String(identity.species()),
		"element_id": String(identity.element()),
		"final_form_id": final_form_id,
		"display_name": _display_name(
			identity,
			genome
		),
		"completed_at_unix": completed_at,
		"all_stage_snapshots": snapshots,
		"card_snapshots": _select_card_snapshots(
			snapshots
		),
		"final_image_path": current_visual.image_path,
		"card_path": "",
		"presented": false,
	}

	return {
		"ok": true,
		"record": record,
	}


func register_record(
	record: Dictionary
) -> Dictionary:
	var record_id := String(
		record.get("record_id", "")
	).strip_edges()
	var final_form_id := String(
		record.get("final_form_id", "")
	).strip_edges()

	if record_id.is_empty() or final_form_id.is_empty():
		return _error(
			"Final Record thiếu record_id/final_form_id."
		)

	var archive := _load_archive()
	var records: Dictionary = archive.get(
		"records",
		{}
	)
	var collection: Dictionary = archive.get(
		"collection",
		{}
	)

	if records.has(record_id):
		var existing_value: Variant = records[record_id]
		var existing := (
			(existing_value as Dictionary).duplicate(true)
			if typeof(existing_value) == TYPE_DICTIONARY
			else record.duplicate(true)
		)

		if String(
			existing.get(
				"gallery_path",
				""
			)
		).is_empty():
			var retry_gallery_path := (
				_auto_save_final_image_to_gallery(
					existing
				)
			)
			if not retry_gallery_path.is_empty():
				existing["gallery_path"] = (
					retry_gallery_path
				)
				records[record_id] = existing
				archive["records"] = records
				_save_archive(archive)

		return {
			"ok": true,
			"is_new": false,
			"record": existing,
			"collection_entry": (
				collection.get(
					final_form_id,
					{}
				) as Dictionary
			).duplicate(true),
		}

	var archive_result := _archive_record_snapshots(
		record
	)
	if not bool(
		archive_result.get(
			"ok",
			false
		)
	):
		return archive_result

	var stored := (
		archive_result.get(
			"record",
			record
		) as Dictionary
	).duplicate(true)
	stored["gallery_path"] = (
		_auto_save_final_image_to_gallery(
			stored
		)
	)
	records[record_id] = stored

	var entry: Dictionary = {}
	var entry_value: Variant = collection.get(
		final_form_id,
		{}
	)

	if typeof(entry_value) == TYPE_DICTIONARY:
		entry = (
			entry_value as Dictionary
		).duplicate(true)

	var count := int(
		entry.get(
			"completion_count",
			0
		)
	) + 1

	if entry.is_empty():
		entry = {
			"final_form_id": final_form_id,
			"species_id": String(
				record.get(
					"species_id",
					""
				)
			),
			"element_id": String(
				record.get(
					"element_id",
					""
				)
			),
			"display_name": String(
				record.get(
					"display_name",
					"Pet"
				)
			),
			"first_completed_at_unix": int(
				record.get(
					"completed_at_unix",
					0
				)
			),
			"first_record_id": record_id,
		}

	entry["completion_count"] = count
	entry["latest_record_id"] = record_id
	entry["thumbnail_path"] = String(
		stored.get(
			"final_image_path",
			""
		)
	)
	entry["display_name"] = String(
		record.get(
			"display_name",
			entry.get(
				"display_name",
				"Pet"
			)
		)
	)

	collection[final_form_id] = entry
	archive["records"] = records
	archive["collection"] = collection

	if not _save_archive(archive):
		return _error(
			"Không lưu được Final Record."
		)

	return {
		"ok": true,
		"is_new": true,
		"record": stored,
		"collection_entry": entry.duplicate(true),
	}


func get_record(
	record_id: String
) -> Dictionary:
	var archive := _load_archive()
	var records_value: Variant = archive.get(
		"records",
		{}
	)

	if typeof(records_value) != TYPE_DICTIONARY:
		return {}

	var records := records_value as Dictionary
	var value: Variant = records.get(
		record_id,
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func list_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var archive := _load_archive()
	var records_value: Variant = archive.get(
		"records",
		{}
	)

	if typeof(records_value) != TYPE_DICTIONARY:
		return result

	for raw in (
		records_value as Dictionary
	).values():
		if typeof(raw) == TYPE_DICTIONARY:
			result.append(
				(raw as Dictionary).duplicate(
					true
				)
			)

	result.sort_custom(
		Callable(
			self,
			"_record_newer_than"
		)
	)
	return result


func record_count() -> int:
	return list_records().size()


func list_collection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var archive := _load_archive()
	var collection_value: Variant = archive.get(
		"collection",
		{}
	)

	if typeof(collection_value) != TYPE_DICTIONARY:
		return result

	for raw in (
		collection_value as Dictionary
	).values():
		if typeof(raw) == TYPE_DICTIONARY:
			result.append(
				(raw as Dictionary).duplicate(
					true
				)
			)

	result.sort_custom(
		Callable(
			self,
			"_collection_less_than"
		)
	)
	return result


func collection_count() -> int:
	return list_collection().size()


func mark_presented(
	record_id: String
) -> bool:
	return _update_record_field(
		record_id,
		"presented",
		true
	)


func set_card_path(
	record_id: String,
	path: String
) -> bool:
	return _update_record_field(
		record_id,
		"card_path",
		path
	)


func _update_record_field(
	record_id: String,
	field: String,
	value: Variant
) -> bool:
	var archive := _load_archive()
	var records_value: Variant = archive.get(
		"records",
		{}
	)

	if typeof(records_value) != TYPE_DICTIONARY:
		return false

	var records := records_value as Dictionary
	var raw: Variant = records.get(
		record_id,
		{}
	)

	if typeof(raw) != TYPE_DICTIONARY:
		return false

	var record := (
		raw as Dictionary
	).duplicate(true)
	record[field] = value
	records[record_id] = record
	archive["records"] = records
	return _save_archive(archive)


func _archive_record_snapshots(
	record: Dictionary
) -> Dictionary:
	var record_id := String(
		record.get(
			"record_id",
			""
		)
	).strip_edges()
	var snapshots_value: Variant = record.get(
		"all_stage_snapshots",
		[]
	)

	if (
		record_id.is_empty()
		or typeof(snapshots_value) != TYPE_ARRAY
	):
		return _error(
			"Final Record không có danh sách ảnh giai đoạn hợp lệ."
		)

	var source_snapshots := snapshots_value as Array
	if source_snapshots.is_empty():
		return _error(
			"Final Record không có ảnh giai đoạn để lưu."
		)

	var record_dir := RECORD_MEDIA_ROOT.path_join(
		record_id.validate_filename()
	)
	var make_error := (
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(
				record_dir
			)
		)
	)

	if (
		make_error != OK
		and make_error != ERR_ALREADY_EXISTS
	):
		return _error(
			"Không tạo được thư mục lưu ảnh đời thú cưng."
		)

	var archived: Array[Dictionary] = []

	for raw in source_snapshots:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var snapshot := (
			raw as Dictionary
		).duplicate(true)
		var stage_index := int(
			snapshot.get(
				"stage_index",
				0
			)
		)
		var source_path := String(
			snapshot.get(
				"image_path",
				""
			)
		).strip_edges()

		if (
			stage_index <= 0
			or source_path.is_empty()
			or not FileAccess.file_exists(
				source_path
			)
		):
			return _error(
				"Thiếu ảnh giai đoạn %d, chưa thể chốt đời thú cưng."
				% stage_index
			)

		var image := Image.load_from_file(
			source_path
		)
		if image == null or image.is_empty():
			return _error(
				"Không đọc được ảnh giai đoạn %d."
				% stage_index
			)

		var archive_path := record_dir.path_join(
			"stage_%02d.png"
			% stage_index
		)
		if image.save_png(
			archive_path
		) != OK:
			return _error(
				"Không lưu được ảnh giai đoạn %d."
				% stage_index
			)

		snapshot["image_path"] = archive_path
		archived.append(
			snapshot
		)

	if archived.is_empty():
		return _error(
			"Không có ảnh giai đoạn nào được lưu."
		)

	var stored := record.duplicate(true)
	stored["all_stage_snapshots"] = archived
	stored["card_snapshots"] = _select_card_snapshots(
		archived
	)

	var final_stage := -1
	var final_image_path := ""
	for snapshot in archived:
		var stage_index := int(
			snapshot.get(
				"stage_index",
				0
			)
		)
		if stage_index > final_stage:
			final_stage = stage_index
			final_image_path = String(
				snapshot.get(
					"image_path",
					""
				)
			)

	stored["final_image_path"] = final_image_path

	return {
		"ok": true,
		"record": stored,
	}


func _auto_save_final_image_to_gallery(
	record: Dictionary
) -> String:
	if (
		not OS.has_feature("android")
		or not Engine.has_singleton(
			"PetVerseBackup"
		)
	):
		return ""

	var source_path := String(
		record.get(
			"final_image_path",
			""
		)
	).strip_edges()
	if (
		source_path.is_empty()
		or not FileAccess.file_exists(
			source_path
		)
	):
		return ""

	var record_id := String(
		record.get(
			"record_id",
			"pet"
		)
	).validate_filename()
	var file_name := (
		"PetVerse_%s_Final.png"
		% record_id
	)
	var native := Engine.get_singleton(
		"PetVerseBackup"
	)
	if native == null:
		return ""

	return String(
		native.save_image_to_gallery(
			ProjectSettings.globalize_path(
				source_path
			),
			file_name
		)
	)


func _collect_snapshots(
	data: Dictionary,
	genome: PetGenome,
	current_visual: PetVisualRecord
) -> Array[Dictionary]:
	var by_stage: Dictionary = {}
	var history_value: Variant = data.get(
		"evolution_history",
		[]
	)

	if typeof(history_value) == TYPE_ARRAY:
		for raw_plan in history_value as Array:
			if typeof(raw_plan) != TYPE_DICTIONARY:
				continue

			var plan := raw_plan as Dictionary
			var stage_index := int(
				plan.get(
					"from_stage",
					0
				)
			)
			var visual_value: Variant = plan.get(
				"source_visual",
				{}
			)

			if (
				stage_index <= 0
				or typeof(visual_value) != TYPE_DICTIONARY
			):
				continue

			var path := String(
				(visual_value as Dictionary).get(
					"image_path",
					""
				)
			).strip_edges()

			if not path.is_empty():
				by_stage[stage_index] = path

	by_stage[genome.stage()] = current_visual.image_path

	var keys := by_stage.keys()
	keys.sort()

	var result: Array[Dictionary] = []

	for key_value in keys:
		var stage_index := int(key_value)
		var image_path := String(
			by_stage[key_value]
		).strip_edges()

		if image_path.is_empty():
			continue

		result.append({
			"stage_index": stage_index,
			"image_path": image_path,
		})

	return result


func _select_card_snapshots(
	snapshots: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if snapshots.size() <= CARD_STAGE_COUNT:
		for snapshot in snapshots:
			result.append(
				snapshot.duplicate(true)
			)
		return result

	for index in range(CARD_STAGE_COUNT):
		var ratio := (
			float(index)
			/ float(CARD_STAGE_COUNT - 1)
		)
		var source_index := int(
			round(
				ratio
				* float(
					snapshots.size() - 1
				)
			)
		)
		source_index = clampi(
			source_index,
			0,
			snapshots.size() - 1
		)
		result.append(
			snapshots[source_index].duplicate(
				true
			)
		)

	return result


func _final_form_id(
	identity: PetIdentity,
	genome: PetGenome
) -> String:
	var trait_tokens: Array[String] = []
	var traits := genome.traits_snapshot()
	var trait_keys := traits.keys()
	trait_keys.sort()

	for key_value in trait_keys:
		trait_tokens.append(
			"%s=%s"
			% [
				String(key_value),
				String(traits[key_value]),
			]
		)

	var mutation_tokens: Array[String] = []

	for mutation_id in genome.mutation_ids():
		mutation_tokens.append(
			String(mutation_id)
		)

	mutation_tokens.sort()

	var signature := (
		String(identity.species())
		+ "|"
		+ String(identity.element())
		+ "|"
		+ ",".join(trait_tokens)
		+ "|"
		+ ",".join(mutation_tokens)
	)
	var context := HashingContext.new()
	context.start(
		HashingContext.HASH_SHA256
	)
	context.update(
		signature.to_utf8_buffer()
	)
	var digest := (
		context.finish().hex_encode()
	)

	return (
		String(identity.species())
		+ "_"
		+ String(identity.element())
		+ "_"
		+ digest.substr(0, 16)
	)


func _display_name(
	identity: PetIdentity,
	genome: PetGenome
) -> String:
	var base_name := (
		PetElementCatalog.display_name(
			identity.element()
		)
		+ " "
		+ String(
			identity.species()
		).capitalize()
	)
	var mutations := genome.mutation_ids()

	if mutations.is_empty():
		return base_name

	var mutation_label := String(
		mutations.back()
	).replace(
		"_",
		" "
	).capitalize()

	return (
		base_name
		+ " • "
		+ mutation_label
	)


func _load_archive() -> Dictionary:
	var archive := AtomicJson.read(ARCHIVE_PATH)
	if archive.is_empty():
		return _empty_archive()

	if int(
		archive.get(
			"schema",
			0
		)
	) != ARCHIVE_SCHEMA:
		return _empty_archive()

	if typeof(
		archive.get(
			"records",
			{}
		)
	) != TYPE_DICTIONARY:
		archive["records"] = {}

	if typeof(
		archive.get(
			"collection",
			{}
		)
	) != TYPE_DICTIONARY:
		archive["collection"] = {}

	return archive


func _save_archive(
	archive: Dictionary
) -> bool:
	archive["schema"] = ARCHIVE_SCHEMA
	return AtomicJson.write(
		ARCHIVE_PATH,
		archive
	)


func _empty_archive() -> Dictionary:
	return {
		"schema": ARCHIVE_SCHEMA,
		"records": {},
		"collection": {},
	}


func _record_newer_than(
	a: Dictionary,
	b: Dictionary
) -> bool:
	var completed_a := int(
		a.get(
			"completed_at_unix",
			0
		)
	)
	var completed_b := int(
		b.get(
			"completed_at_unix",
			0
		)
	)

	if completed_a != completed_b:
		return completed_a > completed_b

	return int(
		a.get(
			"generation",
			0
		)
	) > int(
		b.get(
			"generation",
			0
		)
	)


func _collection_less_than(
	a: Dictionary,
	b: Dictionary
) -> bool:
	return String(
		a.get(
			"display_name",
			""
		)
	).naturalnocasecmp_to(
		String(
			b.get(
				"display_name",
				""
			)
		)
	) < 0


func _error(
	message: String
) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
