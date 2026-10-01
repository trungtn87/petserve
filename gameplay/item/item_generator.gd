class_name ItemGenerator
extends RefCounted


const TYPE_FOOD: StringName = &"food"
const TYPE_GROWTH: StringName = &"growth"
const TYPE_GENE: StringName = &"gene"
const TYPE_FUTURE_FRAGMENT: StringName = &"future_fragment"
const GENE_GROWTH_BONUS_PERCENT: float = 5.0
const GENE_RARITY_STATS := {
	"common": {"score": 10.0, "growth": 2.0},
	"uncommon": {"score": 20.0, "growth": 5.0},
	"rare": {"score": 35.0, "growth": 7.0},
	"epic": {"score": 55.0, "growth": 10.0},
	"legendary": {"score": 80.0, "growth": 15.0},
}

# Food/Growth now follow the same five rarity tiers as Gene items.
# Rarity determines the base value range; quality/properties/defects still
# mutate the individual item instance afterwards.
const RESOURCE_RARITY_STATS := {
	"common": {
		"food_min_seconds": 20 * 60,
		"food_max_seconds": 30 * 60,
		"growth_min_seconds": 6 * 60,
		"growth_max_seconds": 12 * 60,
	},
	"uncommon": {
		"food_min_seconds": 30 * 60,
		"food_max_seconds": 45 * 60,
		"growth_min_seconds": 10 * 60,
		"growth_max_seconds": 16 * 60,
	},
	"rare": {
		"food_min_seconds": 45 * 60,
		"food_max_seconds": 65 * 60,
		"growth_min_seconds": 15 * 60,
		"growth_max_seconds": 25 * 60,
	},
	"epic": {
		"food_min_seconds": 60 * 60,
		"food_max_seconds": 90 * 60,
		"growth_min_seconds": 25 * 60,
		"growth_max_seconds": 40 * 60,
	},
	"legendary": {
		"food_min_seconds": 90 * 60,
		"food_max_seconds": 120 * 60,
		"growth_min_seconds": 40 * 60,
		"growth_max_seconds": 60 * 60,
	},
}

const FOOD_DEFINITIONS_BY_RARITY := {
	"common": [
		{"id": "food_small_fish", "display_name": "Cá nhỏ"},
		{"id": "food_soft_meat", "display_name": "Thịt mềm"},
		{"id": "food_warm_milk", "display_name": "Sữa ấm"},
		{"id": "food_wild_berries", "display_name": "Quả mọng"},
	],
	"uncommon": [
		{"id": "food_silver_fish", "display_name": "Cá bạc"},
		{"id": "food_energy_meat", "display_name": "Thịt giàu năng lượng"},
		{"id": "food_honey_root", "display_name": "Củ mật"},
		{"id": "food_nutri_milk", "display_name": "Sữa hạt tinh lực"},
	],
	"rare": [
		{"id": "food_moon_fish", "display_name": "Cá ánh trăng"},
		{"id": "food_spirit_meat", "display_name": "Thịt Linh Thú"},
		{"id": "food_vital_fruit", "display_name": "Quả sinh lực"},
		{"id": "food_crystal_milk", "display_name": "Sữa pha lê"},
	],
	"epic": [
		{"id": "food_nebula_fish", "display_name": "Cá Tinh Vân"},
		{"id": "food_ancient_meat", "display_name": "Thịt Cổ Thú"},
		{"id": "food_growth_fruit", "display_name": "Quả Tăng Trưởng"},
		{"id": "food_spirit_nectar", "display_name": "Mật Linh"},
	],
	"legendary": [
		{"id": "food_galaxy_fish", "display_name": "Cá Ngân Hà"},
		{"id": "food_celestial_meat", "display_name": "Thịt Thiên Thú"},
		{"id": "food_life_fruit", "display_name": "Quả Sinh Mệnh"},
		{"id": "food_eternal_nectar", "display_name": "Mật Trường Sinh"},
	],
}

