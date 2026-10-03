class_name PetHomeArt
extends RefCounted


const ICONS = preload(
	"res://assets/ui/menu_icons.png"
)


static func icon(
	index: int
) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ICONS
	var cell := Vector2(
		ICONS.get_size()
	) / 3.0
	texture.region = Rect2(
		Vector2(
			index % 3,
			index / 3
		) * cell,
		cell
	)
	return texture


static func badge(
	parent: Control
) -> Label:
	var label := Label.new()
	label.text = "!"
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	label.add_theme_font_size_override(
		"font_size",
		16
	)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("f23642")
	bg.border_color = Color("fff5d9")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(12)
	label.add_theme_stylebox_override(
		"normal",
		bg
	)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -24.0
	label.offset_right = -2.0
	label.offset_top = 2.0
	label.offset_bottom = 24.0
	label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	parent.add_child(label)
	return label
