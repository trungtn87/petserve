class_name PetHomeGameplayTheme
extends RefCounted

const INK := Color("111323")
const GOLD := Color("d9c094")
const TEXT := Color("f5efdf")

static func panel(alpha: float = 0.94) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(INK, alpha)
	box.border_color = Color(GOLD, 0.65)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func build(palette: Dictionary = {}) -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", palette.get("text", TEXT))
	result.set_color("font_color", "Button", palette.get("text", TEXT))
	result.set_color("font_disabled_color", "Button", Color("85858e"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := panel()
		box.bg_color = palette.get("panel", INK)
		box.border_color = palette.get("accent", GOLD)
		if state == "pressed":
			box.bg_color = Color("35304a")
		result.set_stylebox(state, "Button", box)
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("background", "ProgressBar", panel())
	var fill := panel()
	fill.bg_color = GOLD
	result.set_stylebox("fill", "ProgressBar", fill)
	return result
