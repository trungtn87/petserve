class_name ItemGenerator
extends RefCounted


const TYPE_FOOD: StringName = &"food"
const TYPE_GROWTH: StringName = &"growth"
const TYPE_FUTURE_FRAGMENT: StringName = &"future_fragment"

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


func generate_gene(
	definition: GeneDefinition,
	seed_value: int
) -> Dictionary:
	if (
		definition == null
		or not definition.is_valid()
	):
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = max(
		1,
		abs(
			seed_value
		)
	)

	var quality := "normal"
	var rarity := definition.rarity()

	return {
		"uid": (
			"gene_%s_%s"
			% [
				String(
					definition.id()
				),
				str(
					abs(
						seed_value
					)
				),
			]
		),
		"definition_id": String(
			definition.id()
		),
		"item_type": String(
			TYPE_GENE
		),
		"display_name": (
			definition.display_name()
		),
		"rarity": rarity,
		"quality": quality,
		"gene_id": String(
			definition.id()
		),
		"gene_locus": String(
			definition.locus()
		),
		"gene_direction": String(
			definition.direction()
		),
		"gene_influence": (
			definition.primary_influence()
		),
		"influence_tags": (
			definition.influence_tags()
		),
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
			if food_delta < 0:
				text += " • Mất " + _format_minutes(abs(food_delta)) + " thức ăn"
			return text

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


func _generate_food(
	rng: RandomNumberGenerator,
	rarity: String,
	quality: String,
	seed_value: int
) -> Dictionary:
	var base_seconds := rng.randi_range(20 * 60, 30 * 60)
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

	for property_id in properties:
		match StringName(property_id):
			&"fresh":
				main_seconds = int(round(main_seconds * 1.25))
			&"dense":
				main_seconds += rng.randi_range(15 * 60, 30 * 60)
			&"nutritious":
				growth_delta += rng.randi_range(3 * 60, 8 * 60)
			&"growth_rich":
				main_seconds = int(round(main_seconds * 0.8))
				growth_delta += rng.randi_range(5 * 60, 12 * 60)

	for defect_id in defects:
		match StringName(defect_id):
			&"spoiled":
				main_seconds = int(round(main_seconds * 0.5))
			&"stale":
				main_seconds = int(round(main_seconds * 0.75))
			&"heavy":
				growth_delta -= rng.randi_range(2 * 60, 5 * 60)
			&"rotten":
				main_seconds = int(round(main_seconds * 0.25))
				growth_delta -= rng.randi_range(2 * 60, 6 * 60)

	main_seconds = max(60, main_seconds)

	return {
		"uid": _make_uid(seed_value, TYPE_FOOD),
		"definition_id": "food",
		"item_type": String(TYPE_FOOD),
		"display_name": _food_name(quality, properties, defects),
		"rarity": rarity,
		"quality": quality,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": growth_delta,
		"food_delta_seconds": 0,
		"properties": properties,
		"defects": defects,
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
	var base_seconds := rng.randi_range(6 * 60, 12 * 60)
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

	for property_id in properties:
		match StringName(property_id):
			&"concentrated":
				main_seconds = int(round(main_seconds * 1.55))
			&"rapid":
				main_seconds += rng.randi_range(3 * 60, 8 * 60)
			&"pure":
				main_seconds = int(round(main_seconds * 1.25))
			&"burst":
				if rng.randf() <= 0.25:
					main_seconds *= 2

	for defect_id in defects:
		match StringName(defect_id):
			&"diluted":
				main_seconds = int(round(main_seconds * 0.5))
			&"expired":
				main_seconds = int(round(main_seconds * 0.3))
			&"appetite_drain":
				food_delta -= rng.randi_range(5 * 60, 15 * 60)
			&"backfire":
				if rng.randf() <= 0.5:
					main_seconds = -rng.randi_range(2 * 60, 10 * 60)

	if main_seconds == 0:
		main_seconds = 60

	return {
		"uid": _make_uid(seed_value, TYPE_GROWTH),
		"definition_id": "growth",
		"item_type": String(TYPE_GROWTH),
		"display_name": _growth_name(quality, properties, defects),
		"rarity": rarity,
		"quality": quality,
		"main_value_seconds": main_seconds,
		"growth_delta_seconds": 0,
		"food_delta_seconds": food_delta,
		"properties": properties,
		"defects": defects,
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
	quality: String,
	properties: Array[String],
	defects: Array[String]
) -> String:
	if defects.has("rotten"):
		return "Khẩu phần hỏng nặng"
	if defects.has("spoiled"):
		return "Khẩu phần ôi"

	var base := "Khẩu phần"

	match quality:
		"broken":
			base = "Khẩu phần vụn"
		"poor":
			base = "Khẩu phần kém"
		"good":
			base = "Khẩu phần tươi"
		"perfect":
			base = "Khẩu phần hoàn hảo"

	if properties.has("dense"):
		base += " đậm đặc"
	elif properties.has("nutritious"):
		base += " dinh dưỡng"
	elif properties.has("growth_rich"):
		base += " tăng trưởng"

	return base


func _growth_name(
	quality: String,
	properties: Array[String],
	defects: Array[String]
) -> String:
	if defects.has("backfire"):
		return "Chất xúc tác bất ổn"
	if defects.has("expired"):
		return "Tinh chất hết hạn"

	var base := "Gel tăng trưởng"

	match quality:
		"broken":
			base = "Dung dịch lỗi"
		"poor":
			base = "Gel loãng"
		"good":
			base = "Tinh chất tăng trưởng"
		"perfect":
			base = "Lõi tăng trưởng"

	if properties.has("concentrated"):
		base += " cô đặc"
	elif properties.has("burst"):
		base += " bùng nổ"
	elif properties.has("pure"):
		base += " tinh khiết"

	return base


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
