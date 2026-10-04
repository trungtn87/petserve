class_name ItemGenerator
extends RefCounted


const TYPE_FOOD: StringName = &"food"
const TYPE_GROWTH: StringName = &"growth"
const TYPE_GENE: StringName = &"gene"
const TYPE_FUTURE_FRAGMENT: StringName = &"future_fragment"
const TYPE_GENE_FRAGMENT: StringName = &"gene_fragment"
const TYPE_MYTHIC_COMPONENT: StringName = &"mythic_component"

const ITEM_SCHEMA_VERSION: int = 3
const GENE_GROWTH_BONUS_PERCENT: float = 5.0
const GENE_RARITY_STATS := {
	# Every Gene rarity must create a visible phenotype on the next evolution.
	"common": {"score": 25.0, "growth": 2.0},
	"uncommon": {"score": 60.0, "growth": 5.0},
	"rare": {"score": 120.0, "growth": 7.0},
	"epic": {"score": 200.0, "growth": 10.0},
	"legendary": {"score": 320.0, "growth": 15.0},
}

const DUPLICATE_GENE_FRAGMENT_AMOUNT := {
	"common": 1,
	"uncommon": 1,
	"rare": 2,
	"epic": 4,
	"legendary": 7,
}

const MYTHIC_COMPONENT_DEFINITIONS := [
	{
		"id": "moon_beast_core_fragment",
		"display_name": "Mảnh Lõi Nguyệt Thú",
	},
	{
		"id": "ancient_shadow_gene_fragment",
		"display_name": "Mảnh Gen Bóng Tối Cổ",
	},
	{
		"id": "astral_catalyst_fragment",
		"display_name": "Mảnh Xúc Tác Tinh Giới",
	},
]

# Food/Growth now follow the same five rarity tiers as Gene items.
# Rarity determines the base value range; quality/properties/defects still
# mutate the individual item instance afterwards.
const RESOURCE_RARITY_STATS := {
	"common": {
		"food_min_seconds": 20 * 60,
		"food_max_seconds": 20 * 60,
		"growth_min_seconds": 5 * 60,
		"growth_max_seconds": 5 * 60,
	},
	"uncommon": {
		"food_min_seconds": 25 * 60,
		"food_max_seconds": 25 * 60,
		"growth_min_seconds": 7 * 60,
		"growth_max_seconds": 7 * 60,
	},
	"rare": {
		"food_min_seconds": 30 * 60,
		"food_max_seconds": 30 * 60,
		"growth_min_seconds": 10 * 60,
		"growth_max_seconds": 10 * 60,
	},
	"epic": {
		"food_min_seconds": 40 * 60,
		"food_max_seconds": 40 * 60,
		"growth_min_seconds": 14 * 60,
		"growth_max_seconds": 14 * 60,
	},
	"legendary": {
		"food_min_seconds": 60 * 60,
		"food_max_seconds": 60 * 60,
		"growth_min_seconds": 20 * 60,
		"growth_max_seconds": 20 * 60,
	},
}

const FOOD_DEFINITIONS_BY_RARITY := {
	"common": [{"id": "food_common", "display_name": "Khẩu phần dinh dưỡng"}],
	"uncommon": [{"id": "food_uncommon", "display_name": "Khẩu phần dinh dưỡng"}],
	"rare": [{"id": "food_rare", "display_name": "Khẩu phần dinh dưỡng"}],
	"epic": [{"id": "food_epic", "display_name": "Khẩu phần dinh dưỡng"}],
	"legendary": [{"id": "food_legendary", "display_name": "Khẩu phần dinh dưỡng"}],
}

const GROWTH_DEFINITIONS_BY_RARITY := {
	"common": [{"id": "growth_common", "display_name": "Tinh chất tăng trưởng"}],
	"uncommon": [{"id": "growth_uncommon", "display_name": "Tinh chất tăng trưởng"}],
	"rare": [{"id": "growth_rare", "display_name": "Tinh chất tăng trưởng"}],
	"epic": [{"id": "growth_epic", "display_name": "Tinh chất tăng trưởng"}],
	"legendary": [{"id": "growth_legendary", "display_name": "Tinh chất tăng trưởng"}],
}

