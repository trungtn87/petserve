extends Node


const RARITIES: Array[String] = [
	"common",
	"uncommon",
	"rare",
	"epic",
	"legendary",
]


var _failures: int = 0


func _ready() -> void:
	_test_catalog_shape()
	_test_forced_rarity_generation()
	_test_rarity_value_progression()
	_test_stage_scaling_keeps_identity()

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
			food_count == 4,
			"Food must expose four definitions at %s rarity"
			% rarity
		)
		_expect(
			growth_count == 4,
			"Growth must expose four definitions at %s rarity"
			% rarity
		)

	_expect(
		food_total == 20,
		"Food catalog must contain 20 base definitions"
	)
	_expect(
		growth_total == 20,
		"Growth catalog must contain 20 base definitions"
	)


func _test_forced_rarity_generation() -> void:
	var generator := ItemGenerator.new()
	var seed_value := 97000

	for rarity in RARITIES:
		for item_type in [
			ItemGenerator.TYPE_FOOD,
			ItemGenerator.TYPE_GROWTH,
		]:
			seed_value += 1
			var item := generator.generate_resource_for_rarity(
				item_type,
				seed_value,
				rarity
			)

			_expect(
				not item.is_empty(),
				"forced %s %s item must generate"
				% [
					rarity,
					String(item_type),
				]
			)
			_expect(
				String(item.get("rarity", "")) == rarity,
				"forced rarity must be preserved"
			)
			_expect(
				not String(
					item.get(
						"definition_id",
						""
					)
				).is_empty(),
				"resource item must expose a real definition id"
			)
			_expect(
				not String(
					item.get(
						"base_display_name",
						""
					)
				).is_empty(),
				"resource item must expose its base item name"
			)


func _test_rarity_value_progression() -> void:
	var generator := ItemGenerator.new()
	var previous_food := Vector2i.ZERO
	var previous_growth := Vector2i.ZERO

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
			food_range.x > 0
			and food_range.y >= food_range.x,
			"Food %s base range must be valid"
			% rarity
		)
		_expect(
			growth_range.x > 0
			and growth_range.y >= growth_range.x,
			"Growth %s base range must be valid"
			% rarity
		)

		if previous_food != Vector2i.ZERO:
			_expect(
				food_range.x > previous_food.x
				and food_range.y > previous_food.y,
				"Food rarity must increase base value from the previous tier"
			)
			_expect(
				growth_range.x > previous_growth.x
				and growth_range.y > previous_growth.y,
				"Growth rarity must increase base value from the previous tier"
			)

		previous_food = food_range
		previous_growth = growth_range


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
		String(
			scaled.get(
				"definition_id",
				""
			)
		) == String(
			base.get(
				"definition_id",
				""
			)
		),
		"stage scaling must not reroll the item definition"
	)
	_expect(
		String(
			scaled.get(
				"rarity",
				""
			)
		) == "epic",
		"stage scaling must keep rarity"
	)
	_expect(
		int(
			scaled.get(
				"generated_for_stage",
				0
			)
		) == 3,
		"Stage 3 scaling metadata must be set"
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	_failures += 1
	push_error(message)
