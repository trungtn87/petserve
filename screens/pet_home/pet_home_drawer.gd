class_name PetHomeDrawer
extends Control


const PetHomeArtScript = preload(
	"res://screens/pet_home/pet_home_art.gd"
)


signal action_requested(action_id: StringName)


var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var _is_open := false
var _menu_button: Control


func configure(_palette: Dictionary) -> void:
	pass


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
	scrim.color = Color(0.04, 0.07, 0.08, 0.72)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	panel.offset_left = 18.0
	panel.offset_right = -18.0
	panel.offset_top = 90.0
	panel.offset_bottom = -80.0
	panel.add_theme_stylebox_override(
		"panel",
		paper()
	)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "MenuColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 44
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(header)

	var title := Label.new()
	title.text = "Menu"
	title.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	title.add_theme_font_size_override(
		"font_size",
		24
	)
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close := Button.new()
	close.name = "Close"
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(
		44,
		44
	)
	close.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	close.pressed.connect(close_drawer)
	header.add_child(close)

	var entries := [
		{"id": &"inventory", "label": "Kho đồ", "icon": 0},
		{"id": &"crystallization", "label": "Kết tinh", "icon": 1},
		{"id": &"gene", "label": "Gene", "icon": 2},
		{"id": &"evolution", "label": "Tiến hóa", "icon": 3},
		{"id": &"entertainment", "label": "Mini game", "icon": 4},
		{"id": &"chest", "label": "Tài nguyên", "icon": 5},
		{"id": &"pet_info", "label": "Thông tin pet", "icon": 6},
		{"id": &"settings", "label": "Cài đặt", "icon": 7},
	]

	for entry in entries:
		_add_entry(
			column,
			entry
		)


func _add_entry(
	column: VBoxContainer,
	entry: Dictionary
) -> void:
	var action_id := StringName(
		entry.get(
			"id",
			&""
		)
	)
	var button := Button.new()
	button.name = (
		String(action_id).to_pascal_case()
		+ "Button"
	)
	button.text = String(
		entry.get(
			"label",
			""
		)
	)
	button.icon = PetHomeArtScript.icon(
		int(
			entry.get(
				"icon",
				0
			)
		)
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = false
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		43
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.add_theme_font_size_override(
		"font_size",
		15
	)
	button.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color("49331f")
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color("49331f")
	)
	button.add_theme_constant_override(
		"icon_max_width",
		30
	)
	button.add_theme_stylebox_override(
		"normal",
		menu_row_style(
			Color("fff4dd")
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		menu_row_style(
			Color("ffe3a2")
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		menu_row_style(
			Color("eac78f")
		)
	)
	button.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)
	column.add_child(button)

	var badge := PetHomeArtScript.badge(
		button
	)
	badge.hide()

	_buttons[action_id] = button
	_badges[action_id] = badge


static func paper(
	color: Color = Color("f4e2bf")
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("b99a70")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


static func menu_row_style(
	color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4a47b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
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
	action_requested.emit(
		action_id
	)


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