const RARITY_WEIGHTS := {
	"common": 55.0,
	"uncommon": 25.0,
	"rare": 13.0,
	"epic": 6.0,
	"legendary": 1.0,
}

const JUNK_CHANCE: float = 0.12
const BASIC_INFANT_JUNK_CHANCE: float = 0.05
const JUNK_FOOD_SECONDS: int = 5 * 60
const JUNK_GROWTH_SECONDS: int = 2 * 60

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
	3: 12.0,
	4: 12.0,
}


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
				rng,
				_roll_weighted(rng, RARITY_WEIGHTS),
				"standard",
				seed_value
			)
		TYPE_GROWTH:
			if rng.randf() <= JUNK_CHANCE:
				return _generate_junk_growth(seed_value)
			return _generate_growth(
				rng,
				_roll_weighted(rng, RARITY_WEIGHTS),
				"standard",
				seed_value
			)
		TYPE_FUTURE_FRAGMENT:
			return _generate_future_fragment(
				rng,
				_roll_weighted(rng, RARITY_WEIGHTS),
				"standard",
				seed_value
			)
		_:
			push_error("ItemGenerator: unsupported item type: " + String(item_type))
			return {}

func generate_resource_for_rarity(
	item_type: StringName,
	seed_value: int,
	rarity: String
) -> Dictionary:
	var normalized_rarity := rarity.strip_edges().to_lower()

	if not RESOURCE_RARITY_STATS.has(normalized_rarity):
		return {}
	if item_type != TYPE_FOOD and item_type != TYPE_GROWTH:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = max(1, abs(seed_value))

	if item_type == TYPE_FOOD:
		return _generate_food(rng, normalized_rarity, "standard", seed_value)
	return _generate_growth(rng, normalized_rarity, "standard", seed_value)

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
		"salvage_value": _salvage_value(
			rarity,
			quality,
			rng
		),
		"generated_seed": seed_value,
		"usable_stage": "gene",
	}


func generate_gene_for_rarity(
	definition: GeneDefinition,
	seed_value: int,
	rarity: String
) -> Dictionary:
	var normalized_rarity := rarity.strip_edges().to_lower()

	if not GENE_RARITY_STATS.has(
		normalized_rarity
	):
		return {}

	var item := generate_gene(
		definition,
		seed_value
	)

	if item.is_empty():
		return {}

	var stats: Dictionary = GENE_RARITY_STATS[
		normalized_rarity
	]
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

	item["rarity"] = normalized_rarity
	item["gene_score"] = gene_score
	item["gene_influence"] = gene_score
	item["growth_bonus_percent"] = growth_bonus
	item["gene_expression_tier"] = String(
		GeneExpressionScale.tier_for_score(
			gene_score
		)
	)
	item["influence_tags"] = scaled_tags
	return item


func duplicate_gene_fragment_amount(
	rarity: String
) -> int:
	return maxi(
		1,
		int(
			DUPLICATE_GENE_FRAGMENT_AMOUNT.get(
				rarity.strip_edges().to_lower(),
				1
			)
		)
	)


func generate_gene_fragment(
	gene_item: Dictionary,
	seed_value: int,
	quantity: int = 1
) -> Dictionary:
	var gene_id := String(
		gene_item.get(
			"gene_id",
			gene_item.get(
				"definition_id",
				"unknown"
			)
		)
	)
	var display_name := String(
		gene_item.get(
			"display_name",
			"Gen"
		)
	)

	return {
		"uid": "gene_fragment_%s_%s" % [
			gene_id,
			str(absi(seed_value)),
		],
		"definition_id": "gene_fragment_%s" % gene_id,
		"item_type": String(TYPE_GENE_FRAGMENT),
		"display_name": "Mảnh " + display_name,
		"rarity": String(
			gene_item.get(
				"rarity",
				"common"
			)
		),
		"quality": "normal",
		"target_gene_id": gene_id,
		"fragment_quantity": maxi(
			1,
			quantity
		),
		"main_value_seconds": 0,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "gene_fragment",
		"salvage_value": 0,
		"generated_seed": seed_value,
		"usable_stage": "account_vault",
	}