const GROWTH_DEFINITIONS_BY_RARITY := {
	"common": [
		{"id": "growth_vitamin_gel", "display_name": "Gel vitamin"},
		{"id": "growth_nutrient_serum", "display_name": "Dịch dinh dưỡng"},
		{"id": "growth_metabolic_yeast", "display_name": "Men chuyển hóa"},
		{"id": "growth_basic_tonic", "display_name": "Thuốc bổ tăng trưởng"},
	],
	"uncommon": [
		{"id": "growth_concentrate", "display_name": "Tinh chất tăng trưởng"},
		{"id": "growth_accelerator", "display_name": "Dung dịch tăng tốc"},
		{"id": "growth_bio_catalyst", "display_name": "Xúc tác sinh học"},
		{"id": "growth_absorption_serum", "display_name": "Dịch hấp thu"},
	],
	"rare": [
		{"id": "growth_spirit_serum", "display_name": "Huyết thanh linh lực"},
		{"id": "growth_crystal_extract", "display_name": "Tinh chất pha lê"},
		{"id": "growth_adaptive_enzyme", "display_name": "Enzyme thích nghi"},
		{"id": "growth_vital_core", "display_name": "Lõi sinh lực"},
	],
	"epic": [
		{"id": "growth_nebula_serum", "display_name": "Huyết thanh Tinh Vân"},
		{"id": "growth_ancient_catalyst", "display_name": "Xúc tác Cổ Đại"},
		{"id": "growth_evolution_essence", "display_name": "Tinh chất Tiến Hóa"},
		{"id": "growth_star_core", "display_name": "Lõi Sao"},
	],
	"legendary": [
		{"id": "growth_life_core", "display_name": "Lõi Sinh Mệnh"},
		{"id": "growth_celestial_essence", "display_name": "Tinh chất Thiên Thể"},
		{"id": "growth_genesis_serum", "display_name": "Huyết thanh Khởi Nguyên"},
		{"id": "growth_eternal_core", "display_name": "Lõi Trường Sinh"},
	],
}

const RARITY_WEIGHTS := {
	"common": 55.0,
	"uncommon": 25.0,
	"rare": 13.0,
	"epic": 6.0,
	"legendary": 1.0,
}

const QUALITY_WEIGHTS := {
	"broken": 15.0,
	"poor": 25.0,
	"normal": 35.0,
	"good": 20.0,
	"perfect": 5.0,
}

const BASIC_INFANT_QUALITY_WEIGHTS := {
	"poor": 20.0,
	"normal": 65.0,
	"good": 15.0,
}

const QUALITY_MULTIPLIER := {
	"broken": 0.35,
	"poor": 0.65,
	"normal": 0.95,
	"good": 1.30,
	"perfect": 1.75,
}

const DEFECT_CHANCE := {
	"broken": 0.85,
	"poor": 0.55,
	"normal": 0.25,
	"good": 0.08,
	"perfect": 0.02,
}

const SECONDARY_EFFECT_LEVEL_LABELS := {
	1: "I • Nhẹ",
	2: "II • Vừa",
	3: "III • Mạnh",
	4: "IV • Cực mạnh",
}

const POSITIVE_LEVEL_WEIGHTS_BY_RARITY := {
	"common": {1: 100.0},
	"uncommon": {1: 70.0, 2: 30.0},
	"rare": {1: 15.0, 2: 65.0, 3: 20.0},
	"epic": {2: 25.0, 3: 60.0, 4: 15.0},
	"legendary": {3: 45.0, 4: 55.0},
}

const NEGATIVE_LEVEL_WEIGHTS_BY_QUALITY := {
	"perfect": {1: 100.0},
	"good": {1: 85.0, 2: 15.0},
	"normal": {1: 50.0, 2: 40.0, 3: 10.0},
	"poor": {2: 40.0, 3: 45.0, 4: 15.0},
	"broken": {3: 35.0, 4: 65.0},
}

const FOOD_PROPERTIES: Array[StringName] = [
	&"fresh",
	&"dense",
	&"nutritious",
	&"growth_rich",
	&"easy_digest",
	&"vitality",
]

const FOOD_DEFECTS: Array[StringName] = [
	&"spoiled",
	&"stale",
	&"heavy",
	&"rotten",
	&"bloated",
	&"contaminated",
]

const GROWTH_PROPERTIES: Array[StringName] = [
	&"concentrated",
	&"rapid",
	&"pure",
	&"burst",
	&"stable",
	&"efficient",
]

const GROWTH_DEFECTS: Array[StringName] = [
	&"diluted",
	&"expired",
	&"appetite_drain",
	&"backfire",
	&"unstable",
	&"residue",
]

const FUTURE_FAMILIES: Array[StringName] = [
	&"gene_fragment",
	&"element_fragment",
	&"mutation_fragment",
]

const STAGE_VALUE_MULTIPLIERS := {
	1: 1.0,
	2: 12.0,
	3: 18.0,
}


