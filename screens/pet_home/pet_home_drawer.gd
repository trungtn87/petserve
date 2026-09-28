class_name PetHomeDrawer
extends Control


const PetHomeThemeScript = preload(
	"res://screens/pet_home/pet_home_theme.gd"
)


signal action_requested(action_id: StringName)


const POPUP_WIDTH: float = 174.0
const POPUP_TOP: float = 58.0
const RIGHT_MARGIN: float = 14.0


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

	_layout_popup()

	_scrim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
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
		0.12
	)
	tween.tween_property(
		_panel,
		"modulate:a",
		1.0,
		0.15
	)
	tween.tween_property(
		_panel,
		"scale",
		Vector2.ONE,
		0.18
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
		Vector2(0.97, 0.97),
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
	_scrim.color = Color(0, 0, 0, 0.12)
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
		8
	)
	margin.add_theme_constant_override(
		"margin_top",
		8
	)
	margin.add_theme_constant_override(
		"margin_right",
		8
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		8
	)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override(
		"separation",
		5
	)
	margin.add_child(_content)

	_add_action(
		"ⓘ",
		"Thông tin pet",
		&"pet_info"
	)
	_add_action(
		"▣",
		"Rương đồ",
		&"chest"
	)
	_add_action(
		"▷",
		"Giải trí",
		&"entertainment"
	)
	_add_action(
		"✦",
		"Tiến hóa",
		&"evolution"
	)
	_add_action(
		"⚙",
		"Cài đặt",
		&"settings"
	)

	resized.connect(
		_layout_popup
	)

	_apply_theme()
	call_deferred(
		"_layout_popup"
	)


func _add_action(
	icon_text: String,
	label_text: String,
	action_id: StringName
) -> void:
	var button := Button.new()
	button.text = "%s   %s" % [
		icon_text,
		label_text,
	]
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		38
	)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override(
		"font_size",
		13
	)
	button.pressed.connect(
		_emit_action.bind(
			action_id
		)
	)
	_content.add_child(button)


func _apply_theme() -> void:
	if _theme.is_empty():
		_theme = PetHomeThemeScript.for_element(
			&"dark"
		)

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color.a = 0.94

	var accent: Color = _theme.get(
		"accent",
		Color("#A98AF4")
	)
	var text_color: Color = _theme.get(
		"text",
		Color.WHITE
	)

	_panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			accent,
			14
		)
	)

	for child in _content.get_children():
		if child is not Button:
			continue

		var button := child as Button
		button.add_theme_color_override(
			"font_color",
			text_color
		)
		button.add_theme_color_override(
			"font_hover_color",
			text_color
		)
		button.add_theme_color_override(
			"font_pressed_color",
			text_color
		)

		var normal := panel_color.lightened(
			0.035
		)
		var hover := panel_color.lightened(
			0.09
		)
		var soft_accent := accent
		soft_accent.a = 0.32

		button.add_theme_stylebox_override(
			"normal",
			PetHomeThemeScript.panel_style(
				normal,
				soft_accent,
				10
			)
		)
		button.add_theme_stylebox_override(
			"hover",
			PetHomeThemeScript.panel_style(
				hover,
				accent,
				10
			)
		)
		button.add_theme_stylebox_override(
			"pressed",
			PetHomeThemeScript.panel_style(
				hover,
				accent,
				10
			)
		)


func _layout_popup() -> void:
	if _panel == null:
		return

	var width := minf(
		POPUP_WIDTH,
		size.x - 28.0
	)
	var height := 8.0 + 5.0 * 38.0 + 4.0 * 5.0 + 8.0

	_panel.position = Vector2(
		size.x - width - RIGHT_MARGIN,
		POPUP_TOP
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

	# Chọn mục xong tự đóng.
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
