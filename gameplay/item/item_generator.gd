class_name ItemGenerator
extends RefCounted


const TYPE_FOOD: StringName = &"food"
const TYPE_GROWTH: StringName = &"growth"
const TYPE_GENE: StringName = &"gene"
const TYPE_FUTURE_FRAGMENT: StringName = &"future_fragment"

const ITEM_SCHEMA_VERSION: int = 2
const GENE_GROWTH_BONUS_PERCENT: float = 5.0

# Rarity is now the only strength tier for normal consumables.
# Junk is rolled separately and intentionally has no rarity.
const RARITY_WEIGHTS := {
	"common": 55.0,
	"uncommon": 25.0,
	"rare": 13.0,
	"epic": 6.0,
	"legendary": 1.0,
}

const JUNK_CHANCE: float = 0.12
const BASIC_INFANT_JUNK_CHANCE: float = 0.05

# Fixed Stage-1 values. Stage 2/3 scale through STAGE_VALUE_MULTIPLIERS.
# Food is designed so Legendary fills the whole food bar at every live stage.
const FOOD_VALUE_SECONDS := {
	"common": 20 * 60,
	"uncommon": 25 * 60,
	"rare": 30 * 60,
	"epic": 40 * 60,
	"legendary": 60 * 60,
}

const GROWTH_VALUE_SECONDS := {
	"common": 5 * 60,
	"uncommon": 7 * 60,
	"rare": 10 * 60,
	"epic": 14 * 60,
	"legendary": 20 * 60,
}

const JUNK_FOOD_SECONDS: int = 5 * 60
const JUNK_GROWTH_SECONDS: int = 2 * 60

const GENE_RARITY_STATS := {
	"common": {"score": 10.0, "growth": 2.0},
	"uncommon": {"score": 20.0, "growth": 5.0},
	"rare": {"score": 35.0, "growth": 7.0},
	"epic": {"score": 55.0, "growth": 10.0},
	"legendary": {"score": 80.0, "growth": 15.0},
}

const STAGE_VALUE_MULTIPLIERS := {
	1: 1.0,
	2: 12.0,
	3: 18.0,
}

# Legacy IDs are retained for old-save labels only. New items do not roll
# properties, defects or quality multipliers.
const FOOD_PROPERTIES: Array[StringName] = [
	&"fresh",
	&"dense",
	&"nutritious",
	&"growth_rich",
]

const FOOD_DEFECTS: Array[StringName] = [
	&"spoiled",
	&"stale",
	&"heavy",
	&"rotten",
]

const GROWTH_PROPERTIES: Array[StringName] = [
	&"concentrated",
	&"rapid",
	&"pure",
	&"burst",
]

const GROWTH_DEFECTS: Array[StringName] = [
	&"diluted",
	&"expired",
	&"appetite_drain",
	&"backfire",
]

const FUTURE_FAMILIES: Array[StringName] = [
	&"gene_fragment",
	&"element_fragment",
	&"mutation_fragment",
]