func generate(
	item_type: StringName,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))

	var rarity: String = _roll_weighted(rng, RARITY_WEIGHTS)
	var quality: String = _roll_weighted(rng, QUALITY_WEIGHTS)

	match item_type:
		TYPE_FOOD:
			return _generate_food(rng, rarity, quality, seed_value)
		TYPE_GROWTH:
			return _generate_growth(rng, rarity, quality, seed_value)
		TYPE_FUTURE_FRAGMENT:
			return _generate_future_fragment(rng, rarity, quality, seed_value)
		_:
			push_error("ItemGenerator: unsupported item type: " + String(item_type))
			return {}


func generate_resource_for_rarity(
	item_type: StringName,
	seed_value: int,
	rarity: String
) -> Dictionary:
	var normalized_rarity := rarity.strip_edges().to_lower()

	if not RESOURCE_RARITY_STATS.has(
		normalized_rarity
	):
		return {}

	if (
		item_type != TYPE_FOOD
		and item_type != TYPE_GROWTH
	):
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))
	var quality: String = _roll_weighted(
		rng,
		QUALITY_WEIGHTS
	)

	if item_type == TYPE_FOOD:
		return _generate_food(
			rng,
			normalized_rarity,
			quality,
			seed_value
		)

	return _generate_growth(
		rng,
		normalized_rarity,
		quality,
		seed_value
	)


func resource_definition_count(
	item_type: StringName,
	rarity: String
) -> int:
	var normalized_rarity := rarity.strip_edges().to_lower()
	var catalog: Dictionary = {}

	if item_type == TYPE_FOOD:
		catalog = FOOD_DEFINITIONS_BY_RARITY
	elif item_type == TYPE_GROWTH:
		catalog = GROWTH_DEFINITIONS_BY_RARITY
	else:
		return 0

	var value: Variant = catalog.get(
		normalized_rarity,
		[]
	)

	if typeof(value) != TYPE_ARRAY:
		return 0

	return (value as Array).size()


func resource_base_range_for_rarity(
	item_type: StringName,
	rarity: String
) -> Vector2i:
	var stats: Dictionary = RESOURCE_RARITY_STATS.get(
		rarity.strip_edges().to_lower(),
		{}
	)

	if stats.is_empty():
		return Vector2i.ZERO

	if item_type == TYPE_FOOD:
		return Vector2i(
			int(stats.get("food_min_seconds", 0)),
			int(stats.get("food_max_seconds", 0))
		)

	if item_type == TYPE_GROWTH:
		return Vector2i(
			int(stats.get("growth_min_seconds", 0)),
			int(stats.get("growth_max_seconds", 0))
		)

	return Vector2i.ZERO


func generate_for_stage(
	item_type: StringName,
	seed_value: int,
	stage_index: int
) -> Dictionary:
	var item := generate(
		item_type,
		seed_value
	)

	if item.is_empty():
		return {}

	return scale_for_stage(
		item,
		stage_index
	)


func scale_for_stage(
	item: Dictionary,
	stage_index: int
) -> Dictionary:
	var result := item.duplicate(
		true
	)
	var item_type := StringName(
		result.get(
			"item_type",
			""
		)
	)

	if (
		item_type != TYPE_FOOD
		and item_type != TYPE_GROWTH
	):
		return result

	var multiplier := float(
		STAGE_VALUE_MULTIPLIERS.get(
			stage_index,
			1.0
		)
	)

	for field in [
		"main_value_seconds",
		"growth_delta_seconds",
		"food_delta_seconds",
	]:
		if result.has(
			field
		):
			result[field] = int(
				round(
					float(
						result[field]
					) * multiplier
				)
			)

	result["generated_for_stage"] = stage_index
	result["stage_value_multiplier"] = multiplier
	return result


