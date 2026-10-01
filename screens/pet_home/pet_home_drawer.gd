class_name PetHomeDrawer
extends Control


const PetHomeThemeScript = preload(
	"res://screens/pet_home/pet_home_theme.gd"
)
const PetHomeMenuIconScript = preload(
	"res://screens/pet_home/pet_home_menu_icon.gd"
)
const PetHomeMenuDecorScript = preload(
	"res://screens/pet_home/pet_home_menu_decor.gd"
)


signal action_requested(action_id: StringName)


const PANEL_WIDTH: float = 164.0
const PANEL_HEIGHT: float = 444.0
const PANEL_TOP: float = 14.0
const PANEL_RIGHT: float = 8.0


var _theme: Dictionary = {}
var _scrim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _cards: Array[Dictionary] = []
var _is_open: bool = false
var _animating: bool = false


func _ready() -> void:
	set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()

	if not resized.is_connected(
		_layout_panel
	):
		resized.connect(
			_layout_panel
		)

	call_deferred(
		"_layout_panel"
	)


func configure(
	theme: Dictionary
) -> void:
	_theme = theme.duplicate(true)

	if _panel != null:
		_apply_theme()


func open_drawer() -> void:
	if _is_open or _animating:
		return

	_is_open = true
	_animating = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_layout_panel()

	_scrim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(
		0.97,
		0.97
	)
	_panel.pivot_offset = Vector2(
		_panel.size.x,
		0
	)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_scrim,
		"modulate:a",
		1.0,
		0.14
	)
	tween.tween_property(
		_panel,
		"modulate:a",
		1.0,
		0.18
	)
	tween.tween_property(
		_panel,
		"scale",
		Vector2.ONE,
		0.20
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
	tween.finished.connect(
		_on_open_finished,
		CONNECT_ONE_SHOT
	)


func close_drawer() -> void:
	if not _is_open or _animating:
		return

	_is_open = false
	_animating = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_scrim,
		"modulate:a",
		0.0,
		0.10
	)
	tween.tween_property(
		_panel,
		"modulate:a",
		0.0,
		0.12
	)
	tween.tween_property(
		_panel,
		"scale",
		Vector2(
			0.98,
			0.98
		),
		0.12
	)
	tween.finished.connect(
		_on_close_finished,
		CONNECT_ONE_SHOT
	)


func is_open() -> bool:
	return _is_open


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	_scrim.color = Color(
		0.01,
		0.01,
		0.03,
		0.52
	)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(
		_on_scrim_input
	)
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		12
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_content.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	_content.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(_content)

	var decor = PetHomeMenuDecorScript.new()
	decor.name = "Decor"
	decor.custom_minimum_size = Vector2(
		0,
		42
	)
	_content.add_child(decor)

	_add_action(
		&"pet_info",
		"Thông tin thú cưng"
	)
	_add_action(
		&"chest",
		"Kho tài nguyên"
	)
	_add_action(
		&"entertainment",
		"Giải trí"
	)
	_add_action(
		&"achievement",
		"Thành tích"
	)
	_add_action(
		&"settings",
		"Cài đặt"
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	_content.add_child(spacer)

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "PETVERSE"
	footer.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	footer.add_theme_font_size_override(
		"font_size",
		8
	)
	footer.modulate.a = 0.40
	_content.add_child(footer)

	_apply_theme()


func _add_action(
	action_id: StringName,
	label_text: String
) -> void:
	var card := PanelContainer.new()
	card.name = (
		String(action_id).to_pascal_case()
		+ "Card"
	)
	card.custom_minimum_size = Vector2(
		0,
		46
	)
	card.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_content.add_child(card)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override(
		"margin_left",
		8
	)
	padding.add_theme_constant_override(
		"margin_top",
		5
	)
	padding.add_theme_constant_override(
		"margin_right",
		8
	)
	padding.add_theme_constant_override(
		"margin_bottom",
		5
	)
	card.add_child(padding)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_theme_constant_override(
		"separation",
		7
	)
	padding.add_child(row)

	var icon = PetHomeMenuIconScript.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(
		28,
		28
	)
	row.add_child(icon)

	var label := Label.new()
	label.name = "Label"
	label.text = label_text
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	label.add_theme_font_size_override(
		"font_size",
		11
	)
	row.add_child(label)

	var chevron := Label.new()
	chevron.name = "Chevron"
	chevron.text = "›"
	chevron.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	chevron.add_theme_font_size_override(
		"font_size",
		15
	)
	row.add_child(chevron)

	var hitbox := Button.new()
	hitbox.name = "Hitbox"
	hitbox.text = ""
	hitbox.flat = true
	hitbox.focus_mode = Control.FOCUS_NONE
	hitbox.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	hitbox.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	hitbox.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)
	card.add_child(hitbox)

	_cards.append({
		"action_id": action_id,
		"card": card,
		"icon": icon,
		"label": label,
		"chevron": chevron,
		"hitbox": hitbox,
	})


