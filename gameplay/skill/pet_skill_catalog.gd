class_name PetSkillCatalog
extends RefCounted


const MAX_SLOTS: int = 4

const SKILLS: Array[Dictionary] = [
	{"id": "hearty_eater", "name": "Ăn Khỏe", "description": "Thức ăn hồi +20% độ no."},
	{"id": "efficient_absorption", "name": "Hấp Thu Tốt", "description": "Trưởng thành nhận từ thức ăn +10%."},
	{"id": "slow_digestion", "name": "Tiêu Hóa Chậm", "description": "Độ no giảm chậm 20%."},
	{"id": "fast_metabolism", "name": "Trao Đổi Chất Nhanh", "description": "Độ no giảm nhanh 20%, trưởng thành tự nhiên +15%."},
	{"id": "frugal_life", "name": "Ăn Ít Sống Lâu", "description": "Khi độ no từ 30% trở lên, tiêu hao chậm 25%; trưởng thành từ thức ăn giảm 10%."},
	{"id": "glutton", "name": "Háu Ăn", "description": "Thức ăn vẫn giữ hiệu quả trưởng thành và ảnh hưởng khi phần độ no bị tràn khỏi sức chứa."},
	{"id": "long_childhood", "name": "Tuổi Thơ Dài", "description": "Trưởng thành nhận được -20%; ảnh hưởng của gen, hệ và tiến hóa giữ nguyên."},
	{"id": "fast_grower", "name": "Lớn Nhanh", "description": "Trưởng thành tự nhiên +25%; ảnh hưởng từ vật phẩm -10%."},
	{"id": "growth_spurt", "name": "Bứt Phá", "description": "Khi trưởng thành đạt 80%, tốc độ trưởng thành +50%."},
	{"id": "strong_start", "name": "Khởi Đầu Mạnh", "description": "Trong 25% trưởng thành đầu, tốc độ trưởng thành +30%."},
	{"id": "late_bloomer", "name": "Trưởng Thành Muộn", "description": "0-70% trưởng thành: -15%; từ 70% trở lên: +35%."},
	{"id": "energy_burner", "name": "Đốt Năng Lượng", "description": "Khi độ no từ 80%, thú cưng tiêu hao nhanh hơn để đổi lấy tốc độ trưởng thành cao hơn."},
	{"id": "energy_storage", "name": "Tích Trữ Năng Lượng", "description": "20% phần độ no tràn không chứa được được đổi thành trưởng thành."},
	{"id": "full_belly_growth", "name": "Sinh Trưởng Khi No", "description": "Độ no từ 80%: trưởng thành x1,2; dưới 40%: trưởng thành x0,6."},
	{"id": "hungry_growth", "name": "Càng Đói Càng Lớn", "description": "Khi độ no trên 0% và dưới 30%, trưởng thành +25%; 0% vẫn ngủ đông."},
	{"id": "perfect_conversion", "name": "Chuyển Hóa Hoàn Hảo", "description": "10% khi dùng thức ăn không tiêu hao vật phẩm nhưng vẫn nhận hiệu ứng."},
	{"id": "night_eater", "name": "Ăn Đêm", "description": "Mỗi thú cưng có một khung 6 giờ riêng; thức ăn và trưởng thành tự nhiên trong khung này +15%."},
	{"id": "hibernation", "name": "Ngủ Đông", "description": "Khi độ no không quá 15%, tiêu hao còn 15% và trưởng thành còn 10% bình thường."},
	{"id": "omnivore", "name": "Phàm Ăn", "description": "Không bị giảm hiệu quả từ loại thức ăn không ưa; vẫn nhận thưởng từ món ưa thích."},
	{"id": "picky_eater", "name": "Kén Ăn", "description": "Ngẫu nhiên một nhóm thức ăn ưa thích: +30%; nhóm khác -30% nếu không có Phàm Ăn."},
	{"id": "first_meal_genius", "name": "Một Bữa Thành Tài", "description": "Bữa thức ăn đầu tiên mỗi ngày nhận x2 trưởng thành từ thức ăn."},
	{"id": "bottomless_stomach", "name": "Dạ Dày Không Đáy", "description": "Phần độ no tràn được giữ trong phần dự trữ tối đa 50% sức chứa gốc."},
	{"id": "rumination", "name": "Phản Sô", "description": "20% khi ăn tạo một lần hồi 25% độ no sau 2 giờ."},
	{"id": "survival_instinct", "name": "Bản Năng Sinh Tồn", "description": "Mỗi giai đoạn, lần đầu độ no chạm 0 tự hồi 25% sức chứa."},
	{"id": "growth_window", "name": "Kỳ Tăng Trưởng", "description": "Mỗi giai đoạn có một khoảng tăng trưởng ngẫu nhiên dài 12% tiến độ, trưởng thành x2."},
	{"id": "mutant_metabolism", "name": "Đột Biến Chuyển Hóa", "description": "12% khi ăn: 6% đổi toàn bộ thành trưởng thành x3, 6% đổi toàn bộ thành độ no x3."},
]


static func all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in SKILLS:
		result.append(definition.duplicate(true))
	return result


static func all_ids() -> Array[String]:
	var result: Array[String] = []
	for definition in SKILLS:
		result.append(String(definition.get("id", "")))
	return result


static func definition(skill_id: StringName) -> Dictionary:
	var expected := String(skill_id)
	for skill in SKILLS:
		if String(skill.get("id", "")) == expected:
			return skill.duplicate(true)
	return {}


static func is_valid(skill_id: StringName) -> bool:
	return not definition(skill_id).is_empty()


static func display_name(skill_id: StringName) -> String:
	return String(definition(skill_id).get("name", String(skill_id)))


static func description(skill_id: StringName) -> String:
	return String(definition(skill_id).get("description", ""))