func generate_gene(
	definition: GeneDefinition,
	seed_value: int
) -> Dictionary:
	if definition == null or not definition.is_valid():
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))
	var rarity: String = _roll_weighted(
		rng,
		RARITY_WEIGHTS
	)
	var quality := "normal"
	var stats: Dictionary = GENE_RARITY_STATS.get(
		rarity,
		GENE_RARITY_STATS["uncommon"]
	)
	var gene_score := float(
		stats.get(
			"score",
			definition.primary_influence()
		)
	)
	var growth_bonus := float(
		stats.get(
			"growth",
			GENE_GROWTH_BONUS_PERCENT
		)
	)
	var source_tags := definition.influence_tags()
	var scaled_tags: Dictionary = {}
	var influence_scale := (
		gene_score
		/ maxf(
			1.0,
			definition.primary_influence()
		)
	)

	for key_value in source_tags.keys():
		scaled_tags[String(key_value)] = (
			float(source_tags[key_value])
			* influence_scale
		)

	return {
		"uid": (
			"gene_%s_%s"
			% [
				String(definition.id()),
				str(abs(seed_value)),
			]
		),
		"definition_id": String(definition.id()),
		"item_type": String(TYPE_GENE),
		"display_name": definition.display_name(),
		"rarity": rarity,
		"quality": quality,
		"gene_id": String(definition.id()),
		"gene_locus": String(definition.locus()),
		"gene_direction": String(definition.direction()),
		"gene_element_lock": String(definition.element_lock()),
		"gene_score": gene_score,
		"gene_influence": gene_score,
		"gene_expression_tier": String(
			GeneExpressionScale.tier_for_score(
				gene_score
			)
		),
		"growth_bonus_percent": growth_bonus,
		"influence_tags": scaled_tags,
		"main_value_seconds": 0,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "gene_dust",
		"salvage_value": _salvage_value(
			rarity,
			quality,
			rng
		),
		"generated_seed": seed_value,
		"usable_stage": "gene",
	}


func gene_score_for_rarity(
	rarity: String
) -> float:
	var stats: Dictionary = GENE_RARITY_STATS.get(
		rarity.strip_edges().to_lower(),
		{}
	)
	return float(
		stats.get(
			"score",
			0.0
		)
	)


func gene_growth_for_rarity(
	rarity: String
) -> float:
	var stats: Dictionary = GENE_RARITY_STATS.get(
		rarity.strip_edges().to_lower(),
		{}
	)
	return float(
		stats.get(
			"growth",
			0.0
		)
	)


func secondary_effect_level_label(
	level: int
) -> String:
	return String(
		SECONDARY_EFFECT_LEVEL_LABELS.get(
			clampi(level, 1, 4),
			"I • Nhẹ"
		)
	)


func generate_basic_infant(
	item_type: StringName,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))

	var rarity := "common"
	var quality: String = _roll_weighted(
		rng,
		BASIC_INFANT_QUALITY_WEIGHTS
	)

	match item_type:
		TYPE_FOOD:
			return _generate_food(rng, rarity, quality, seed_value)
		TYPE_GROWTH:
			return _generate_growth(rng, rarity, quality, seed_value)
		_:
			push_error(
				"ItemGenerator: unsupported basic infant type: "
				+ String(item_type)
			)
			return {}


func describe(item: Dictionary) -> String:
	var item_type := StringName(item.get("item_type", ""))

	match item_type:
		TYPE_FOOD:
			var food_seconds := int(item.get("main_value_seconds", 0))
			var growth_delta := int(item.get("growth_delta_seconds", 0))
			var text := "No +" + _format_minutes(food_seconds)
			if growth_delta > 0:
				text += " • Trưởng thành -" + _format_minutes(growth_delta)
			elif growth_delta < 0:
				text += " • Trưởng thành +" + _format_minutes(abs(growth_delta))
			return text

		TYPE_GROWTH:
			var growth_seconds := int(item.get("main_value_seconds", 0))
			var food_delta := int(item.get("food_delta_seconds", 0))
			var text := ""
			if growth_seconds >= 0:
				text = "Trưởng thành -" + _format_minutes(growth_seconds)
			else:
				text = "Trưởng thành +" + _format_minutes(abs(growth_seconds))
			if food_delta > 0:
				text += " • No +" + _format_minutes(food_delta)
			elif food_delta < 0:
				text += " • Mất " + _format_minutes(abs(food_delta)) + " thức ăn"
			return text

		TYPE_GENE:
			var gene_text := (
				"Gene "
				+ String(
					item.get(
						"gene_locus",
						"?"
					)
				)
				+ " → "
				+ String(
					item.get(
						"gene_direction",
						"?"
					)
				)
				+ " • Điểm +"
				+ str(
					int(
						round(
							float(
								item.get(
									"gene_score",
									item.get(
										"gene_influence",
										0.0
									)
								)
							)
						)
					)
				)
				+ " • Growth +"
				+ str(
					int(
						round(
							float(
								item.get(
									"growth_bonus_percent",
									GENE_GROWTH_BONUS_PERCENT
								)
							)
						)
					)
				)
				+ "%"
			)
			var element_lock := String(
				item.get(
					"gene_element_lock",
					""
				)
			)
			if not element_lock.is_empty():
				gene_text += " • Hệ " + element_lock.capitalize()
			return gene_text

		TYPE_FUTURE_FRAGMENT:
			return "Mảnh dành cho giai đoạn sau • chưa thể dùng"

	return "Không rõ hiệu ứng"


