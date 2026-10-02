class_name ViDisplay
extends RefCounted


const LOCUS_LABELS := {
	"body": "Cơ thể",
	"eyes": "Mắt",
	"ears": "Tai",
	"whiskers": "Râu",
	"fur": "Lông",
	"coat": "Vân lông",
	"tail": "Đuôi",
	"paws": "Bàn chân",
	"mane": "Bờm",
	"mark": "Ấn",
	"structure": "Cấu trúc",
	"aura": "Hào quang",
	"horns": "Sừng",
	"wings": "Cánh",
	"hooves": "Móng",
	"antlers": "Gạc",
}


const TRAIT_LABELS := {
	"agile": "Nhanh nhẹn",
	"ancient": "Cổ linh",
	"ascended_dark": "Ám thăng hoa",
	"ascended_spirit": "Linh thể thăng hoa",
	"astral": "Tinh giới",
	"astral_nebula": "Tinh vân tinh giới",
	"celestial": "Thiên giới",
	"compact": "Gọn chắc",
	"cosmic_nebula": "Tinh vân vũ trụ",
	"crescent": "Trăng khuyết",
	"curved": "Cong",
	"dark": "Ám",
	"deep_shadow": "Bóng tối sâu",
	"earth": "Thổ",
	"eclipse": "Nguyệt thực",
	"eclipsed_dark": "Ám nguyệt thực",
	"elegant": "Thanh nhã",
	"elongated": "Kéo dài",
	"ethereal_sleek": "Mượt linh thể",
	"fanned": "Xòe",
	"feral": "Hoang dã",
	"fine": "Mảnh",
	"fire": "Hỏa",
	"fluffy": "Bông xù",
	"full": "Dày",
	"gentle": "Hiền",
	"grand_plume": "Chùm lông lớn",
	"guardian": "Hộ vệ",
	"guardian_ruff": "Bờm cổ hộ vệ",
	"layered": "Phân tầng",
	"light": "Quang",
	"living_shadow": "Bóng sống",
	"long": "Dài",
	"luminous": "Phát sáng",
	"marbled": "Cẩm thạch",
	"metal": "Kim",
	"moon": "Nguyệt",
	"nebula": "Tinh vân",
	"plume": "Chùm lông",
	"plume_tufted": "Tua lông lớn",
	"plush": "Nhung dày",
	"powerful": "Cường tráng",
	"radiant": "Rực sáng",
	"regal": "Oai vệ",
	"regal_long": "Dài oai vệ",
	"ringed": "Viền quang",
	"rounded": "Tròn",
	"runic": "Phù văn",
	"satin": "Mượt bóng",
	"shadow": "Bóng tối",
	"sharp": "Sắc",
	"silken": "Mượt",
	"silky": "Mịn",
	"sleek": "Mượt gọn",
	"slender": "Thon",
	"softfan": "Mềm xòe",
	"spirit": "Linh thể",
	"spirit_tufted": "Tua linh thể",
	"spotted": "Đốm",
	"starlight": "Ánh sao",
	"streamlined": "Thanh gọn",
	"striped": "Sọc",
	"sturdy": "Chắc khỏe",
	"swift": "Nhanh",
	"tipped": "Chóp nổi",
	"transcendent_luminous": "Phát sáng siêu việt",
	"transcendent_spirit": "Linh thể siêu việt",
	"tufted": "Tua lông",
	"water": "Thủy",
	"wood": "Mộc",
}


const RARITY_LABELS := {
	"common": "Thường",
	"uncommon": "Khá hiếm",
	"rare": "Hiếm",
	"epic": "Sử thi",
	"legendary": "Huyền thoại",
	"mythic": "Thần thoại",
}


const SPECIES_LABELS := {
	"cat": "Mèo",
	"dog": "Chó",
	"fox": "Cáo",
	"bear": "Gấu",
	"rabbit": "Thỏ",
	"lizard": "Thằn lằn",
	"bird": "Chim",
	"dragon": "Rồng",
	"phoenix": "Phượng hoàng",
	"horse": "Ngựa",
	"qilin": "Kỳ lân",
	"deer": "Hươu",
}


static func species_label(
	species: StringName
) -> String:
	var key := String(species).strip_edges().to_lower()
	return String(
		SPECIES_LABELS.get(
			key,
			key.capitalize()
		)
	)


static func locus_label(
	locus: StringName
) -> String:
	var key := String(locus).strip_edges().to_lower()
	return String(
		LOCUS_LABELS.get(
			key,
			"Thuộc tính"
		)
	)


static func trait_value(
	trait_id: StringName
) -> String:
	var key := String(
		trait_id
	).strip_edges().to_lower()

	if key.is_empty():
		return "Chưa xác định"

	if key == String(
		PetGenomeSchema.BASE_TRAIT
	):
		return "Cơ bản"

	if TRAIT_LABELS.has(
		key
	):
		return String(
			TRAIT_LABELS[key]
		)

	if key.ends_with(
		"_developed"
	):
		var root := key.trim_suffix(
			"_developed"
		)
		if TRAIT_LABELS.has(root):
			return String(
				TRAIT_LABELS[root]
			) + " phát triển"

	if key.ends_with(
		"_mature"
	):
		var root := key.trim_suffix(
			"_mature"
		)
		if TRAIT_LABELS.has(root):
			return String(
				TRAIT_LABELS[root]
			) + " trưởng thành"

	# Không để ID tiếng Anh nội bộ rò ra UI.
	return "Biến thể khác"


static func rarity_label(
	rarity: String
) -> String:
	var key := rarity.strip_edges().to_lower()
	return String(
		RARITY_LABELS.get(
			key,
			"Không xác định"
		)
	)


static func gene_name(
	gene_id: String
) -> String:
	var normalized := gene_id.strip_edges().to_lower()

	if normalized.is_empty():
		return "Gen chưa xác định"

	var catalog := GeneCatalog.new()
	var definition := catalog.find_by_id(
		catalog.load_default(),
		StringName(normalized)
	)

	if definition != null:
		return item_name(
			definition.display_name()
		)

	return "Gen chưa xác định"


static func item_name(
	raw_name: String
) -> String:
	var value := raw_name.strip_edges()

	if value.is_empty():
		return "Vật phẩm"

	# Tương thích save cũ từng lưu tên hiển thị tiếng Anh.
	value = value.replace(
		"Gene Aura ",
		"Gen Hào Quang "
	)
	value = value.replace(
		"Gene ",
		"Gen "
	)
	value = value.replace(
		"Mảnh Gene ",
		"Mảnh Gen "
	)
	value = value.replace(
		"Mythic",
		"Thần Thoại"
	)
	value = value.replace(
		"Aura ",
		"Hào Quang "
	)

	return value


static func element_label(
	element: StringName
) -> String:
	return PetElementCatalog.display_name(
		element
	)
