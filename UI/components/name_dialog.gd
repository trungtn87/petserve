class_name PetNameDialog
extends Control


signal submitted(
	raw_name: String
)


var _name_input: LineEdit
var _error_label: Label
var _confirm_button: Button

var _built: bool = false


func _ready() -> void:
	_build_ui()

	close_dialog()


func _build_ui() -> void:
	if _built:
		return

	_built = true


	# =====================================================
	# ROOT OVERLAY
	# =====================================================

	set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	# =====================================================
	# DARK BACKGROUND
	# =====================================================

	var background: ColorRect = ColorRect.new()

	background.color = Color(
		0.03,
		0.02,
		0.015,
		0.48
	)

	background.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	add_child(
		background
	)


	# =====================================================
	# CENTER
	# =====================================================

	var center: CenterContainer = (
		CenterContainer.new()
	)

	center.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)

	center.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	add_child(
		center
	)


	# =====================================================
	# PANEL
	# =====================================================

	var panel: PanelContainer = (
		PanelContainer.new()
	)

	panel.custom_minimum_size = Vector2(
		300.0,
		230.0
	)

	panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)


	var panel_style: StyleBoxFlat = (
		StyleBoxFlat.new()
	)

	panel_style.bg_color = Color(
		0.09,
		0.065,
		0.045,
		0.96
	)

	panel_style.border_color = Color(
		0.72,
		0.52,
		0.22,
		1.0
	)

	panel_style.set_border_width_all(
		2
	)

	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16

	panel_style.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.55
	)

	panel_style.shadow_size = 10


	panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

	center.add_child(
		panel
	)


	# =====================================================
	# MARGIN
	# =====================================================

	var margin: MarginContainer = (
		MarginContainer.new()
	)

	margin.add_theme_constant_override(
		"margin_left",
		22
	)

	margin.add_theme_constant_override(
		"margin_right",
		22
	)

	margin.add_theme_constant_override(
		"margin_top",
		20
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		20
	)

	panel.add_child(
		margin
	)


	# =====================================================
	# CONTENT
	# =====================================================

	var content: VBoxContainer = (
		VBoxContainer.new()
	)

	content.add_theme_constant_override(
		"separation",
		11
	)

	margin.add_child(
		content
	)


	# =====================================================
	# TITLE
	# =====================================================

	var title: Label = Label.new()

	title.text = "✦  TRỨNG SẮP NỞ  ✦"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		22
	)

	title.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.84,
			0.48,
			1.0
		)
	)

	content.add_child(
		title
	)


	# =====================================================
	# DESCRIPTION
	# =====================================================

	var description: Label = Label.new()

	description.text = (
		"Đặt tên cho sinh mệnh mới"
	)

	description.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	description.add_theme_font_size_override(
		"font_size",
		14
	)

	description.add_theme_color_override(
		"font_color",
		Color(
			0.86,
			0.81,
			0.72,
			1.0
		)
	)

	content.add_child(
		description
	)


	# =====================================================
	# INPUT
	# =====================================================

	_name_input = LineEdit.new()

	_name_input.placeholder_text = (
		"Tên của pet..."
	)

	_name_input.max_length = 16

	_name_input.custom_minimum_size = Vector2(
		0.0,
		46.0
	)

	_name_input.alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	_name_input.add_theme_font_size_override(
		"font_size",
		18
	)

	_name_input.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	_name_input.add_theme_color_override(
		"font_placeholder_color",
		Color(
			0.65,
			0.60,
			0.52,
			1.0
		)
	)


	var input_style: StyleBoxFlat = (
		StyleBoxFlat.new()
	)

	input_style.bg_color = Color(
		0.035,
		0.025,
		0.02,
		0.90
	)

	input_style.border_color = Color(
		0.50,
		0.36,
		0.18,
		1.0
	)

	input_style.set_border_width_all(
		1
	)

	input_style.corner_radius_top_left = 9
	input_style.corner_radius_top_right = 9
	input_style.corner_radius_bottom_left = 9
	input_style.corner_radius_bottom_right = 9


	_name_input.add_theme_stylebox_override(
		"normal",
		input_style
	)


	var input_focus_style: StyleBoxFlat = (
		input_style.duplicate()
	)

	input_focus_style.border_color = Color(
		0.95,
		0.70,
		0.28,
		1.0
	)

	input_focus_style.set_border_width_all(
		2
	)

	_name_input.add_theme_stylebox_override(
		"focus",
		input_focus_style
	)

	content.add_child(
		_name_input
	)


	# =====================================================
	# ERROR
	# =====================================================

	_error_label = Label.new()

	_error_label.text = ""

	_error_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	_error_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	_error_label.add_theme_font_size_override(
		"font_size",
		12
	)

	_error_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.42,
			0.38,
			1.0
		)
	)

	content.add_child(
		_error_label
	)


	# =====================================================
	# CONFIRM BUTTON
	# =====================================================

	_confirm_button = Button.new()

	_confirm_button.text = "XÁC NHẬN"

	_confirm_button.custom_minimum_size = Vector2(
		0.0,
		46.0
	)

	_confirm_button.add_theme_font_size_override(
		"font_size",
		17
	)

	_confirm_button.add_theme_color_override(
		"font_color",
		Color(
			0.16,
			0.09,
			0.025,
			1.0
		)
	)


	var button_normal: StyleBoxFlat = (
		StyleBoxFlat.new()
	)

	button_normal.bg_color = Color(
		0.82,
		0.59,
		0.25,
		1.0
	)

	button_normal.border_color = Color(
		1.0,
		0.78,
		0.36,
		1.0
	)

	button_normal.set_border_width_all(
		1
	)

	button_normal.corner_radius_top_left = 10
	button_normal.corner_radius_top_right = 10
	button_normal.corner_radius_bottom_left = 10
	button_normal.corner_radius_bottom_right = 10


	var button_hover: StyleBoxFlat = (
		button_normal.duplicate()
	)

	button_hover.bg_color = Color(
		0.95,
		0.70,
		0.31,
		1.0
	)


	var button_pressed: StyleBoxFlat = (
		button_normal.duplicate()
	)

	button_pressed.bg_color = Color(
		0.68,
		0.46,
		0.18,
		1.0
	)


	_confirm_button.add_theme_stylebox_override(
		"normal",
		button_normal
	)

	_confirm_button.add_theme_stylebox_override(
		"hover",
		button_hover
	)

	_confirm_button.add_theme_stylebox_override(
		"pressed",
		button_pressed
	)

	content.add_child(
		_confirm_button
	)


	# =====================================================
	# SIGNALS
	# =====================================================

	_confirm_button.pressed.connect(
		_on_confirm_pressed
	)

	_name_input.text_submitted.connect(
		_on_text_submitted
	)
func open_dialog() -> void:
	if visible:
		return


	_error_label.text = ""
	_name_input.text = ""

	show()

	_name_input.grab_focus()


func close_dialog() -> void:
	hide()


func show_error(
	message: String
) -> void:
	_error_label.text = message

	_name_input.grab_focus()


func _on_confirm_pressed() -> void:
	_submit()


func _on_text_submitted(
	_value: String
) -> void:
	_submit()


func _submit() -> void:
	submitted.emit(
		_name_input.text
	)