func rarity_label(value: String) -> String:
	match value:
		"common":
			return "COMMON"
		"uncommon":
			return "UNCOMMON"
		"rare":
			return "RARE"
		"epic":
			return "EPIC"
		"legendary":
			return "LEGENDARY"
		_:
			return value.to_upper()


func quality_label(value: String) -> String:
	match value:
		"broken":
			return "Hỏng"
		"poor":
			return "Kém"
		"normal":
			return "Thường"
		"good":
			return "Tốt"
		"perfect":
			return "Hoàn hảo"
		_:
			return value


func property_label(value: StringName) -> String:
	match value:
		&"fresh":
			return "Tươi"
		&"dense":
			return "Đậm đặc"
		&"nutritious":
			return "Dinh dưỡng"
		&"growth_rich":
			return "Giàu tăng trưởng"
		&"easy_digest":
			return "Dễ tiêu"
		&"vitality":
			return "Bồi bổ"
		&"concentrated":
			return "Cô đặc"
		&"rapid":
			return "Tác dụng nhanh"
		&"pure":
			return "Tinh khiết"
		&"burst":
			return "Bùng trưởng"
		&"stable":
			return "Ổn định"
		&"efficient":
			return "Hấp thu cao"
		_:
			return String(value)


func defect_label(value: StringName) -> String:
	match value:
		&"spoiled":
			return "Ôi"
		&"stale":
			return "Cũ"
		&"heavy":
			return "Khó tiêu"
		&"rotten":
			return "Hỏng nặng"
		&"diluted":
			return "Pha loãng"
		&"expired":
			return "Hết hạn"
		&"appetite_drain":
			return "Hao thức ăn"
		&"backfire":
			return "Phản tác dụng"
		&"bloated":
			return "Đầy bụng"
		&"contaminated":
			return "Nhiễm tạp"
		&"unstable":
			return "Bất ổn"
		&"residue":
			return "Dư chất"
		_:
			return String(value)


