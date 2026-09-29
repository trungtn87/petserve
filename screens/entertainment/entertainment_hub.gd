class_name EntertainmentHubUI
extends Control


const CaroActivityScript = preload(
	"res://screens/entertainment/caro_activity_ui.gd"
)


signal caro_win_reward_requested
signal match_finished(result: StringName)


var palette: Dictionary = {}

var _is_open: bool = false
var _reward_claimed: int = 0
var _reward_max: int = 4
var _reward_enabled: bool = true

var _hub_screen: Control
var _caro_activity
var _caro_reward_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_hub(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_reward_claimed = reward_claimed
	_reward_max = max(
		0,
		reward_max
	)
	_reward_enabled = reward_enabled
	_sync_reward_state()
	_show_hub_screen()
	visible = true
	_is_open = true


func close_hub() -> void:
	if _caro_activity != null:
		_caro_activity.close_activity()

	visible = false
	_is_open = false


func is_open() -> bool:
	return _is_open


func set_reward_status(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_reward_claimed = reward_claimed
	_reward_max = max(
		0,
		reward_max
	)
	_reward_enabled = reward_enabled
	_sync_reward_state()


func show_reward_message(
	message: String
) -> void:
	if _caro_activity != null:
		_caro_activity.show_reward_message(
			message
		)


func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.015,
		0.01,
		0.03,
		0.94
	)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(
		scrim
	)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.06
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(
				0.07,
				0.045,
				0.13,
				0.99
			),
			Color(
				0.55,
				0.42,
				0.80,
				0.96
			)
		)
	)
	add_child(
		panel
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		16
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	panel.add_child(
		margin
	)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	root.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(
		root
	)

	var header := HBoxContainer.new()
	root.add_child(
		header
	)

	var title := Label.new()
	title.text = "GIẢI TRÍ"
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		19
	)
	header.add_child(
		title
	)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(
		44,
		44
	)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(
		close_hub
	)
	header.add_child(
		close
	)

	var body := Control.new()
	body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	body.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		body
	)

	_build_hub_screen(
		body
	)
	_build_caro_activity(
		body
	)


func _build_hub_screen(
	parent: Control
) -> void:
	_hub_screen = Control.new()
	parent.add_child(
		_hub_screen
	)
	_hub_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var root := VBoxContainer.new()
	_hub_screen.add_child(
		root
	)
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_theme_constant_override(
		"separation",
		10
	)

	var intro := Label.new()
	intro.text = (
		"Chọn một hoạt động để chơi cùng pet."
	)
	intro.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	intro.add_theme_font_size_override(
		"font_size",
		12
	)
	intro.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		intro
	)

	var game_label := Label.new()
	game_label.text = "TRÒ CHƠI"
	game_label.add_theme_font_size_override(
		"font_size",
		11
	)
	game_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		game_label
	)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	grid.add_theme_constant_override(
		"h_separation",
		8
	)
	grid.add_theme_constant_override(
		"v_separation",
		8
	)
	root.add_child(
		grid
	)

	grid.add_child(
		_activity_card(
			"Caro 3×3",
			"Đấu với pet",
			true,
			_open_caro
		)
	)

	grid.add_child(
		_activity_card(
			"Sắp mở",
			"Hoạt động mới",
			false,
			Callable()
		)
	)

	var more_label := Label.new()
	more_label.text = "HOẠT ĐỘNG KHÁC"
	more_label.add_theme_font_size_override(
		"font_size",
		11
	)
	more_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		more_label
	)

	var more_grid := GridContainer.new()
	more_grid.columns = 2
	more_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	more_grid.add_theme_constant_override(
		"h_separation",
		8
	)
	more_grid.add_theme_constant_override(
		"v_separation",
		8
	)
	root.add_child(
		more_grid
	)

	more_grid.add_child(
		_activity_card(
			"Sắp mở",
			"Hoạt động mới",
			false,
			Callable()
		)
	)
	more_grid.add_child(
		_activity_card(
			"Sắp mở",
			"Hoạt động mới",
			false,
			Callable()
		)
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		spacer
	)

	_caro_reward_label = Label.new()
	_caro_reward_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_caro_reward_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_caro_reward_label.add_theme_font_size_override(
		"font_size",
		11
	)
	_caro_reward_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		_caro_reward_label
	)


func _build_caro_activity(
	parent: Control
) -> void:
	_caro_activity = CaroActivityScript.new()
	_caro_activity.palette = palette
	parent.add_child(
		_caro_activity
	)
	_caro_activity.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_caro_activity.visible = false
	_caro_activity.reward_requested.connect(
		_on_caro_reward_requested
	)
	_caro_activity.back_requested.connect(
		_show_hub_screen
	)
	_caro_activity.match_finished.connect(
		_on_caro_match_finished
	)


func _activity_card(
	title_text: String,
	subtitle_text: String,
	enabled: bool,
	callback: Callable
) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(
		0,
		108
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
		if enabled
		else Control.CURSOR_ARROW
	)
	button.add_theme_stylebox_override(
		"normal",
		_style(
			Color(
				0.11,
				0.07,
				0.18,
				0.97
			),
			Color(
				0.55,
				0.42,
				0.80,
				0.82
			)
		)
	)

	if (
		enabled
		and callback.is_valid()
	):
		button.pressed.connect(
			callback
		)

	var content := VBoxContainer.new()
	content.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	content.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	content.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	content.add_theme_constant_override(
		"separation",
		4
	)
	button.add_child(
		content
	)

	var icon := Label.new()
	icon.text = (
		"▦"
		if enabled
		else "＋"
	)
	icon.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	icon.add_theme_font_size_override(
		"font_size",
		24
	)
	icon.add_theme_color_override(
		"font_color",
		palette.get(
			"accent",
			Color.WHITE
		)
	)
	content.add_child(
		icon
	)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		12
	)
	content.add_child(
		title
	)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	subtitle.add_theme_font_size_override(
		"font_size",
		9
	)
	subtitle.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	content.add_child(
		subtitle
	)

	return button


func _open_caro() -> void:
	if _hub_screen != null:
		_hub_screen.visible = false

	if _caro_activity != null:
		_caro_activity.set_reward_status(
			_reward_claimed,
			_reward_max,
			_reward_enabled
		)
		_caro_activity.open_activity()


func _show_hub_screen() -> void:
	if _caro_activity != null:
		_caro_activity.close_activity()

	if _hub_screen != null:
		_hub_screen.visible = true

	_update_hub_reward_label()


func _sync_reward_state() -> void:
	if _caro_activity != null:
		_caro_activity.set_reward_status(
			_reward_claimed,
			_reward_max,
			_reward_enabled
		)

	_update_hub_reward_label()


func _update_hub_reward_label() -> void:
	if _caro_reward_label == null:
		return

	var claimed := clampi(
		_reward_claimed,
		0,
		_reward_max
	)

	if not _reward_enabled:
		_caro_reward_label.text = (
			"Caro vẫn chơi được • "
			+ "thưởng của giai đoạn này đã kết thúc."
		)
		return

	_caro_reward_label.text = (
		"Caro: Rương Ấu thể %d/%d"
		% [
			claimed,
			_reward_max,
		]
	)


func _on_caro_reward_requested() -> void:
	caro_win_reward_requested.emit()


func _on_caro_match_finished(
	result: StringName
) -> void:
	match_finished.emit(
		result
	)


func _style(
	bg: Color,
	border: Color
) -> StyleBoxFlat:
	return PetHomeTheme.panel_style(
		Color(
			palette.get(
				"panel",
				Color("171229")
			),
			bg.a
		),
		palette.get(
			"accent",
			Color("a98af4")
		)
	)
