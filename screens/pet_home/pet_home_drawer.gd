class_name PetHomeDrawer
extends Control


signal action_requested(action_id: StringName)


const DRAWER_WIDTH: float = 236.0


var _theme: Dictionary = {}
var _scrim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _is_open: bool = false
var _animating: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func configure(
	theme: Dictionary
) -> void:
	_theme = theme.duplicate(true)

	if _panel == null:
		return

	_apply_theme()


func open_drawer() -> void:
	if _is_open or _animating:
		return

	_is_open = true
	_animating = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	var width := _drawer_width()
	_layout_panel(size.x)

	_scrim.modulate.a = 0.0
	_panel.position.x = size.x

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_scrim,
		"modulate:a",
		1.0,
		0.18
	)
	tween.tween_property(
		_panel,
		"position:x",
		size.x - width,
		0.22
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
		0.16
	)
	tween.tween_property(
		_panel,
		"position:x",
		size.x,
		0.20
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
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
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.gui_input.connect(
		_on_scrim_input
	)
	add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		18
	)
	margin.add_theme_constant_override(
		"margin_top",
		24
	)
	margin.add_theme_constant_override(
		"margin_right",
		18
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		20
	)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(_content)

	var header := HBoxContainer.new()
	_content.add_child(header)

	var title := Label.new()
	title.text = "PET HOME"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override(
		"font_size",
		18
	)
	title.set_meta(
		"theme_role",
		"title"
	)
	header.add_child(title)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(
		38,
		38
	)
	close.pressed.connect(
		close_drawer
	)
	close.set_meta(
		"theme_role",
		"menu_button"
	)
	header.add_child(close)

	_content.add_child(
		_separator()
	)

	_add_action(
		"Thông tin pet",
		&"pet_info"
	)
	_add_action(
		"Rương đồ",
		&"chest"
	)
	_add_action(
		"Giải trí",
		&"entertainment"
	)
	_add_action(
		"Tiến hóa",
		&"evolution"
	)
	_add_action(
		"Cài đặt",
		&"settings"
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)

	var hint := Label.new()
	hint.text = "Các chức năng được mở theo từng lớp."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override(
		"font_size",
		10
	)
	hint.set_meta(
		"theme_role",
		"muted"
	)
	_content.add_child(hint)

	resized.connect(
		_on_resized
	)

	_apply_theme()
	call_deferred(
		"_on_resized"
	)


func _add_action(
	label: String,
	action_id: StringName
) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		48
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)
	button.set_meta(
		"theme_role",
		"menu_button"
	)
	_content.add_child(button)


func _separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.modulate.a = 0.35

	return separator


func _apply_theme() -> void:
	if _theme.is_empty():
		_theme = PetHomeTheme.for_element(
			&"dark"
		)

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color.a = 0.96

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

	_scrim.color = _theme.get(
		"scrim",
		Color(0.02, 0.02, 0.04, 0.55)
	)

	_panel.add_theme_stylebox_override(
		"panel",
		PetHomeTheme.panel_style(
			panel_color,
			accent,
			0
		)
	)

	for child in _walk(
		_content
	):
		if child is Label:
			var label := child as Label

			if str(
				label.get_meta(
					"theme_role",
					""
				)
			) == "muted":
				label.add_theme_color_override(
					"font_color",
					muted
				)
			else:
				label.add_theme_color_override(
					"font_color",
					text_color
				)

		elif child is Button:
			var button := child as Button
			button.add_theme_color_override(
				"font_color",
				text_color
			)
			button.add_theme_color_override(
				"font_hover_color",
				text_color
			)

			var normal := panel_color.lightened(
				0.04
			)
			var hover := panel_color.lightened(
				0.10
			)

			button.add_theme_stylebox_override(
				"normal",
				PetHomeTheme.panel_style(
					normal,
					Color(accent, 0.35),
					12
				)
			)
			button.add_theme_stylebox_override(
				"hover",
				PetHomeTheme.panel_style(
					hover,
					accent,
					12
				)
			)


func _walk(
	root: Node
) -> Array[Node]:
	var result: Array[Node] = []

	for child in root.get_children():
		result.append(child)
		result.append_array(
			_walk(child)
		)

	return result


func _drawer_width() -> float:
	return minf(
		DRAWER_WIDTH,
		size.x * 0.72
	)


func _layout_panel(
	x_position: float
) -> void:
	var width := _drawer_width()
	_panel.position = Vector2(
		x_position,
		0
	)
	_panel.size = Vector2(
		width,
		size.y
	)


func _on_resized() -> void:
	if _panel == null:
		return

	var target_x := (
		size.x - _drawer_width()
		if _is_open
		else size.x
	)

	_layout_panel(
		target_x
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


func _emit_action(
	action_id: StringName
) -> void:
	action_requested.emit(
		action_id
	)
	close_drawer()


func _on_open_finished() -> void:
	_animating = false


func _on_close_finished() -> void:
	_animating = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
