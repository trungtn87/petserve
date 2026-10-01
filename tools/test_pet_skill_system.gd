extends Node


var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_catalog()
	_test_stage_slots()
	_test_stage4_egg_bonus()
	_test_inherited_slot_one()
	_test_growth_and_hunger_effects()

	print(
		"PET SKILLS checks=",
		_checks,
		" failures=",
		_failures
	)
	get_tree().quit(
		1 if _failures > 0 else 0
	)


func _test_catalog() -> void:
	var definitions := PetSkillCatalog.all()
	var ids := PetSkillCatalog.all_ids()

	_expect(
		definitions.size() == 26,
		"catalog must contain exactly 26 skills"
	)
	_expect(
		ids.size() == 26,
		"catalog id list must contain exactly 26 skills"
	)

	var unique: Dictionary = {}
	for skill_id in ids:
		unique[skill_id] = true
		_expect(
			PetSkillCatalog.is_valid(
				StringName(skill_id)
			),
			"catalog id must resolve: " + skill_id
		)

	_expect(
		unique.size() == 26,
		"all 26 skill ids must be unique"
	)


func _test_stage_slots() -> void:
	var meta: Dictionary = {}
	var skills := PetSkillService.new()
	skills.setup(
		meta,
		8101,
		1
	)

	_expect(
		skills.ensure_for_stage(1),
		"Stage 1 must unlock one skill"
	)
	_expect(
		skills.snapshot().skills.size() == 1,
		"Stage 1 must own exactly one skill"
	)
	_expect(
		not skills.ensure_for_stage(1),
		"reloading Stage 1 must not reroll the slot"
	)

	skills.ensure_for_stage(2)
	_expect(
		skills.snapshot().skills.size() == 2,
		"Stage 2 must own exactly two skills"
	)

	skills.ensure_for_stage(3)
	var snapshot := skills.snapshot()
	_expect(
		snapshot.skills.size() == 3,
		"Stage 3 normal egg must own exactly three skills"
	)
	_expect(
		_unique_skill_count(
			snapshot.skills
		) == 3,
		"Stage 1-3 random skills must not duplicate"
	)

	var reloaded := PetSkillService.new()
	reloaded.setup(
		meta,
		8101,
		1
	)
	reloaded.ensure_for_stage(3)
	_expect(
		reloaded.snapshot().skills == snapshot.skills,
		"skill rolls must survive reload without rerolling"
	)


func _test_stage4_egg_bonus() -> void:
	var meta: Dictionary = {}
	var skills := PetSkillService.new()
	skills.setup(
		meta,
		8201,
		4
	)
	skills.ensure_for_stage(1)

	var hatch_snapshot := skills.snapshot()
	_expect(
		hatch_snapshot.skills.size() == 2,
		"Stage 4 egg must hatch with Stage 1 skill plus bonus slot 4"
	)
	_expect(
		_has_slot(
			hatch_snapshot.skills,
			4,
			"egg_stage4"
		),
		"Stage 4 egg bonus must occupy slot 4"
	)

	skills.ensure_for_stage(3)
	var final_snapshot := skills.snapshot()
	_expect(
		final_snapshot.skills.size() == 4,
		"Stage 4 egg must reach four total skills by Stage 3"
	)
	_expect(
		_unique_skill_count(
			final_snapshot.skills
		) == 4,
		"four skill slots must never duplicate a skill"
	)


func _test_inherited_slot_one() -> void:
	var meta := {
		"legacy_inherited_skill_id": "long_childhood",
	}
	var skills := PetSkillService.new()
	skills.setup(
		meta,
		8301,
		1
	)
	skills.ensure_for_stage(1)

	var entries: Array = skills.snapshot().skills
	_expect(
		entries.size() == 1,
		"inherited life must still have only one Stage 1 slot"
	)

	if entries.is_empty():
		return

	var slot: Dictionary = entries[0]
	_expect(
		String(
			slot.get(
				"skill_id",
				""
			)
		) == "long_childhood",
		"inherited skill must replace the Stage 1 random roll"
	)
	_expect(
		String(
			slot.get(
				"source",
				""
			)
		) == "legacy",
		"inherited skill source must be marked legacy"
	)


