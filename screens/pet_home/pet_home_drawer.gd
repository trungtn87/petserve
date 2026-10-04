class_name PetHomeDrawer
extends Control


const PetHomeMenuIconScript = preload(
	"res://screens/pet_home/pet_home_menu_icon.gd"
)


signal action_requested(action_id: StringName)


var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var _is_open := false
var _menu_button: Control
var _palette: Dictionary = {}


func configure(palette: Dictionary) -> void:
	_palette = palette.duplicate(true)


func set_menu_button(button: Control) -> void:
	_menu_button = button


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(0.03, 0.04, 0.05, 0.48)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.anchor_left = 0.62
	panel.anchor_top = 0.105
	panel.anchor_right = 0.985
	panel.anchor_bottom = 0.855
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.add_theme_stylebox_override(
		"panel",
		_drawer_style()
	)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		4
	)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 36
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 3)
	column.add_child(header)

	var title := Label.new()
	title.text = "Menu"
	title.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	title.add_theme_font_size_override(
		"font_size",
		18
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(32, 32)
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override(
		"font_color",
		Color("f7d879")
	)
	close.add_theme_color_override(
		"font_hover_color",
		Color("fff2bd")
	)
	close.add_theme_stylebox_override(
		"normal",
		_close_style(Color("2e291f"))
	)
	close.add_theme_stylebox_override(
		"hover",
		_close_style(Color("403827"))
	)
	close.add_theme_stylebox_override(
		"pressed",
		_close_style(Color("1f1c17"))
	)
	close.pressed.connect(close_drawer)
	header.add_child(close)

	var entries := [
		{"id": &"pet_info", "label": "Thông tin pet"},
		{"id": &"inventory", "label": "Kho đồ"},
		{"id": &"chest", "label": "Rương"},
		{"id": &"crystallization", "label": "Kết tinh"},
		{"id": &"gene", "label": "Gene"},
		{"id": &"evolution", "label": "Tiến hóa"},
		{"id": &"entertainment", "label": "Mini game"},
		{"id": &"settings", "label": "Cài đặt"},
	]

	for entry in entries:
		_add_entry(column, entry)


func _add_entry(
	column: VBoxContainer,
	entry: Dictionary
) -> void:
	var action_id := StringName(
		entry.get("id", &"")
	)

	var button := Button.new()
	button.name = (
		String(action_id).to_pascal_case()
		+ "Button"
	)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override(
		"normal",
		_menu_row_style(Color("fff6df"))
	)
	button.add_theme_stylebox_override(
		"hover",
		_menu_row_style(Color("ffe7b5"))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_menu_row_style(Color("e9c98d"))
	)
	button.pressed.connect(
		_emit_action.bind(action_id)
	)
	column.add_child(button)

	var icon_holder := PanelContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.anchor_left = 0.0
	icon_holder.anchor_top = 0.0
	icon_holder.anchor_right = 0.0
	icon_holder.anchor_bottom = 1.0
	icon_holder.offset_left = 4.0
	icon_holder.offset_top = 4.0
	icon_holder.offset_right = 38.0
	icon_holder.offset_bottom = -4.0
	icon_holder.add_theme_stylebox_override(
		"panel",
		_icon_style()
	)
	button.add_child(icon_holder)

	var icon := PetHomeMenuIconScript.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	icon.configure(
		action_id,
		Color("f7d879"),
		Color("c69745")
	)
	icon_holder.add_child(icon)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = String(entry.get("label", ""))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.0
	caption.anchor_top = 0.0
	caption.anchor_right = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = 43.0
	caption.offset_right = -16.0
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	button.add_child(caption)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.anchor_left = 1.0
	chevron.anchor_top = 0.0
	chevron.anchor_right = 1.0
	chevron.anchor_bottom = 1.0
	chevron.offset_left = -15.0
	chevron.offset_right = -3.0
	chevron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 20)
	chevron.add_theme_color_override(
		"font_color",
		Color("9b6f3f")
	)
	button.add_child(chevron)

	var badge := _make_badge(button)
	badge.hide()

	_buttons[action_id] = button
	_badges[action_id] = badge


func _make_badge(parent: Control) -> Label:
	var label := Label.new()
	label.text = "!"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -28.0
	label.offset_right = -14.0
	label.offset_top = 3.0
	label.offset_bottom = 17.0
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color.WHITE)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("ef3f45")
	bg.border_color = Color("fff0c7")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(8)
	label.add_theme_stylebox_override("normal", bg)

	parent.add_child(label)
	return label


static func _drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f7e5bd")
	style.border_color = Color("b78f58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 7
	style.shadow_offset = Vector2(-3, 3)
	return style


static func _menu_row_style(
	color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d7b77b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


static func _icon_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("312b21")
	style.border_color = Color("d8b761")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


static func _close_style(
	color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("d8b761")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func set_notifications(
	crystallization_count: int,
	evolution_ready: bool
) -> void:
	if _badges.has(&"crystallization"):
		_badges[&"crystallization"].visible = (
			crystallization_count > 0
		)
	if _badges.has(&"evolution"):
		_badges[&"evolution"].visible = (
			evolution_ready
		)


func open_drawer() -> void:
	_is_open = true
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()


func close_drawer() -> void:
	_is_open = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return _is_open and visible


func _emit_action(
	action_id: StringName
) -> void:
	action_requested.emit(action_id)


func _on_scrim_input(
	event: InputEvent
) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
	):
		close_drawer()
	elif (
		event is InputEventScreenTouch
		and event.pressed
	):
		close_drawer()
