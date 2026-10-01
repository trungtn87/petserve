class_name PetSkillCatalog
extends RefCounted


const MAX_SLOTS: int = 4

const SKILLS: Array[Dictionary] = [
	{"id": "hearty_eater", "name": "Ăn Khỏe", "description": "Thức ăn hồi +20% độ no."},
	{"id": "efficient_absorption", "name": "Hấp Thu Tốt", "description": "Growth nhận từ thức ăn +10%."},
	{"id": "slow_digestion", "name": "Tiêu Hóa Chậm", "description": "Độ no giảm chậm 20%."},
	{"id": "fast_metabolism", "name": "Trao Đổi Chất Nhanh", "description": "Độ no giảm nhanh 20%, Growth tự nhiên +15%."},
	{"id": "frugal_life", "name": "Ăn Ít Sống Lâu", "description": "Khi độ no từ 30% trở lên, tiêu hao chậm 25%; Growth từ Food giảm 10%."},
	{"id": "glutton", "name": "Háu Ăn", "description": "Food vẫn giữ Growth/Influence khi phần độ no bị tràn khỏi sức chứa."},
	{"id": "long_childhood", "name": "Tuổi Thơ Dài", "description": "Growth nhận được -20%; Gene/Element/Evolution Influence giữ nguyên."},
	{"id": "fast_grower", "name": "Lớn Nhanh", "description": "Growth tự nhiên +25%; Influence từ item -10%."},
	{"id": "growth_spurt", "name": "Bứt Phá", "description": "Khi Growth đạt 80%, tốc độ Growth +50%."},
	{"id": "strong_start", "name": "Khởi Đầu Mạnh", "description": "Trong 25% Growth đầu, tốc độ trưởng thành +30%."},
	{"id": "late_bloomer", "name": "Trưởng Thành Muộn", "description": "0-70% Growth: -15%; từ 70% trở lên: +35%."},
	{"id": "energy_burner", "name": "Đốt Năng Lượng", "description": "Khi độ no từ 80%, pet tiêu hao nhanh hơn để đổi lấy Growth cao hơn."},
	{"id": "energy_storage", "name": "Tích Trữ Năng Lượng", "description": "20% phần độ no tràn không chứa được được đổi thành Growth."},
	{"id": "full_belly_growth", "name": "Sinh Trưởng Khi No", "description": "No >=80%: Growth x1.2; dưới 40%: Growth x0.6."},
	{"id": "hungry_growth", "name": "Càng Đói Càng Lớn", "description": "Khi 0% < độ no <30%, Growth +25%; 0% vẫn ngủ đông."},
	{"id": "perfect_conversion", "name": "Chuyển Hóa Hoàn Hảo", "description": "10% khi dùng Food không tiêu hao item nhưng vẫn nhận hiệu ứng."},
	{"id": "night_eater", "name": "Ăn Đêm", "description": "Mỗi pet có một khung 6 giờ riêng; Food và Growth tự nhiên trong khung này +15%."},
	{"id": "hibernation", "name": "Ngủ Đông", "description": "Khi độ no <=15%, tiêu hao còn 15% và Growth còn 10% bình thường."},
	{"id": "omnivore", "name": "Phàm Ăn", "description": "Không chịu phạt hiệu quả từ loại Food không ưa; vẫn nhận bonus món ưa."},
	{"id": "picky_eater", "name": "Kén Ăn", "description": "Random một nhóm Food ưa thích: +30%; nhóm khác -30% nếu không có Phàm Ăn."},
	{"id": "first_meal_genius", "name": "Một Bữa Thành Tài", "description": "Bữa Food đầu tiên mỗi ngày nhận x2 Growth từ Food."},
	{"id": "bottomless_stomach", "name": "Dạ Dày Không Đáy", "description": "Phần độ no tràn được giữ trong buffer tối đa 50% sức chứa gốc."},
	{"id": "rumination", "name": "Phản Sô", "description": "20% khi ăn tạo một lần hồi 25% lượng No sau 2 giờ."},
	{"id": "survival_instinct", "name": "Bản Năng Sinh Tồn", "description": "Mỗi Stage, lần đầu độ no chạm 0 tự hồi 25% sức chứa."},
	{"id": "growth_window", "name": "Kỳ Tăng Trưởng", "description": "Mỗi Stage có một cửa sổ Growth ngẫu nhiên 12% tiến độ, Growth x2."},
	{"id": "mutant_metabolism", "name": "Đột Biến Chuyển Hóa", "description": "12% khi ăn: 6% đổi toàn bộ thành Growth x3, 6% đổi toàn bộ thành No x3."},
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