func _generate_food(
	rng: RandomNumberGenerator,
	rarity: String,
	quality: String,
	seed_value: int
) -> Dictionary:
	var stats: Dictionary = RESOURCE_RARITY_STATS.get(
		rarity,
		RESOURCE_RARITY_STATS["common"]
	)
	var definition := _pick_resource_definition(
		rng,
		FOOD_DEFINITIONS_BY_RARITY,
		rarity
	)
	var base_seconds := rng.randi_range(
		int(stats.get("food_min_seconds", 20 * 60)),
		int(stats.get("food_max_seconds", 30 * 60))
	)
	var main_seconds := int(round(
		float(base_seconds) * float(QUALITY_MULTIPLIER[quality])
	))
	var growth_delta := 0

	var properties := _roll_properties(
		rng,
		rarity,
		FOOD_PROPERTIES
	)

	var defects := _roll_defects(
		rng,
		quality,
		FOOD_DEFECTS
	)
	var secondary_effects := _build_secondary_effects(
		rng,
		properties,
		defects,
		rarity,
		quality
	)

	for effect in secondary_effects:
		var effect_id := StringName(
			effect.get(
				"id",
				""
			)
		)
		var level := clampi(
			int(
				effect.get(
					"level",
					1
				)
			),
			1,
			4
		)

		match effect_id:
			&"fresh":
				main_seconds = int(round(
					float(main_seconds)
					* (1.0 + 0.12 * level)
				))
			&"dense":
				main_seconds += [
					10, 20, 35, 55
				][level - 1] * 60
			&"nutritious":
				growth_delta += [
					2, 5, 10, 18
				][level - 1] * 60
			&"growth_rich":
				main_seconds = int(round(
					float(main_seconds)
					* [0.95, 0.90, 0.85, 0.80][level - 1]
				))
				growth_delta += [
					5, 10, 18, 30
				][level - 1] * 60
			&"easy_digest":
				growth_delta += [
					1, 3, 6, 10
				][level - 1] * 60
			&"vitality":
				main_seconds += [
					5, 10, 20, 35
				][level - 1] * 60
				growth_delta += [
					1, 3, 5, 8
				][level - 1] * 60
			&"spoiled":
				main_seconds = int(round(
					float(main_seconds)
					* [0.85, 0.70, 0.55, 0.40][level - 1]
				))
			&"stale":
				main_seconds = int(round(
					float(main_seconds)
					* [0.90, 0.80, 0.70, 0.60][level - 1]
				))
			&"heavy":
				growth_delta -= [
					2, 5, 10, 18
				][level - 1] * 60
			&"rotten":
				main_seconds = int(round(
					float(main_seconds)
					* [0.75, 0.50, 0.30, 0.15][level - 1]
				))
				growth_delta -= [
					2, 6, 12, 20
				][level - 1] * 60
			&"bloated":
				growth_delta -= [
					1, 4, 8, 15
				][level - 1] * 60
			&"contaminated":
				main_seconds = int(round(
					float(main_seconds)
					* [0.92, 0.82, 0.68, 0.50][level - 1]
				))
				growth_delta -= [
					3, 7, 14, 25
				][level - 1] * 60

	main_seconds = max(60, main_seconds)

	return {
		"uid": _make_uid(seed_value, TYPE_FOOD),
		"definition_id": String(
			definition.get(
				"id",
				"food"
			)
		),
		"item_type": String(TYPE_FOOD),
		"display_name": _food_name(
			String(
				definition.get(
					"display_name",
					"Khẩu phần"
				)
			),
			quality,
			properties,
			defects
		),
		"base_display_name": String(
			definition.get(
				"display_name",
				"Khẩu phần"
			)
		),
		"rarity": rarity,
		"quality": quality,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": growth_delta,
		"food_delta_seconds": 0,
		"properties": properties,
		"defects": defects,
		"secondary_effects": secondary_effects,
		"salvage_type": "food_dust",
		"salvage_value": _salvage_value(rarity, quality, rng),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_growth(
	rng: RandomNumberGenerator,
	rarity: String,
	quality: String,
	seed_value: int
) -> Dictionary:
	var stats: Dictionary = RESOURCE_RARITY_STATS.get(
		rarity,
		RESOURCE_RARITY_STATS["common"]
	)
	var definition := _pick_resource_definition(
		rng,
		GROWTH_DEFINITIONS_BY_RARITY,
		rarity
	)
	var base_seconds := rng.randi_range(
		int(stats.get("growth_min_seconds", 6 * 60)),
		int(stats.get("growth_max_seconds", 12 * 60))
	)
	var main_seconds := int(round(
		float(base_seconds) * float(QUALITY_MULTIPLIER[quality])
	))
	var food_delta := 0

	var properties := _roll_properties(
		rng,
		rarity,
		GROWTH_PROPERTIES
	)

	var defects := _roll_defects(
		rng,
		quality,
		GROWTH_DEFECTS
	)
	var secondary_effects := _build_secondary_effects(
		rng,
		properties,
		defects,
		rarity,
		quality
	)

	for effect in secondary_effects:
		var effect_id := StringName(
			effect.get(
				"id",
				""
			)
		)
		var level := clampi(
			int(
				effect.get(
					"level",
					1
				)
			),
			1,
			4
		)

		match effect_id:
			&"concentrated":
				main_seconds = int(round(
					float(main_seconds)
					* [1.15, 1.30, 1.50, 1.80][level - 1]
				))
			&"rapid":
				main_seconds += [
					3, 7, 12, 20
				][level - 1] * 60
			&"pure":
				main_seconds = int(round(
					float(main_seconds)
					* [1.10, 1.20, 1.35, 1.55][level - 1]
				))
			&"burst":
				var burst_chance := [
					0.10, 0.20, 0.35, 0.50
				][level - 1]
				if rng.randf() <= burst_chance:
					main_seconds = int(round(
						float(main_seconds)
						* [1.25, 1.50, 1.75, 2.00][level - 1]
					))
			&"stable":
				food_delta += [
					3, 6, 12, 20
				][level - 1] * 60
			&"efficient":
				main_seconds += [
					2, 5, 9, 15
				][level - 1] * 60
				food_delta += [
					2, 5, 10, 15
				][level - 1] * 60
			&"diluted":
				main_seconds = int(round(
					float(main_seconds)
					* [0.85, 0.70, 0.50, 0.35][level - 1]
				))
			&"expired":
				main_seconds = int(round(
					float(main_seconds)
					* [0.75, 0.55, 0.35, 0.20][level - 1]
				))
			&"appetite_drain":
				food_delta -= [
					5, 10, 20, 35
				][level - 1] * 60
			&"backfire":
				var backfire_chance := [
					0.15, 0.30, 0.55, 0.80
				][level - 1]
				if rng.randf() <= backfire_chance:
					main_seconds = -[
						2, 5, 12, 25
					][level - 1] * 60
			&"unstable":
				main_seconds = int(round(
					float(main_seconds)
					* [0.92, 0.82, 0.68, 0.50][level - 1]
				))
			&"residue":
				main_seconds -= [
					1, 3, 6, 10
				][level - 1] * 60
				food_delta -= [
					3, 8, 15, 25
				][level - 1] * 60

	if main_seconds == 0:
		main_seconds = 60

	return {
		"uid": _make_uid(seed_value, TYPE_GROWTH),
		"definition_id": String(
			definition.get(
				"id",
				"growth"
			)
		),
		"item_type": String(TYPE_GROWTH),
		"display_name": _growth_name(
			String(
				definition.get(
					"display_name",
					"Gel tăng trưởng"
				)
			),
			quality,
			properties,
			defects
		),
		"base_display_name": String(
			definition.get(
				"display_name",
				"Gel tăng trưởng"
			)
		),
		"rarity": rarity,
		"quality": quality,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": 0,
		"food_delta_seconds": food_delta,
		"properties": properties,
		"defects": defects,
		"secondary_effects": secondary_effects,
		"salvage_type": "growth_dust",
		"salvage_value": _salvage_value(rarity, quality, rng),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_future_fragment(
	rng: RandomNumberGenerator,
	rarity: String,
	quality: String,
	seed_value: int
) -> Dictionary:
	var family: StringName = FUTURE_FAMILIES[
		rng.randi_range(0, FUTURE_FAMILIES.size() - 1)
	]

	return {
		"uid": _make_uid(seed_value, TYPE_FUTURE_FRAGMENT),
		"definition_id": String(family),
		"item_type": String(TYPE_FUTURE_FRAGMENT),
		"display_name": _future_fragment_name(family),
		"rarity": rarity,
		"quality": quality,
		"main_value_seconds": 0,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "mystery_dust",
		"salvage_value": _salvage_value(rarity, quality, rng),
		"generated_seed": seed_value,
		"usable_stage": "post_infant",
	}


func _build_secondary_effects(
	rng: RandomNumberGenerator,
	properties: Array[String],
	defects: Array[String],
	rarity: String,
	quality: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for property_id in properties:
		var positive_level := _roll_effect_level(
			rng,
			POSITIVE_LEVEL_WEIGHTS_BY_RARITY.get(
				rarity,
				{1: 100.0}
			)
		)
		result.append({
			"id": property_id,
			"polarity": "positive",
			"level": positive_level,
			"level_label": secondary_effect_level_label(
				positive_level
			),
			"label": property_label(
				StringName(property_id)
			),
		})

	for defect_id in defects:
		var negative_level := _roll_effect_level(
			rng,
			NEGATIVE_LEVEL_WEIGHTS_BY_QUALITY.get(
				quality,
				{1: 100.0}
			)
		)
		result.append({
			"id": defect_id,
			"polarity": "negative",
			"level": negative_level,
			"level_label": secondary_effect_level_label(
				negative_level
			),
			"label": defect_label(
				StringName(defect_id)
			),
		})

	return result


func _roll_effect_level(
	rng: RandomNumberGenerator,
	weights: Dictionary
) -> int:
	var total := 0.0

	for value in weights.values():
		total += float(value)

	if total <= 0.0:
		return 1

	var roll := rng.randf_range(
		0.0,
		total
	)
	var cursor := 0.0

	for key_value in weights.keys():
		cursor += float(
			weights[key_value]
		)

		if roll <= cursor:
			return clampi(
				int(key_value),
				1,
				4
			)

	return 1


func _roll_properties(
	rng: RandomNumberGenerator,
	rarity: String,
	pool: Array[StringName]
) -> Array[String]:
	var count := 0

	match rarity:
		"common":
			count = 0
		"uncommon":
			count = 1 if rng.randf() <= 0.45 else 0
		"rare":
			count = 1
		"epic":
			count = 1 + (1 if rng.randf() <= 0.5 else 0)
		"legendary":
			count = 2

	var result: Array[String] = []
	var available: Array[StringName] = pool.duplicate()

	for _index in range(min(count, available.size())):
		var pick_index := rng.randi_range(0, available.size() - 1)
		result.append(String(available[pick_index]))
		available.remove_at(pick_index)

	return result


func _roll_defects(
	rng: RandomNumberGenerator,
	quality: String,
	pool: Array[StringName]
) -> Array[String]:
	var result: Array[String] = []
	var chance := float(DEFECT_CHANCE[quality])

	if rng.randf() > chance:
		return result

	var first := pool[rng.randi_range(0, pool.size() - 1)]
	result.append(String(first))

	if quality == "broken" and rng.randf() <= 0.35:
		var available: Array[StringName] = pool.duplicate()
		available.erase(first)

		if not available.is_empty():
			result.append(String(
				available[rng.randi_range(0, available.size() - 1)]
			))

	return result


func _roll_weighted(
	rng: RandomNumberGenerator,
	weights: Dictionary
) -> String:
	var total := 0.0

	for value in weights.values():
		total += float(value)

	var roll := rng.randf_range(0.0, total)
	var cursor := 0.0

	for key in weights.keys():
		cursor += float(weights[key])

		if roll <= cursor:
			return String(key)

	return String(weights.keys().back())


func _salvage_value(
	rarity: String,
	quality: String,
	rng: RandomNumberGenerator
) -> int:
	var rarity_base: int = {
		"common": 2,
		"uncommon": 4,
		"rare": 8,
		"epic": 16,
		"legendary": 36,
	}.get(rarity, 1)

	var quality_bonus: int = {
		"broken": 0,
		"poor": 1,
		"normal": 2,
		"good": 3,
		"perfect": 5,
	}.get(quality, 0)

	return int(rarity_base) + int(quality_bonus) + rng.randi_range(0, 2)


func _food_name(
	base_name: String,
	quality: String,
	_properties: Array[String],
	defects: Array[String]
) -> String:
	if defects.has("rotten"):
		return "Hỏng nặng: " + base_name
	if defects.has("spoiled"):
		return "Ôi: " + base_name

	match quality:
		"broken":
			return "Mẻ lỗi: " + base_name
		"poor":
			return "Loại kém: " + base_name
		"good":
			return "Loại tốt: " + base_name
		"perfect":
			return "Hoàn hảo: " + base_name
		_:
			return base_name


func _growth_name(
	base_name: String,
	quality: String,
	_properties: Array[String],
	defects: Array[String]
) -> String:
	if defects.has("backfire"):
		return "Bất ổn: " + base_name
	if defects.has("expired"):
		return "Hết hạn: " + base_name

	match quality:
		"broken":
			return "Mẻ lỗi: " + base_name
		"poor":
			return "Loại kém: " + base_name
		"good":
			return "Loại tốt: " + base_name
		"perfect":
			return "Hoàn hảo: " + base_name
		_:
			return base_name


func _pick_resource_definition(
	rng: RandomNumberGenerator,
	catalog: Dictionary,
	rarity: String
) -> Dictionary:
	var value: Variant = catalog.get(
		rarity,
		[]
	)

	if (
		typeof(value) != TYPE_ARRAY
		or (value as Array).is_empty()
	):
		value = catalog.get(
			"common",
			[]
		)

	if (
		typeof(value) != TYPE_ARRAY
		or (value as Array).is_empty()
	):
		return {}

	var pool := value as Array
	var picked: Variant = pool[
		rng.randi_range(
			0,
			pool.size() - 1
		)
	]

	if typeof(picked) != TYPE_DICTIONARY:
		return {}

	return (picked as Dictionary).duplicate(
		true
	)


func _future_fragment_name(family: StringName) -> String:
	match family:
		&"gene_fragment":
			return "Mảnh Gene chưa xác định"
		&"element_fragment":
			return "Mảnh Nguyên Tố chưa xác định"
		&"mutation_fragment":
			return "Mảnh Dị Biến chưa xác định"
		_:
			return "Mảnh chưa xác định"


func _make_uid(
	seed_value: int,
	item_type: StringName
) -> String:
	return "%s_%s" % [
		String(item_type),
		str(abs(seed_value)),
	]


func _format_minutes(seconds: int) -> String:
	var minutes := float(seconds) / 60.0

	if minutes < 10.0:
		return "%.1f phút" % minutes

	return "%d phút" % int(round(minutes))
