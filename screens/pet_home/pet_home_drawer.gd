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


const PANEL_WIDTH: float = 232.0
const PANEL_TOP: float = 18.0
const PANEL_BOTTOM: float = 18.0
const RIGHT_MARGIN: float = 10.0


var _theme: Dictionary = {}
var _scrim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _is_open: bool = false
var _animating: bool = false


func _ready() -> void:
	set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_build()


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
	_panel.position.x += 20.0

	var target_x := (
		size.x
		- _panel.size.x
		- RIGHT_MARGIN
	)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		_scrim,
		"modulate:a",
		1.0,
		0.16
	)
	tween.tween_property(
		_panel,
		"modulate:a",
		1.0,
		0.18
	)
	tween.tween_property(
		_panel,
		"position:x",
		target_x,
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
		0.12
	)
	tween.tween_property(
		_panel,
		"modulate:a",
		0.0,
		0.14
	)
	tween.tween_property(
		_panel,
		"position:x",
		size.x + 8.0,
		0.18
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
	_scrim.color = Color(0.01, 0.01, 0.03, 0.48)
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
	_content.add_theme_constant_override(
		"separation",
		8
	)
	margin.add_child(_content)

	var decor = PetHomeMenuDecorScript.new()
	decor.name = "Decor"
	decor.custom_minimum_size = Vector2(
		0,
		72
	)
	_content.add_child(decor)

	_add_action(
		&"pet_info",
		"Thông tin pet"
	)
	_add_action(
		&"chest",
		"Rương đồ"
	)
	_add_action(
		&"entertainment",
		"Giải trí"
	)
	_add_action(
		&"evolution",
		"Tiến hóa"
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
		9
	)
	footer.modulate.a = 0.42
	_content.add_child(footer)

	resized.connect(
		_layout_panel
	)

	_apply_theme()
	call_deferred(
		"_layout_panel"
	)


func _add_action(
	action_id: StringName,
	label_text: String
) -> void:
	var button := Button.new()
	button.name = String(action_id).to_pascal_case()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		58
	)
	button.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)
	_content.add_child(button)

	var row := HBoxContainer.new()
	row.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	row.offset_left = 10.0
	row.offset_top = 7.0
	row.offset_right = -10.0
	row.offset_bottom = -7.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(
		"separation",
		10
	)
	button.add_child(row)

	var icon = PetHomeMenuIconScript.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(
		42,
		42
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
		14
	)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var chevron := Label.new()
	chevron.name = "Chevron"
	chevron.text = "›"
	chevron.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	chevron.add_theme_font_size_override(
		"font_size",
		23
	)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)

	button.set_meta(
		"action_id",
		action_id
	)


func _apply_theme() -> void:
	if _theme.is_empty():
		_theme = PetHomeThemeScript.for_element(
			&"dark"
		)

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color = panel_color.lightened(0.035)
	panel_color.a = 0.965

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

	_panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			Color(
				accent.r,
				accent.g,
				accent.b,
				0.68
			),
			24
		)
	)

	for child in _content.get_children():
		if child is PetHomeMenuDecor:
			child.configure(
				accent,
				secondary
			)
			continue

		if child is Label:
			var footer := child as Label
			footer.add_theme_color_override(
				"font_color",
				muted
			)
			continue

		if child is not Button:
			continue

		var button := child as Button
		var normal := panel_color.lightened(
			0.055
		)
		var hover := panel_color.lightened(
			0.105
		)
		var border := accent
		border.a = 0.42

		button.add_theme_stylebox_override(
			"normal",
			PetHomeThemeScript.panel_style(
				normal,
				border,
				18
			)
		)
		button.add_theme_stylebox_override(
			"hover",
			PetHomeThemeScript.panel_style(
				hover,
				accent,
				18
			)
		)
		button.add_theme_stylebox_override(
			"pressed",
			PetHomeThemeScript.panel_style(
				hover,
				accent,
				18
			)
		)

		var action_id := StringName(
			str(
				button.get_meta(
					"action_id",
					""
				)
			)
		)

		var row := button.get_child(
			0
		) as HBoxContainer

		if row == null:
			continue

		var icon := row.get_node_or_null(
			"Icon"
		)

		if icon != null:
			icon.configure(
				action_id,
				accent,
				secondary
			)

		var label := row.get_node_or_null(
			"Label"
		) as Label

		if label != null:
			label.add_theme_color_override(
				"font_color",
				text_color
			)

		var chevron := row.get_node_or_null(
			"Chevron"
		) as Label

		if chevron != null:
			chevron.add_theme_color_override(
				"font_color",
				muted
			)


func _layout_panel() -> void:
	if _panel == null:
		return

	var width := minf(
		PANEL_WIDTH,
		size.x * 0.68
	)
	var height := maxf(
		320.0,
		size.y - PANEL_TOP - PANEL_BOTTOM
	)

	_panel.position = Vector2(
		size.x - width - RIGHT_MARGIN,
		PANEL_TOP
	)
	_panel.size = Vector2(
		width,
		height
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
