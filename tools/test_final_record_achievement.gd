extends Node


var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_cleanup()
	_prepare_fixture_images()
	_test_build_four_panel_record()
	_test_idempotent_collection()
	_cleanup()

	print(
		"FINAL RECORD checks=",
		_checks,
		" failures=",
		_failures
	)
	get_tree().quit(
		1 if _failures > 0 else 0
	)


func _test_build_four_panel_record() -> void:
	var service := FinalRecordService.new()
	var data := _fixture(
		"PET_RECORD_A",
		11,
		0
	)
	var result := service.build_record_from_evolution(
		data,
		1700000000
	)

	_expect(
		bool(result.get("ok", false)),
		"final record must build from completed evolution history"
	)

	if not bool(result.get("ok", false)):
		return

	var record: Dictionary = result.get(
		"record",
		{}
	)
	var all_snapshots: Array = record.get(
		"all_stage_snapshots",
		[]
	)
	var card_snapshots: Array = record.get(
		"card_snapshots",
		[]
	)

	_expect(
		all_snapshots.size() == 5,
		"runtime Stage 1-5 must keep all five source snapshots as metadata"
	)
	_expect(
		card_snapshots.size() == 4,
		"Final Card must always select exactly four portrait milestones"
	)

	if card_snapshots.size() == 4:
		var stages := [
			int(
				(card_snapshots[0] as Dictionary).get(
					"stage_index",
					0
				)
			),
			int(
				(card_snapshots[1] as Dictionary).get(
					"stage_index",
					0
				)
			),
			int(
				(card_snapshots[2] as Dictionary).get(
					"stage_index",
					0
				)
			),
			int(
				(card_snapshots[3] as Dictionary).get(
					"stage_index",
					0
				)
			),
		]
		_expect(
			stages == [1, 2, 4, 5],
			"five runtime stages must be sampled evenly as 1,2,4,Final"
		)

	_expect(
		not String(
			record.get(
				"final_form_id",
				""
			)
		).is_empty(),
		"final form id must be deterministic and non-empty"
	)
	_expect(
		String(
			record.get(
				"final_image_path",
				""
			)
		) == "user://pet_stage_5.png",
		"final thumbnail must point to the current Final visual"
	)


func _test_idempotent_collection() -> void:
	var service := FinalRecordService.new()
	var first_build := service.build_record_from_evolution(
		_fixture(
			"PET_RECORD_A",
			11,
			0
		),
		1700000000
	)
	var first_record: Dictionary = first_build.get(
		"record",
		{}
	)
	var first := service.register_record(
		first_record
	)

	_expect(
		bool(first.get("ok", false))
		and bool(first.get("is_new", false)),
		"first completed life must create a new record"
	)
	_expect(
		int(
			(
				first.get(
					"collection_entry",
					{}
				) as Dictionary
			).get(
				"completion_count",
				0
			)
		) == 1,
		"first discovery must set completion_count=1"
	)

	var duplicate := service.register_record(
		first_record
	)
	_expect(
		bool(duplicate.get("ok", false))
		and not bool(
			duplicate.get(
				"is_new",
				true
			)
		),
		"registering the same life twice must be idempotent"
	)

	var second_build := service.build_record_from_evolution(
		_fixture(
			"PET_RECORD_B",
			11,
			1
		),
		1700001000
	)
	var second := service.register_record(
		second_build.get(
			"record",
			{}
		) as Dictionary
	)

	_expect(
		bool(second.get("ok", false)),
		"second completed life with the same final form must register"
	)
	_expect(
		service.collection_count() == 1,
		"same final form across different lives must keep one collection tile"
	)

	_expect(
		service.record_count() == 2,
		"each completed life must keep its own achievement record"
	)

	var records := service.list_records()
	_expect(
		records.size() == 2,
		"achievement history must list every completed life"
	)
	if records.size() == 2:
		var snapshots_value: Variant = records[0].get(
			"all_stage_snapshots",
			[]
		)
		if typeof(snapshots_value) == TYPE_ARRAY:
			var snapshots := snapshots_value as Array
			_expect(
				snapshots.size() == StageLifecycle.FINAL_STAGE,
				"each life record must archive every stage image"
			)
			if not snapshots.is_empty():
				_expect(
					String(
						(snapshots[0] as Dictionary).get(
							"image_path",
							""
						)
					).begins_with(
						FinalRecordService.RECORD_MEDIA_ROOT
					),
					"stage images must be copied into durable final-record media"
				)

	var entries := service.list_collection()
	if entries.size() == 1:
		_expect(
			int(
				entries[0].get(
					"completion_count",
					0
				)
			) == 2,
			"same final form completed twice must increment completion_count"
		)

	_expect(
		service.mark_presented(
			String(
				first_record.get(
					"record_id",
					""
				)
			)
		),
		"record presentation state must persist"
	)
	_expect(
		service.set_card_path(
			String(
				first_record.get(
					"record_id",
					""
				)
			),
			"user://final_records/test.png"
		),
		"saved Final Card path must persist"
	)


func _prepare_fixture_images() -> void:
	for stage_index in range(
		1,
		StageLifecycle.FINAL_STAGE + 1
	):
		var image := Image.create(
			8,
			8,
			false,
			Image.FORMAT_RGBA8
		)
		image.fill(
			Color(
				0.1 * float(stage_index),
				0.2,
				0.3,
				1.0
			)
		)
		var error := image.save_png(
			"user://pet_stage_%d.png"
			% stage_index
		)
		_expect(
			error == OK,
			"fixture image must be writable"
		)


func _fixture(
	pet_id: String,
	lineage_seed: int,
	generation: int
) -> Dictionary:
	var identity := PetIdentity.new(
		pet_id,
		&"cat",
		&"dark",
		lineage_seed,
		generation
	)
	var genome := PetGenome.new(
		StageLifecycle.FINAL_STAGE,
		0.0,
		{
			&"eyes": &"moon",
			&"tail": &"long",
		},
		[
			&"eclipse_aura",
		]
	)
	var history: Array[Dictionary] = []

	for stage_index in range(
		1,
		StageLifecycle.FINAL_STAGE
	):
		history.append({
			"from_stage": stage_index,
			"to_stage": stage_index + 1,
			"source_visual": _visual(
				pet_id,
				stage_index - 1,
				"user://pet_stage_%d.png"
				% stage_index
			),
		})

	return {
		"identity": identity.to_dict(),
		"genome": genome.to_dict(),
		"current_visual": _visual(
			pet_id,
			StageLifecycle.FINAL_STAGE - 1,
			"user://pet_stage_%d.png"
			% StageLifecycle.FINAL_STAGE
		),
		"evolution_history": history,
	}


func _visual(
	pet_id: String,
	visual_index: int,
	path: String
) -> Dictionary:
	return {
		"schema": 1,
		"pet_id": pet_id,
		"visual_index": visual_index,
		"image_path": path,
		"source_mode": "test",
		"mutation_id": "",
		"renderer_id": "test",
		"model_id": "test",
	}


func _cleanup() -> void:
	if FileAccess.file_exists(
		FinalRecordService.ARCHIVE_PATH
	):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(
				FinalRecordService.ARCHIVE_PATH
			)
		)


func _expect(
	condition: bool,
	message: String
) -> void:
	_checks += 1

	if condition:
		return

	_failures += 1
	push_error(message)