func _test_growth_and_hunger_effects() -> void:
	var baseline_meta: Dictionary = {}
	var baseline := StageLifecycle.new()
	baseline.setup(
		baseline_meta,
		8401,
		1
	)
	var base_before := baseline.snapshot()
	var food_item := {
		"uid": "skill_test_food",
		"item_type": String(
			ItemGenerator.TYPE_FOOD
		),
		"display_name": "Skill Test Food",
		"main_value_seconds": 60,
		"growth_delta_seconds": 100,
	}
	baseline.apply_item(
		food_item
	)
	var base_after := baseline.snapshot()

	var hearty_meta := _skill_meta(
		8402,
		"hearty_eater"
	)
	var hearty_skills := PetSkillService.new()
	hearty_skills.setup(
		hearty_meta,
		8402,
		1
	)
	var hearty := StageLifecycle.new()
	hearty.setup(
		hearty_meta,
		8402,
		1,
		hearty_skills
	)
	var hearty_before := hearty.snapshot()
	hearty.apply_item(
		food_item
	)
	var hearty_after := hearty.snapshot()

	_expect(
		(
			int(hearty_after.food_seconds)
			- int(hearty_before.food_seconds)
		) > (
			int(base_after.food_seconds)
			- int(base_before.food_seconds)
		),
		"Ăn Khỏe must increase fullness gained from food"
	)

	var long_meta := _skill_meta(
		8403,
		"long_childhood"
	)
	var long_skills := PetSkillService.new()
	long_skills.setup(
		long_meta,
		8403,
		1
	)
	var long_life := StageLifecycle.new()
	long_life.setup(
		long_meta,
		8403,
		1,
		long_skills
	)
	var direct_growth := {
		"uid": "skill_test_growth",
		"item_type": String(
			ItemGenerator.TYPE_GROWTH
		),
		"display_name": "Skill Test Growth",
		"main_value_seconds": 1000,
		"food_delta_seconds": 0,
	}
	long_life.apply_item(
		direct_growth
	)
	_expect(
		int(
			long_life.snapshot().growth_remaining_seconds
		) > int(
			baseline.snapshot().growth_remaining_seconds
		) - 1000,
		"Tuổi Thơ Dài must reduce direct Growth gains"
	)

	var stomach_meta := _skill_meta(
		8404,
		"bottomless_stomach"
	)
	var stomach_skills := PetSkillService.new()
	stomach_skills.setup(
		stomach_meta,
		8404,
		1
	)
	var stomach := StageLifecycle.new()
	stomach.setup(
		stomach_meta,
		8404,
		1,
		stomach_skills
	)
	var stomach_start := stomach.snapshot()
	var overflow_food := food_item.duplicate(true)
	overflow_food["uid"] = "overflow_food"
	overflow_food["main_value_seconds"] = (
		int(stomach_start.food_capacity_seconds) * 2
	)
	overflow_food["growth_delta_seconds"] = 0
	stomach.apply_item(
		overflow_food
	)
	_expect(
		int(
			stomach.snapshot().food_buffer_seconds
		) > 0,
		"Dạ Dày Không Đáy must store overflow in its separate buffer"
	)


func _skill_meta(
	run_id: int,
	skill_id: String
) -> Dictionary:
	return {
		"pet_skill_state": {
			"schema": 1,
			"run_id": run_id,
			"egg_stage": 1,
			"slots": [
				{
					"slot": 1,
					"skill_id": skill_id,
					"source": "test",
				},
			],
			"roll_counters": {},
			"survival_used_stages": [],
			"rebound_queue": [],
			"first_meal_day": "",
			"food_preference": "",
		},
	}


func _unique_skill_count(
	entries: Array
) -> int:
	var unique: Dictionary = {}

	for raw in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		unique[
			String(
				(raw as Dictionary).get(
					"skill_id",
					""
				)
			)
		] = true

	return unique.size()


func _has_slot(
	entries: Array,
	slot_index: int,
	source: String
) -> bool:
	for raw in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry := raw as Dictionary
		if (
			int(
				entry.get(
					"slot",
					0
				)
			) == slot_index
			and String(
				entry.get(
					"source",
					""
				)
			) == source
		):
			return true

	return false


func _expect(
	condition: bool,
	message: String
) -> void:
	_checks += 1

	if condition:
		return

	_failures += 1
	push_error(
		message
	)