func generate_mythic_component(
	seed_value: int
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = max(
		1,
		absi(seed_value)
	)
	var definition: Dictionary = MYTHIC_COMPONENT_DEFINITIONS[
		rng.randi_range(
			0,
			MYTHIC_COMPONENT_DEFINITIONS.size() - 1
		)
	]

	return {
		"uid": "mythic_component_%s_%s" % [
			String(
				definition.get(
					"id",
					"mythic"
				)
			),
			str(absi(seed_value)),
		],
		"definition_id": String(
			definition.get(
				"id",
				"mythic"
			)
		),
		"item_type": String(TYPE_MYTHIC_COMPONENT),
		"display_name": String(
			definition.get(
				"display_name",
				"Mảnh Thần Thoại"
			)
		),
		"rarity": "mythic",
		"quality": "normal",
		"mythic_component": true,
		"fragment_quantity": 1,
		"main_value_seconds": 0,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"salvage_type": "mythic_component",
		"salvage_value": 0,
		"generated_seed": seed_value,
		"usable_stage": "account_vault",
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

	match item_type:
		TYPE_FOOD:
			if rng.randf() <= BASIC_INFANT_JUNK_CHANCE:
				return _generate_junk_food(seed_value)
			return _generate_food(rng, "common", "standard", seed_value)
		TYPE_GROWTH:
			if rng.randf() <= BASIC_INFANT_JUNK_CHANCE:
				return _generate_junk_growth(seed_value)
			return _generate_growth(rng, "common", "standard", seed_value)
		_:
			push_error(
				"ItemGenerator: unsupported basic infant type: "
				+ String(item_type)
			)
			return {}

func describe(item: Dictionary) -> String:
	if bool(item.get("is_junk", false)):
		return "Phế phẩm • không có rarity • chỉ nên phân giải"

	var item_type := StringName(item.get("item_type", ""))

	match item_type:
		TYPE_FOOD:
			var food_seconds := int(item.get("main_value_seconds", 0))
			var growth_delta := int(item.get("growth_delta_seconds", 0))
			var text := "Độ no +" + _format_minutes(food_seconds)
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
				text += " • Độ no +" + _format_minutes(food_delta)
			elif food_delta < 0:
				text += " • Mất " + _format_minutes(abs(food_delta)) + " thức ăn"
			return text

		TYPE_GENE:
			var locus := StringName(
				item.get(
					"gene_locus",
					""
				)
			)
			var direction := StringName(
				item.get(
					"gene_direction",
					""
				)
			)
			var gene_text := (
				"Gen "
				+ ViDisplay.locus_label(
					locus
				)
				+ " → "
				+ ViDisplay.trait_value(
					direction
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
				+ " • Trưởng thành +"
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
					+ ViDisplay.element_label(
						StringName(element_lock)
					)
				)
			return gene_text

		TYPE_GENE_FRAGMENT:
			return (
				"Mảnh của %s • số lượng %d"
				% [
					ViDisplay.gene_name(
						String(
							item.get(
								"target_gene_id",
								""
							)
						)
					),
					int(
						item.get(
							"fragment_quantity",
							1
						)
					),
				]
			)

		TYPE_MYTHIC_COMPONENT:
			return "Thành phần thần thoại • dùng làm điều kiện cho công thức tiến hóa hiếm"

		TYPE_FUTURE_FRAGMENT:
			return "Mảnh dành cho giai đoạn sau • chưa thể dùng"

	return "Không rõ hiệu ứng"


func rarity_label(value: String) -> String:
	match value:
		"common":
			return "THƯỜNG"
		"uncommon":
			return "KHÁ HIẾM"
		"rare":
			return "HIẾM"
		"epic":
			return "SỬ THI"
		"legendary":
			return "HUYỀN THOẠI"
		"mythic":
			return "THẦN THOẠI"
		"", "junk":
			return ""
		_:
			return ViDisplay.rarity_label(
				value
			)


func quality_label(value: String) -> String:
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
	_quality: String,
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
	var main_seconds := int(
		stats.get(
			"food_min_seconds",
			20 * 60
		)
	)

	return {
		"uid": _make_uid(seed_value, TYPE_FOOD),
		"definition_id": String(definition.get("id", "food_" + rarity)),
		"item_type": String(TYPE_FOOD),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Khẩu phần dinh dưỡng",
		"base_display_name": "Khẩu phần dinh dưỡng",
		"rarity": rarity,
		"quality": "standard",
		"is_junk": false,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"secondary_effects": [],
		"salvage_type": "food_dust",
		"salvage_value": _fixed_salvage_value(rarity),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}

func _generate_growth(
	rng: RandomNumberGenerator,
	rarity: String,
	_quality: String,
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
	var main_seconds := int(
		stats.get(
			"growth_min_seconds",
			5 * 60
		)
	)

	return {
		"uid": _make_uid(seed_value, TYPE_GROWTH),
		"definition_id": String(definition.get("id", "growth_" + rarity)),
		"item_type": String(TYPE_GROWTH),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Tinh chất tăng trưởng",
		"base_display_name": "Tinh chất tăng trưởng",
		"rarity": rarity,
		"quality": "standard",
		"is_junk": false,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"secondary_effects": [],
		"salvage_type": "growth_dust",
		"salvage_value": _fixed_salvage_value(rarity),
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}

func _generate_junk_food(seed_value: int) -> Dictionary:
	return {
		"uid": _make_uid(seed_value, TYPE_FOOD),
		"definition_id": "food_junk",
		"item_type": String(TYPE_FOOD),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Thức ăn hỏng",
		"base_display_name": "Thức ăn hỏng",
		"rarity": "",
		"quality": "junk",
		"is_junk": true,
		"main_value_seconds": JUNK_FOOD_SECONDS,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"secondary_effects": [],
		"salvage_type": "food_dust",
		"salvage_value": 1,
		"generated_seed": seed_value,
		"usable_stage": "growth",
	}


func _generate_junk_growth(seed_value: int) -> Dictionary:
	return {
		"uid": _make_uid(seed_value, TYPE_GROWTH),
		"definition_id": "growth_junk",
		"item_type": String(TYPE_GROWTH),
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": "Tinh chất lỗi",
		"base_display_name": "Tinh chất lỗi",
		"rarity": "",
		"quality": "junk",
		"is_junk": true,
		"main_value_seconds": JUNK_GROWTH_SECONDS,
		"growth_delta_seconds": 0,
		"food_delta_seconds": 0,
		"properties": [],
		"defects": [],
		"secondary_effects": [],
		"salvage_type": "growth_dust",
		"salvage_value": 1,
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
		"item_schema_version": ITEM_SCHEMA_VERSION,
		"display_name": _future_fragment_name(family),
		"rarity": rarity,
		"quality": "standard",
		"is_junk": false,
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
			count = 1 if rng.randf() <= 0.20 else 0
		"uncommon":
			count = 1 if rng.randf() <= 0.55 else 0
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

	var second_defect_chance := 0.0

	if quality == "broken":
		second_defect_chance = 0.45
	elif quality == "poor":
		second_defect_chance = 0.20

	if (
		second_defect_chance > 0.0
		and rng.randf() <= second_defect_chance
	):
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


static func _fixed_salvage_value(rarity: String) -> int:
	return int({
		"common": 2,
		"uncommon": 4,
		"rare": 8,
		"epic": 16,
		"legendary": 36,
	}.get(rarity.strip_edges().to_lower(), 1))


static func normalize_item(item: Dictionary) -> Dictionary:
	var result := item.duplicate(true)
	if int(result.get("item_schema_version", 0)) >= ITEM_SCHEMA_VERSION:
		return result

	var item_type := StringName(result.get("item_type", ""))
	var rarity := String(result.get("rarity", "common")).strip_edges().to_lower()
	if not RARITY_WEIGHTS.has(rarity):
		rarity = "common"

	match item_type:
		TYPE_FOOD, TYPE_GROWTH:
			var defects_value: Variant = result.get("defects", [])
			var has_legacy_defect := (
				typeof(defects_value) == TYPE_ARRAY
				and not (defects_value as Array).is_empty()
			)
			var junk := (
				bool(result.get("is_junk", false))
				or String(result.get("quality", "normal")) == "broken"
				or has_legacy_defect
			)
			var stage_index := int(result.get("generated_for_stage", 1))
			var multiplier := float(STAGE_VALUE_MULTIPLIERS.get(stage_index, 1.0))
			result["properties"] = []
			result["defects"] = []
			result["secondary_effects"] = []
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
					result["base_display_name"] = "Thức ăn hỏng"
					result["main_value_seconds"] = int(round(JUNK_FOOD_SECONDS * multiplier))
				else:
					result["definition_id"] = "growth_junk"
					result["display_name"] = "Tinh chất lỗi"
					result["base_display_name"] = "Tinh chất lỗi"
					result["main_value_seconds"] = int(round(JUNK_GROWTH_SECONDS * multiplier))
			else:
				result["rarity"] = rarity
				result["quality"] = "standard"
				result["salvage_value"] = _fixed_salvage_value(rarity)
				var stats: Dictionary = RESOURCE_RARITY_STATS.get(rarity, RESOURCE_RARITY_STATS["common"])
				if item_type == TYPE_FOOD:
					result["definition_id"] = "food_" + rarity
					result["display_name"] = "Khẩu phần dinh dưỡng"
					result["base_display_name"] = "Khẩu phần dinh dưỡng"
					result["main_value_seconds"] = int(round(float(stats.get("food_min_seconds", 20 * 60)) * multiplier))
				else:
					result["definition_id"] = "growth_" + rarity
					result["display_name"] = "Tinh chất tăng trưởng"
					result["base_display_name"] = "Tinh chất tăng trưởng"
					result["main_value_seconds"] = int(round(float(stats.get("growth_min_seconds", 5 * 60)) * multiplier))
			result["stage_value_multiplier"] = multiplier

		TYPE_GENE:
			var stats: Dictionary = GENE_RARITY_STATS.get(rarity, GENE_RARITY_STATS["common"])
			var old_score := maxf(1.0, float(result.get("gene_score", result.get("gene_influence", 1.0))))
			var new_score := float(stats.get("score", 25.0))
			var tag_scale := new_score / old_score
			var tags_value: Variant = result.get("influence_tags", {})
			if typeof(tags_value) == TYPE_DICTIONARY:
				var scaled_tags: Dictionary = {}
				for key_value in (tags_value as Dictionary).keys():
					scaled_tags[String(key_value)] = float((tags_value as Dictionary)[key_value]) * tag_scale
				result["influence_tags"] = scaled_tags
			result["rarity"] = rarity
			result["quality"] = "standard"
			result["is_junk"] = false
			result["gene_score"] = new_score
			result["gene_influence"] = new_score
			result["gene_expression_tier"] = String(GeneExpressionScale.tier_for_score(new_score))
			result["growth_bonus_percent"] = float(stats.get("growth", GENE_GROWTH_BONUS_PERCENT))
			result["properties"] = []
			result["defects"] = []

		_:
			result["quality"] = "standard" if String(result.get("quality", "")).is_empty() else result.get("quality")
			result["is_junk"] = false

	result["item_schema_version"] = ITEM_SCHEMA_VERSION
	return result


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
			return "Mảnh gen chưa xác định"
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
