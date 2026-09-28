class_name SettingsPanel
extends Control

var _title: Label
var _language_label: Label
var _note: Label
var _vi_button: Button
var _en_button: Button
var _close_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_build_ui()
	_refresh_text()

	if not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)


func open_panel() -> void:
	_refresh_text()
	visible = true


func close_panel() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.015, 0.01, 0.03, 0.86)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 300)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.07, 0.045, 0.13, 0.99),
			Color(0.55, 0.42, 0.80, 0.96)
		)
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color(0.93, 0.88, 1.0))
	header.add_child(_title)

	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(44, 44)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.text = "×"
	_close_button.pressed.connect(close_panel)
	header.add_child(_close_button)

	var rule := HSeparator.new()
	root.add_child(rule)

	_language_label = Label.new()
	_language_label.add_theme_font_size_override("font_size", 14)
	_language_label.add_theme_color_override("font_color", Color(0.76, 0.69, 0.88))
	root.add_child(_language_label)

	_vi_button = _language_button()
	_vi_button.pressed.connect(_select_language.bind("vi"))
	root.add_child(_vi_button)

	_en_button = _language_button()
	_en_button.pressed.connect(_select_language.bind("en"))
	root.add_child(_en_button)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 11)
	_note.add_theme_color_override("font_color", Color(0.60, 0.54, 0.70))
	root.add_child(_note)


func _language_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override(
		"normal",
		_panel_style(
			Color(0.15, 0.10, 0.24, 0.98),
			Color(0.40, 0.30, 0.60, 0.88)
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_panel_style(
			Color(0.23, 0.16, 0.36, 1.0),
			Color(0.67, 0.53, 0.92, 0.96)
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_panel_style(
			Color(0.27, 0.19, 0.42, 1.0),
			Color(0.72, 0.58, 0.96, 1.0)
		)
	)
	return button


func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	return style


func _select_language(language: String) -> void:
	LocalizationManager.set_language(language)
	_refresh_text()


func _refresh_text() -> void:
	if _title == null:
		return

	_title.text = LocalizationManager.text("SETTINGS_TITLE", "Settings")
	_language_label.text = LocalizationManager.text("SETTINGS_LANGUAGE", "Language")
	_note.text = LocalizationManager.text(
		"SETTINGS_LANGUAGE_NOTE",
		"Changes apply immediately and are saved on this device."
	)

	var current := LocalizationManager.get_language()
	var vi_prefix := "✓  " if current == "vi" else "   "
	var en_prefix := "✓  " if current == "en" else "   "

	_vi_button.text = vi_prefix + LocalizationManager.text("LANG_VIETNAMESE", "Tiếng Việt")
	_en_button.text = en_prefix + LocalizationManager.text("LANG_ENGLISH", "English")


func _on_language_changed(_language: String) -> void:
	_refresh_text()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			close_panel()
			accept_event()

	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch

		if touch_event.pressed:
			close_panel()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
