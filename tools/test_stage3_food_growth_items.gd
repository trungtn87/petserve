extends Node


const RARITIES: Array[String] = [
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
]

const FOOD_SECONDS := {
	"common": 20 * 60,
	"uncommon": 25 * 60,
	"rare": 30 * 60,
	"epic": 40 * 60,
	"legendary": 60 * 60,
}

const GROWTH_SECONDS := {
	"common": 5 * 60,
	"uncommon": 7 * 60,
	"rare": 10 * 60,
	"epic": 14 * 60,
	"legendary": 20 * 60,
}


var _failures: int = 0


func _ready() -> void:
	_test_catalog_shape()
	_test_forced_rarity_generation()
	_test_rarity_value_progression()
	_test_stage_scaling_keeps_identity()
	_test_junk_contract()
	_test_legacy_migration()

	if _failures == 0:
		print("Stage 3 Food/Growth Items: PASS")
		get_tree().quit(0)
		return

	push_error(
		"Stage 3 Food/Growth Items: FAIL (%d)"
		% _failures
	)
	get_tree().quit(1)


func _test_catalog_shape() -> void:
	var generator := ItemGenerator.new()
	var food_total := 0
	var growth_total := 0

	for rarity in RARITIES:
		var food_count := generator.resource_definition_count(
			ItemGenerator.TYPE_FOOD,
			rarity
		)
		var growth_count := generator.resource_definition_count(
			ItemGenerator.TYPE_GROWTH,
			rarity
		)
		food_total += food_count
		growth_total += growth_count

		_expect(
			food_count == 1,
			"Food exposes one standardized definition at %s"
			% rarity
		)
		_expect(
			growth_count == 1,
			"Growth exposes one standardized definition at %s"
			% rarity
		)

	_expect(
		food_total == 5
		and growth_total == 5,
		"rarity variants reuse one Food and one Growth display identity"
	)


func _test_forced_rarity_generation() -> void:
	var generator := ItemGenerator.new()
	var seed_value := 97000

	for rarity in RARITIES:
		seed_value += 1
		var food := generator.generate_resource_for_rarity(
			ItemGenerator.TYPE_FOOD,
			seed_value,
			rarity
		)
		seed_value += 1
		var growth := generator.generate_resource_for_rarity(
			ItemGenerator.TYPE_GROWTH,
			seed_value,
			rarity
		)

		for item in [food, growth]:
			_expect(
				not item.is_empty()
				and String(item.get("rarity", "")) == rarity
				and String(item.get("quality", "")) == "standard"
				and not bool(item.get("is_junk", false))
				and (item.get("properties", []) as Array).is_empty()
				and (item.get("defects", []) as Array).is_empty()
				and (item.get("secondary_effects", []) as Array).is_empty(),
				"normal resource has rarity only and no quality/property/defect stack"
			)

		_expect(
			String(food.get("display_name", ""))
				== "Khẩu phần dinh dưỡng"
			and int(food.get("main_value_seconds", 0))
				== int(FOOD_SECONDS[rarity]),
			"Food rarity maps to fixed standardized value"
		)
		_expect(
			String(growth.get("display_name", ""))
				== "Tinh chất tăng trưởng"
			and int(growth.get("main_value_seconds", 0))
				== int(GROWTH_SECONDS[rarity]),
			"Growth rarity maps to fixed standardized value"
		)


func _test_rarity_value_progression() -> void:
	var generator := ItemGenerator.new()
	var previous_food := 0
	var previous_growth := 0

	for rarity in RARITIES:
		var food_range := generator.resource_base_range_for_rarity(
			ItemGenerator.TYPE_FOOD,
			rarity
		)
		var growth_range := generator.resource_base_range_for_rarity(
			ItemGenerator.TYPE_GROWTH,
			rarity
		)

		_expect(
			food_range.x == food_range.y
			and growth_range.x == growth_range.y,
			"standardized rarity values are fixed, not random ranges"
		)
		_expect(
			food_range.x > previous_food
			and growth_range.x > previous_growth,
			"higher rarity increases both Food and Growth value"
		)
		previous_food = food_range.x
		previous_growth = growth_range.x


func _test_stage_scaling_keeps_identity() -> void:
	var generator := ItemGenerator.new()
	var base := generator.generate_resource_for_rarity(
		ItemGenerator.TYPE_FOOD,
		98111,
		"epic"
	)
	var scaled := generator.scale_for_stage(
		base,
		3
	)

	_expect(
		String(scaled.get("definition_id", ""))
			== String(base.get("definition_id", ""))
		and String(scaled.get("rarity", "")) == "epic"
		and int(scaled.get("generated_for_stage", 0)) == 3,
		"stage scaling preserves standardized resource identity"
	)
	_expect(
		int(scaled.get("main_value_seconds", 0))
			== int(round(float(base.get("main_value_seconds", 0)) * 12.0)),
		"pethome Stage 3 keeps its current x12 lifecycle scaling"
	)


func _test_junk_contract() -> void:
	var generator := ItemGenerator.new()
	var saw_junk := false
	var saw_normal := false

	for seed_value in range(99000, 99400):
		var item := generator.generate(
			ItemGenerator.TYPE_FOOD,
			seed_value
		)
		if bool(item.get("is_junk", false)):
			saw_junk = true
			_expect(
				String(item.get("rarity", "")).is_empty()
				and String(item.get("quality", "")) == "junk"
				and String(item.get("display_name", ""))
					== "Thức ăn hỏng",
				"junk has no rarity and uses PHẾ PHẨM quality"
			)
		else:
			saw_normal = true

		if saw_junk and saw_normal:
			break

	_expect(
		saw_junk and saw_normal,
		"normal generation can produce both standardized items and rarity-free junk"
	)


func _test_legacy_migration() -> void:
	var legacy := ItemGenerator.normalize_item({
		"uid": "legacy_food",
		"item_type": "food",
		"rarity": "rare",
		"quality": "broken",
		"main_value_seconds": 999,
		"defects": ["spoiled"],
		"properties": ["fresh"],
		"secondary_effects": [],
	})
	_expect(
		bool(legacy.get("is_junk", false))
		and String(legacy.get("rarity", "")).is_empty()
		and String(legacy.get("quality", "")) == "junk",
		"legacy broken/defective resource migrates to rarity-free junk"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
