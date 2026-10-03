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
	# Giữ API cũ để PetHome hiện tại không phụ thuộc vị trí panel.
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

	var column := VBoxContainer.new()
	column.add_theme_constant_override(
		"separation",
		14
	)
	panel.add_child(column)

	var header := HBoxContainer.new()
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

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	column.add_child(scroll)

	var grid := GridContainer.new()
	grid.name = "MenuGrid"
	grid.columns = 3
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		7
	)
	grid.add_theme_constant_override(
		"v_separation",
		10
	)
	scroll.add_child(grid)

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
			grid,
			entry
		)


func _add_entry(
	grid: GridContainer,
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
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		94
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.add_theme_stylebox_override(
		"normal",
		paper(
			Color("fff4dd")
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		paper(
			Color("ffe3a2")
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		paper(
			Color("eac78f")
		)
	)
	button.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = PetHomeArtScript.icon(
		int(
			entry.get(
				"icon",
				0
			)
		)
	)
	icon.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	icon.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	icon.anchor_left = 0.5
	icon.anchor_right = 0.5
	icon.offset_left = -28.0
	icon.offset_right = 28.0
	icon.offset_top = 4.0
	icon.offset_bottom = 60.0
	button.add_child(icon)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = String(
		entry.get(
			"label",
			""
		)
	)
	caption.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	caption.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	caption.add_theme_font_size_override(
		"font_size",
		12
	)
	caption.add_theme_color_override(
		"font_color",
		Color("49331f")
	)
	caption.anchor_right = 1.0
	caption.offset_top = 64.0
	caption.offset_bottom = 86.0
	caption.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	button.add_child(caption)

	var badge := PetHomeArtScript.badge(
		button
	)
	badge.hide()

	grid.add_child(button)
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