func _apply_theme() -> void:
	if _theme.is_empty():
		_theme = PetHomeThemeScript.for_element(
			&"dark"
		)

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color = panel_color.lightened(
		0.035
	)
	panel_color.a = 0.97

	var accent: Color = _theme.get(
		"accent",
		Color("#A98AF4")
	)
	var text_color: Color = _theme.get(
		"text",
		Color.WHITE
	)
	var muted: Color = _theme.get(
		"muted",
		Color("#C3B2E8")
	)
	var secondary := accent.lightened(
		0.22
	)

	var panel_border := accent
	panel_border.a = 0.62

	_panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			panel_border,
			24
		)
	)

	var decor := _content.get_node_or_null(
		"Decor"
	)

	if (
		decor != null
		and decor.has_method(
			"configure"
		)
	):
		decor.configure(
			accent,
			secondary
		)

	var footer := _content.get_node_or_null(
		"Footer"
	) as Label

	if footer != null:
		footer.add_theme_color_override(
			"font_color",
			muted
		)

	for item in _cards:
		var card = item.get(
			"card"
		)
		var icon = item.get(
			"icon"
		)
		var label = item.get(
			"label"
		)
		var chevron = item.get(
			"chevron"
		)
		var action_id := StringName(
			item.get(
				"action_id",
				&""
			)
		)

		if card != null:
			var card_bg := panel_color.lightened(
				0.055
			)
			card_bg.a = 0.94
			var border := accent
			border.a = 0.38

			card.add_theme_stylebox_override(
				"panel",
				PetHomeThemeScript.panel_style(
					card_bg,
					border,
					18
				)
			)

		if (
			icon != null
			and icon.has_method(
				"configure"
			)
		):
			icon.configure(
				action_id,
				accent,
				secondary
			)

		if label is Label:
			label.add_theme_color_override(
				"font_color",
				text_color
			)

		if chevron is Label:
			chevron.add_theme_color_override(
				"font_color",
				muted
			)


func _layout_panel() -> void:
	if _panel == null:
		return

	var viewport_width := maxf(
		size.x,
		1.0
	)
	var viewport_height := maxf(
		size.y,
		1.0
	)

	var panel_width := minf(
		PANEL_WIDTH,
		viewport_width - 16.0
	)
	var panel_height := minf(
		PANEL_HEIGHT,
		viewport_height - PANEL_TOP - 12.0
	)

	_panel.position = Vector2(
		viewport_width
		- panel_width
		- PANEL_RIGHT,
		PANEL_TOP
	)
	_panel.size = Vector2(
		panel_width,
		panel_height
	)


func _input(
	event: InputEvent
) -> void:
	if (
		not _is_open
		or not visible
		or _panel == null
	):
		return

	var pressed := false
	var pointer_position := Vector2.ZERO

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		pressed = mouse_event.pressed
		pointer_position = mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		pressed = touch_event.pressed
		pointer_position = touch_event.position
	else:
		return

	if not pressed:
		return

	if _panel.get_global_rect().has_point(
		pointer_position
	):
		return

	close_drawer()
	get_viewport().set_input_as_handled()


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


func _emit_action(
	action_id: StringName
) -> void:
	action_requested.emit(
		action_id
	)

	_is_open = false
	_animating = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_open_finished() -> void:
	_animating = false


func _on_close_finished() -> void:
	_animating = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