func generate(
	item_type: StringName,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))

	match item_type:
		TYPE_FOOD:
			if rng.randf() <= JUNK_CHANCE:
				return _generate_junk_food(seed_value)
			return _generate_food(
				_roll_weighted(rng, RARITY_WEIGHTS),
				seed_value
			)

		TYPE_GROWTH:
			if rng.randf() <= JUNK_CHANCE:
				return _generate_junk_growth(seed_value)
			return _generate_growth(
				_roll_weighted(rng, RARITY_WEIGHTS),
				seed_value
			)

		TYPE_FUTURE_FRAGMENT:
			return _generate_future_fragment(
				rng,
				_roll_weighted(rng, RARITY_WEIGHTS),
				seed_value
			)

		_:
			push_error(
				"ItemGenerator: unsupported item type: "
				+ String(item_type)
			)
			return {}


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
	var result := item.duplicate(true)
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
		if result.has(field):
			result[field] = int(
				round(
					float(result[field])
					* multiplier
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
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": definition.display_name(),
		"rarity": rarity,
		"quality": "standard",
		"is_junk": false,
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
		"salvage_value": _salvage_value_for_rarity(rarity),
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


func generate_basic_infant(
	item_type: StringName,
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))

	match item_type:
		TYPE_FOOD:
			if rng.randf() <= BASIC_INFANT_JUNK_CHANCE:
				return _generate_junk_food(seed_value)
			return _generate_food("common", seed_value)

		TYPE_GROWTH:
			if rng.randf() <= BASIC_INFANT_JUNK_CHANCE:
				return _generate_junk_growth(seed_value)
			return _generate_growth("common", seed_value)

		_:
			push_error(
				"ItemGenerator: unsupported basic infant type: "
				+ String(item_type)
			)
			return {}


func describe(item: Dictionary) -> String:
	if bool(item.get("is_junk", false)):
		return "Phế phẩm • không có rarity • nên phân giải"

	var item_type := StringName(
		item.get(
			"item_type",
			""
		)
	)

	match item_type:
		TYPE_FOOD:
			var food_seconds := int(
				item.get(
					"main_value_seconds",
					0
				)
			)
			return "Độ no +" + _format_minutes(
				food_seconds
			)

		TYPE_GROWTH:
			var growth_seconds := int(
				item.get(
					"main_value_seconds",
					0
				)
			)
			return (
				"Trưởng thành -"
				+ _format_minutes(
					maxi(
						0,
						growth_seconds
					)
				)
			)

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
				gene_text += (
					" • Hệ "
					+ element_lock.capitalize()
				)
			return gene_text

		TYPE_FUTURE_FRAGMENT:
			return "Mảnh dành cho giai đoạn sau • chưa thể dùng"

	return "Không rõ hiệu ứng"


func rarity_label(value: String) -> String:
	match value.strip_edges().to_lower():
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
		"", "junk":
			return ""
		_:
			return value.to_upper()


func quality_label(value: String) -> String:
	# Kept for backward compatibility with legacy saves/UI calls.
	match value:
		"standard":
			return ""
		"junk":
			return "PHẾ PHẨM"
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
		&"concentrated":
			return "Cô đặc"
		&"rapid":
			return "Tác dụng nhanh"
		&"pure":
			return "Tinh khiết"
		&"burst":
			return "Bùng trưởng"
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
		_:
			return String(value)


static func normalize_item(
	item: Dictionary
) -> Dictionary:
	var result := item.duplicate(true)

	if int(
		result.get(
			"item_schema_version",
			0
		)
	) >= ITEM_SCHEMA_VERSION:
		return result

	var item_type := StringName(
		result.get(
			"item_type",
			""
		)
	)

	match item_type:
		TYPE_FOOD, TYPE_GROWTH:
			var defects_value: Variant = result.get(
				"defects",
				[]
			)
			var has_legacy_defect := (
				typeof(defects_value) == TYPE_ARRAY
				and not (defects_value as Array).is_empty()
			)
			var quality := String(
				result.get(
					"quality",
					"normal"
				)
			)
			var junk := (
				bool(
					result.get(
						"is_junk",
						false
					)
				)
				or quality == "broken"
				or has_legacy_defect
			)
			var rarity := _normalized_rarity(
				String(
					result.get(
						"rarity",
						"common"
					)
				)
			)
			var stage_index := int(
				result.get(
					"generated_for_stage",
					1
				)
			)
			var multiplier := _stage_multiplier(
				stage_index
			)

			result["properties"] = []
			result["defects"] = []
			result["growth_delta_seconds"] = 0
			result["food_delta_seconds"] = 0
			result["is_junk"] = junk

			if junk:
				result["rarity"] = ""
				result["quality"] = "junk"
				result["salvage_value"] = 1

				if item_type == TYPE_FOOD:
					result["definition_id"] = "food_junk"
					result["display_name"] = "Thức ăn hỏng"
					result["main_value_seconds"] = int(
						round(
							JUNK_FOOD_SECONDS
							* multiplier
						)
					)
				else:
					result["definition_id"] = "growth_junk"
					result["display_name"] = "Tinh chất lỗi"
					result["main_value_seconds"] = int(
						round(
							JUNK_GROWTH_SECONDS
							* multiplier
						)
					)
			else:
				result["rarity"] = rarity
				result["quality"] = "standard"
				result["salvage_value"] = (
					_salvage_value_for_rarity(
						rarity
					)
				)

				if item_type == TYPE_FOOD:
					result["definition_id"] = "food"
					result["display_name"] = "Khẩu phần dinh dưỡng"
					result["main_value_seconds"] = int(
						round(
							float(
								FOOD_VALUE_SECONDS.get(
									rarity,
									FOOD_VALUE_SECONDS["common"]
								)
							)
							* multiplier
						)
					)
				else:
					result["definition_id"] = "growth"
					result["display_name"] = "Tinh chất tăng trưởng"
					result["main_value_seconds"] = int(
						round(
							float(
								GROWTH_VALUE_SECONDS.get(
									rarity,
									GROWTH_VALUE_SECONDS["common"]
								)
							)
							* multiplier
						)
					)

			result["stage_value_multiplier"] = multiplier

		TYPE_GENE:
			result["quality"] = "standard"
			result["is_junk"] = false
			result["properties"] = []
			result["defects"] = []

		TYPE_FUTURE_FRAGMENT:
			result["quality"] = "standard"
			result["is_junk"] = false
			result["properties"] = []
			result["defects"] = []

	result["item_schema_version"] = ITEM_SCHEMA_VERSION
	return result


func _generate_food(
	rarity: String,
	seed_value: int
) -> Dictionary:
	var normalized := _normalized_rarity(
		rarity
	)

	return {
		"uid": _make_uid(
			seed_value,
			TYPE_FOOD
		),
		"definition_id": "food",
		"item_type": String(TYPE_FOOD),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Khẩu phần dinh dưỡng",
		"rarity": normalized,
		"quality": "standard",
		"is_junk": false,
		"main_value_seconds": int(
			FOOD_VALUE_SECONDS.get(
				normalized,
				FOOD_VALUE_SECONDS["common"]
			)
		),
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "food_dust",
		"salvage_value": _salvage_value_for_rarity(
			normalized
		),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_growth(
	rarity: String,
	seed_value: int
) -> Dictionary:
	var normalized := _normalized_rarity(
		rarity
	)

	return {
		"uid": _make_uid(
			seed_value,
			TYPE_GROWTH
		),
		"definition_id": "growth",
		"item_type": String(TYPE_GROWTH),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Tinh chất tăng trưởng",
		"rarity": normalized,
		"quality": "standard",
		"is_junk": false,
		"main_value_seconds": int(
			GROWTH_VALUE_SECONDS.get(
				normalized,
				GROWTH_VALUE_SECONDS["common"]
			)
		),
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "growth_dust",
		"salvage_value": _salvage_value_for_rarity(
			normalized
		),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_junk_food(
	seed_value: int
) -> Dictionary:
	return {
		"uid": _make_uid(
			seed_value,
			TYPE_FOOD
		),
		"definition_id": "food_junk",
		"item_type": String(TYPE_FOOD),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Thức ăn hỏng",
		"rarity": "",
		"quality": "junk",
		"is_junk": true,
		"main_value_seconds": JUNK_FOOD_SECONDS,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "food_dust",
		"salvage_value": 1,
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_junk_growth(
	seed_value: int
) -> Dictionary:
	return {
		"uid": _make_uid(
			seed_value,
			TYPE_GROWTH
		),
		"definition_id": "growth_junk",
		"item_type": String(TYPE_GROWTH),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Tinh chất lỗi",
		"rarity": "",
		"quality": "junk",
		"is_junk": true,
		"main_value_seconds": JUNK_GROWTH_SECONDS,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "growth_dust",
		"salvage_value": 1,
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_future_fragment(
	rng: RandomNumberGenerator,
	rarity: String,
	seed_value: int
) -> Dictionary:
	var family: StringName = FUTURE_FAMILIES[
		rng.randi_range(
			0,
			FUTURE_FAMILIES.size() - 1
		)
	]

	return {
		"uid": _make_uid(
			seed_value,
			TYPE_FUTURE_FRAGMENT
		),
		"definition_id": String(family),
		"item_type": String(TYPE_FUTURE_FRAGMENT),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": _future_fragment_name(
			family
		),
		"rarity": _normalized_rarity(
			rarity
		),
		"quality": "standard",
		"is_junk": false,
		"main_value_seconds": 0,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "mystery_dust",
		"salvage_value": _salvage_value_for_rarity(
			rarity
		),
		"generated_seed": seed_value,
		"usable_stage": "post_infant",
	}


func _roll_weighted(
	rng: RandomNumberGenerator,
	weights: Dictionary
) -> String:
	var total := 0.0

	for value in weights.values():
		total += float(value)

	var roll := rng.randf_range(
		0.0,
		total
	)
	var cursor := 0.0

	for key in weights.keys():
		cursor += float(
			weights[key]
		)

		if roll <= cursor:
			return String(key)

	return String(
		weights.keys().back()
	)


static func _salvage_value_for_rarity(
	rarity: String
) -> int:
	return int({
		"common": 2,
		"uncommon": 4,
		"rare": 8,
		"epic": 16,
		"legendary": 36,
	}.get(
		_normalized_rarity(
			rarity
		),
		1
	))


static func _normalized_rarity(
	rarity: String
) -> String:
	var normalized := rarity.strip_edges().to_lower()

	if RARITY_WEIGHTS.has(
		normalized
	):
		return normalized

	return "common"


static func _stage_multiplier(
	stage_index: int
) -> float:
	return float(
		STAGE_VALUE_MULTIPLIERS.get(
			stage_index,
			1.0
		)
	)


func _future_fragment_name(
	family: StringName
) -> String:
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


func _format_minutes(
	seconds: int
) -> String:
	var minutes := float(seconds) / 60.0

	if minutes < 10.0:
		return "%.1f phút" % minutes

	return "%d phút" % int(
		round(
			minutes
		)
	)
