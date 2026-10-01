class_name PetHomeTheme
extends RefCounted


static func for_element(
	element: StringName
) -> Dictionary:
	match String(element).to_lower():
		"metal":
			return _theme(
				Color("#17232B"),
				Color("#C7E2EC"),
				Color("#F1FAFF"),
				Color("#9FB6C2")
			)
		"wood":
			return _theme(
				Color("#14261B"),
				Color("#8FD38C"),
				Color("#F0FFF1"),
				Color("#A9C8A7")
			)
		"water":
			return _theme(
				Color("#102434"),
				Color("#72D5ED"),
				Color("#EEFCFF"),
				Color("#A7D2DE")
			)
		"fire":
			return _theme(
				Color("#2B1711"),
				Color("#F08A55"),
				Color("#FFF2E9"),
				Color("#D6AE98")
			)
		"earth":
			return _theme(
				Color("#2A2118"),
				Color("#D2AA73"),
				Color("#FFF5E5"),
				Color("#CDBB9D")
			)
		"light":
			return _theme(
				Color("#2B281D"),
				Color("#F2DA83"),
				Color("#FFFBE8"),
				Color("#DDD3A9")
			)
		"dark":
			return _theme(
				Color("#171229"),
				Color("#A98AF4"),
				Color("#F4EEFF"),
				Color("#C3B2E8")
			)
		_:
			return _theme(
				Color("#181820"),
				Color("#AEB3C7"),
				Color("#F5F5FA"),
				Color("#B9BBC6")
			)


static func element_label(
	element: StringName
) -> String:
	return PetElementCatalog.display_name(
		element
	)


static func stage_label(
	stage: int
) -> String:
	match stage:
		1:
			return "Ấu thể"
		2:
			return "Thiếu niên"
		3:
			return "Trưởng thành"
		4:
			return "Giai đoạn 4"
		5:
			return "Hình thái cuối"
		_:
			return "Giai đoạn %d" % stage


static func panel_style(
	background: Color,
	border: Color,
	radius: int = 16
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	return style


static func _theme(
	panel: Color,
	accent: Color,
	text: Color,
	muted: Color
) -> Dictionary:
	return {
		"panel": panel,
		"accent": accent,
		"text": text,
		"muted": muted,
		"scrim": Color(0.02, 0.02, 0.04, 0.55),
	}
