class_name ArcadeTheme
extends RefCounted

const BG := Color("101923")
const SURFACE := Color("182636")
const RAISED := Color("223548")
const BORDER := Color("3b536b")
const TEXT := Color("edf4fc")
const MUTED := Color("afc1d3")
const ACCENT := Color("79d8cb")

static func palette() -> Dictionary:
	return {"panel": BG, "accent": ACCENT, "text": TEXT, "muted": MUTED, "scrim": Color(0.02, 0.04, 0.06, 0.94)}

static func box(color: Color, border: Color = BORDER, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

static func create() -> Theme:
	var result := Theme.new()
	for type in ["Button", "OptionButton", "CheckButton"]:
		result.set_stylebox("normal", type, box(SURFACE))
		result.set_stylebox("hover", type, box(RAISED, ACCENT.darkened(0.3)))
		result.set_stylebox("pressed", type, box(Color("2c5759"), ACCENT))
		result.set_stylebox("disabled", type, box(BG, SURFACE))
		result.set_stylebox("focus", type, box(Color.TRANSPARENT, ACCENT))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, type, TEXT)
		result.set_color("font_disabled_color", type, Color("73869a"))
		result.set_font_size("font_size", type, 13)
	result.set_color("font_color", "Label", TEXT)
	result.set_stylebox("panel", "PanelContainer", box(SURFACE))
	result.set_stylebox("panel", "PopupMenu", box(SURFACE))
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_color("font_hover_color", "PopupMenu", TEXT)
	result.set_stylebox("hover", "PopupMenu", box(RAISED))
	return result

# Called after construction, preserving the compact mobile layout of each game.
static func polish(root: Control) -> void:
	root.theme = create()
	_polish_children(root)

static func _polish_children(node: Node) -> void:
	if node is Button:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			node.remove_theme_stylebox_override(state)
	elif node is Label:
		node.add_theme_color_override("font_color", TEXT)
		var font_size: int = node.get_theme_font_size("font_size")
		if font_size <= 11:
			node.add_theme_font_size_override("font_size", 11)
			node.add_theme_color_override("font_color", MUTED)
	elif node is PanelContainer:
		var panel := box(SURFACE)
		panel.content_margin_left = 1
		panel.content_margin_right = 1
		panel.content_margin_top = 1
		panel.content_margin_bottom = 1
		node.add_theme_stylebox_override("panel", panel)
	for child in node.get_children():
		_polish_children(child)
