class_name PetHomeGameplayUI
extends Control


const PetHomeItemIconScript = preload(
	"res://screens/pet_home/pet_home_item_icon.gd"
)


var palette: Dictionary = {}
var dialogs_only: bool = false

signal chest_open_requested
signal overlay_closed
signal item_use_requested(uid: String)
signal item_salvage_requested(uid: String)
signal entertainment_requested
signal evolution_requested

var _facade: InfantGameFacade
var _pet_name_label: Label
var _growth_bar: ProgressBar
var _fullness_bar: ProgressBar
var _growth_label: Label
var _food_label: Label
var _state_label: Label
var _chest_button: Button
var _inventory_button: Button
var _entertainment_button: Button
var _overlay: Control
var _overlay_panel: PanelContainer
var _title: Label
var _list: GridContainer
var _filters: HBoxContainer
var _toast: Label
var _notice_bar: PanelContainer
var _notice_label: Label
var _detail_overlay: Control
var _detail_panel: PanelContainer
var _detail_icon_host: CenterContainer
var _detail_title: Label
var _detail_meta: Label
var _detail_effect: Label
var _detail_mods: Label
var _detail_use_button: Button
var _detail_salvage_button: Button
var _detail_item: Dictionary = {}
var _detail_allow_use: bool = false
var _evolve_button: Button
var _stage_label: Label
var _stage_index: int = 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_build_hud()
	if dialogs_only:
		for child in get_children():
			child.hide()

		# PetHome dùng HUD chính riêng nhưng vẫn cần thanh cảnh báo
		# trạng thái gameplay ở đáy màn hình.
		if _notice_bar != null:
			_notice_bar.show()

	_build_overlay()
	_build_toast()

	if not resized.is_connected(
		_layout_overlay
	):
		resized.connect(
			_layout_overlay
		)

	call_deferred(
		"_layout_overlay"
	)

func bind(facade: InfantGameFacade) -> void:
	_facade = facade
	refresh_status(_facade.snapshot())


func set_pet_identity(display_name: String) -> void:
	if _pet_name_label != null:
		_pet_name_label.text = display_name

func refresh_status(s: Dictionary) -> void:
	_stage_index = int(
		s.get(
			"stage_index",
			1
		)
	)
	_stage_label.text = (
		PetHomeTheme.stage_label(
			_stage_index
		).to_upper()
	)

	var ready := bool(
		s.get(
			"ready_to_evolve",
			false
		)
	)
	var can_evolve := bool(
		s.get(
			"can_evolve",
			ready
		)
	)
	var final_form := bool(
		s.get(
			"final_form",
			false
		)
	)
	_evolve_button.visible = (
		not dialogs_only
		and can_evolve
		and not final_form
	)

	var percent := int(
		s.get(
			"growth_percent",
			0
		)
	)
	_growth_bar.value = percent
	var food_percent := int(
		s.get(
			"food_percent",
			0
		)
	)
	_fullness_bar.value = food_percent
	var growth_speed_percent := int(
		s.get(
			"growth_speed_percent",
			0
		)
	)
	var hibernating := bool(
		s.get(
			"hibernating",
			false
		)
	)
	_food_label.text = (
		"Độ no %d%% • %s"
		% [
			food_percent,
			_duration(
				int(
					s.get(
						"food_seconds",
						0
					)
				)
			),
		]
	)

	if final_form:
		_growth_label.text = "Hình thái cuối"
		_state_label.text = ""
	else:
		_growth_label.text = (
			"Trưởng thành  %d%%"
			% percent
		)
		_state_label.text = (
			"Ngủ đông • cần cho ăn"
			if hibernating
			else (
				"Sẵn sàng tiến hóa"
				if ready
				else (
					"Có thể tiến hóa ngay [THỬ NGHIỆM]"
					if can_evolve
					else (
						"Tăng trưởng %d%%"
						% growth_speed_percent
					)
				)
			)
		)

	var pending := int(s.get("pending_chests", 0))
	_chest_button.text = "RƯƠNG • %d" % pending if pending > 0 else "RƯƠNG"
	_chest_button.disabled = pending <= 0
	_inventory_button.text = "VẬT PHẨM • %d" % int(s.get("inventory_count", 0))
	_refresh_notice(s)

func open_inventory(filter_type: StringName = &"") -> void:
	if _facade == null:
		return
	_hide_item_detail()
	_title.text = "HÒM VẬT PHẨM"
	_filters.visible = true
	_fill(_facade.inventory(filter_type), true)
	_layout_overlay()
	_overlay.visible = true

var _chest_animating := false

func show_chest_rewards(items: Array[Dictionary]) -> void:
	if _chest_animating:
		return
	_chest_animating = true
	var effect := preload("res://screens/pet_home/chest_open_effect.gd").new()
	add_child(effect)
	effect.z_index = 100
	effect.finished.connect(func() -> void:
		_chest_animating = false
		_hide_item_detail()
		_title.text = "RƯƠNG"
		_filters.visible = false
		_fill(items, false)
		_layout_overlay()
		_overlay.visible = true
		refresh_status(_facade.snapshot())
	)

func show_message(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_hide_toast)

func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = -12
	panel.custom_minimum_size = Vector2(224, 112)
	panel.add_theme_stylebox_override("panel", _style(Color(0.06,0.04,0.12,0.92), Color(0.5,0.36,0.72,0.9)))
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left","margin_top","margin_right","margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_pet_name_label = Label.new()
	_pet_name_label.text = "THÚ CƯNG"
	_pet_name_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_pet_name_label)

	var stage := Label.new()
	_stage_label = stage
	stage.text = "ẤU THỂ"
	stage.add_theme_font_size_override("font_size", 12)
	box.add_child(stage)

	_growth_bar = ProgressBar.new()
	_growth_bar.max_value = 100
	_growth_bar.show_percentage = false
	_growth_bar.custom_minimum_size = Vector2(0, 13)
	box.add_child(_growth_bar)

	_growth_label = Label.new()
	_growth_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_growth_label)

	_fullness_bar = ProgressBar.new()
	_fullness_bar.max_value = 100
	_fullness_bar.show_percentage = false
	_fullness_bar.custom_minimum_size = Vector2(0, 9)
	box.add_child(_fullness_bar)

	var row := HBoxContainer.new()
	box.add_child(row)
	_food_label = Label.new()
	_food_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_food_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_food_label)
	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_state_label)

	_evolve_button = _action_button("TIẾN HÓA")
	_evolve_button.anchor_left = 0.18
	_evolve_button.anchor_right = 0.82
	_evolve_button.anchor_top = 1.0
	_evolve_button.anchor_bottom = 1.0
	_evolve_button.offset_top = -170
	_evolve_button.offset_bottom = -122
	_evolve_button.visible = false
	_evolve_button.pressed.connect(func(): evolution_requested.emit())
	add_child(_evolve_button)

	_build_notice_bar()

	var actions := HBoxContainer.new()
	actions.anchor_left = 0.5
	actions.anchor_top = 1.0
	actions.anchor_right = 0.5
	actions.anchor_bottom = 1.0
	actions.offset_left = -165
	actions.offset_top = -68
	actions.offset_right = 165
	actions.offset_bottom = -16
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)

	_chest_button = _action_button("RƯƠNG")
	_chest_button.pressed.connect(_emit_chest_open)
	actions.add_child(_chest_button)

	_inventory_button = _action_button("HÒM VẬT PHẨM")
	_inventory_button.pressed.connect(_open_inventory_all)
	actions.add_child(_inventory_button)

	_entertainment_button = _action_button("CHƠI")
	_entertainment_button.pressed.connect(_emit_entertainment)
	actions.add_child(_entertainment_button)

func _build_notice_bar() -> void:
	_notice_bar = PanelContainer.new()
	_notice_bar.anchor_left = 0.04
	_notice_bar.anchor_top = 1.0
	_notice_bar.anchor_right = 0.96
	_notice_bar.anchor_bottom = 1.0
	_notice_bar.offset_top = -116
	_notice_bar.offset_bottom = -76
	_notice_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_bar.add_theme_stylebox_override(
		"panel",
		_style(
			Color(0.06, 0.04, 0.12, 0.94),
			Color(0.52, 0.38, 0.78, 0.92)
		)
	)
	add_child(_notice_bar)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_notice_bar.add_child(margin)

	_notice_label = Label.new()
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.add_theme_font_size_override("font_size", 12)
	_notice_label.text = ""
	margin.add_child(_notice_label)
	_notice_bar.visible = false


func _refresh_notice(s: Dictionary) -> void:
	if (
		_notice_bar == null
		or _notice_label == null
	):
		return

	var final_form := bool(
		s.get(
			"final_form",
			false
		)
	)
	var ready := bool(
		s.get(
			"ready_to_evolve",
			false
		)
	)
	var hibernating := bool(
		s.get(
			"hibernating",
			false
		)
	)
	var food_percent := int(
		s.get(
			"food_percent",
			0
		)
	)
	var food_ratio := float(
		s.get(
			"food_ratio",
			0.0
		)
	)
	var growth_speed_percent := maxi(
		0,
		int(
			s.get(
				"growth_speed_percent",
				0
			)
		)
	)

	var message := ""

	# Ưu tiên trạng thái ảnh hưởng trực tiếp đến tiến trình.
	if ready and not final_form:
		message = "Đã đủ điều kiện tiến hóa."
	elif hibernating:
		if food_ratio <= 0.0:
			message = (
				"Độ no đã hết • thú cưng đang ngủ đông • trưởng thành tạm dừng."
			)
		else:
			message = (
				"Thú cưng đang ngủ đông • độ no %d%% • tốc độ trưởng thành còn %d%%."
				% [
					food_percent,
					growth_speed_percent,
				]
			)
	elif food_ratio <= StageLifecycle.LOW_SPEED_FOOD_RATIO:
		message = (
			"Độ no còn %d%% • từ 25%% trở xuống nên tốc độ trưởng thành còn %d%%."
			% [
				food_percent,
				growth_speed_percent,
			]
		)
	elif food_ratio <= StageLifecycle.FULL_SPEED_FOOD_RATIO:
		message = (
			"Độ no còn %d%% • từ 50%% trở xuống nên tốc độ trưởng thành còn %d%%."
			% [
				food_percent,
				growth_speed_percent,
			]
		)
	elif final_form:
		message = "Thú cưng đã đạt hình thái cuối."

	if message.is_empty():
		_notice_label.text = ""
		_notice_bar.visible = false
		return

	_notice_label.text = message
	_notice_bar.visible = true

func _build_overlay() -> void:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false

	var scrim := ColorRect.new()
	_overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(0.01,0.01,0.02,0.78)

	_overlay_panel = PanelContainer.new()
	_overlay.add_child(_overlay_panel)
	_overlay_panel.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)
	_overlay_panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(0.07,0.045,0.13,0.99),
			Color(0.52,0.38,0.78,0.95)
		)
	)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left","margin_top","margin_right","margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	_overlay_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 20)
	header.add_child(_title)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(_close_overlay)
	header.add_child(close)

	_filters = HBoxContainer.new()
	root.add_child(_filters)
	_add_filter("Tất cả", &"")
	_add_filter("Ăn", ItemGenerator.TYPE_FOOD)
	_add_filter("Lớn", ItemGenerator.TYPE_GROWTH)
	_add_filter("Gen", ItemGenerator.TYPE_GENE)
	_add_filter("Khác", ItemGenerator.TYPE_FUTURE_FRAGMENT)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 3
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_list)

	_build_item_detail()


func _layout_overlay() -> void:
	if (
		_overlay == null
		or _overlay_panel == null
	):
		return

	_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var viewport_size := size

	if (
		viewport_size.x <= 1.0
		or viewport_size.y <= 1.0
	):
		return

	var side_margin := maxf(
		12.0,
		viewport_size.x * 0.05
	)
	var top_margin := maxf(
		18.0,
		viewport_size.y * 0.08
	)
	var bottom_margin := maxf(
		18.0,
		viewport_size.y * 0.07
	)

	_overlay_panel.position = Vector2(
		side_margin,
		top_margin
	)
	var panel_width := maxf(
		1.0,
		viewport_size.x
		- side_margin * 2.0
	)
	var panel_height := maxf(
		180.0,
		viewport_size.y
		- top_margin
		- bottom_margin
	)

	_overlay_panel.size = Vector2(
		panel_width,
		panel_height
	)

	if _list != null:
		var usable_width := maxf(
			1.0,
			panel_width - 28.0
		)
		_list.columns = clampi(
			int(
				floor(
					usable_width / 88.0
				)
			),
			2,
			4
		)

	if _detail_panel != null:
		var detail_width := minf(
			panel_width - 24.0,
			300.0
		)
		var detail_height := minf(
			panel_height - 36.0,
			430.0
		)
		_detail_panel.position = Vector2(
			(viewport_size.x - detail_width) * 0.5,
			(viewport_size.y - detail_height) * 0.5
		)
		_detail_panel.size = Vector2(
			detail_width,
			detail_height
		)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.visible = false
	_toast.anchor_left = 0.1
	_toast.anchor_top = 0.72
	_toast.anchor_right = 0.9
	_toast.anchor_bottom = 0.80
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_toast)

func _fill(items: Array[Dictionary], allow_use: bool) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	if items.is_empty():
		var empty := Label.new()
		empty.text = "Không có vật phẩm."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(
			240,
			72
		)
		_list.add_child(empty)
		return

	for item in items:
		_list.add_child(
			_item_tile(
				item,
				allow_use
			)
		)


func _item_tile(
	item: Dictionary,
	allow_use: bool
) -> Control:
	var rarity := String(
		item.get(
			"rarity",
			"common"
		)
	)
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(
		82,
		104
	)
	tile.focus_mode = Control.FOCUS_NONE
	tile.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	tile.add_theme_stylebox_override(
		"normal",
		_style(
			Color(
				0.11,
				0.07,
				0.18,
				0.96
			),
			_rarity_color(
				rarity
			)
		)
	)
	tile.add_theme_stylebox_override(
		"hover",
		_style(
			Color(
				0.16,
				0.11,
				0.24,
				0.98
			),
			_rarity_color(
				rarity
			)
		)
	)
	tile.pressed.connect(
		_show_item_detail.bind(
			item.duplicate(true),
			allow_use
		)
	)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	for side in [
		"margin_left",
		"margin_top",
		"margin_right",
		"margin_bottom"
	]:
		margin.add_theme_constant_override(
			side,
			5
		)
	tile.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(
		"separation",
		3
	)
	margin.add_child(box)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.custom_minimum_size.y = 64
	box.add_child(center)

	var icon = PetHomeItemIconScript.new()
	icon.custom_minimum_size = Vector2(
		58,
		58
	)
	icon.configure(
		item,
		palette
	)
	center.add_child(icon)

	var name := Label.new()
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text = ViDisplay.item_name(
		String(
			item.get(
				"display_name",
				"Vật phẩm"
			)
		)
	)
	name.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	name.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	name.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	name.add_theme_font_size_override(
		"font_size",
		9
	)
	name.add_theme_color_override(
		"font_color",
		palette.get(
			"text",
			Color.WHITE
		)
	)
	box.add_child(name)

	return tile


func _build_item_detail() -> void:
	_detail_overlay = Control.new()
	_overlay.add_child(
		_detail_overlay
	)
	_detail_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_detail_overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	_detail_overlay.visible = false

	var scrim := ColorRect.new()
	_detail_overlay.add_child(
		scrim
	)
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.01,
		0.01,
		0.02,
		0.68
	)

	_detail_panel = PanelContainer.new()
	_detail_overlay.add_child(
		_detail_panel
	)
	_detail_panel.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)
	_detail_panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(
				0.07,
				0.045,
				0.13,
				0.995
			),
			Color(
				0.52,
				0.38,
				0.78,
				0.95
			)
		)
	)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	margin.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	for side in [
		"margin_left",
		"margin_top",
		"margin_right",
		"margin_bottom"
	]:
		margin.add_theme_constant_override(
			side,
			14
		)
	_detail_panel.add_child(
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
		8
	)
	margin.add_child(
		root
	)

	var header := HBoxContainer.new()
	root.add_child(
		header
	)

	var heading := Label.new()
	heading.text = "VẬT PHẨM"
	heading.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	heading.add_theme_font_size_override(
		"font_size",
		12
	)
	heading.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	header.add_child(
		heading
	)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(
		38,
		38
	)
	close.pressed.connect(
		_hide_item_detail
	)
	header.add_child(
		close
	)

	_detail_icon_host = CenterContainer.new()
	_detail_icon_host.custom_minimum_size.y = 118
	root.add_child(
		_detail_icon_host
	)

	_detail_title = Label.new()
	_detail_title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_detail_title.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_detail_title.add_theme_font_size_override(
		"font_size",
		18
	)
	root.add_child(
		_detail_title
	)

	_detail_meta = Label.new()
	_detail_meta.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_detail_meta.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		_detail_meta
	)

	var separator := HSeparator.new()
	separator.modulate = palette.get(
		"accent",
		Color.WHITE
	)
	separator.modulate.a = 0.42
	root.add_child(
		separator
	)

	_detail_effect = Label.new()
	_detail_effect.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_detail_effect.add_theme_font_size_override(
		"font_size",
		12
	)
	root.add_child(
		_detail_effect
	)

	_detail_mods = Label.new()
	_detail_mods.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_detail_mods.add_theme_font_size_override(
		"font_size",
		11
	)
	_detail_mods.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		_detail_mods
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		spacer
	)

	_detail_use_button = Button.new()
	_detail_use_button.text = "DÙNG"
	_detail_use_button.custom_minimum_size.y = 46
	_detail_use_button.focus_mode = Control.FOCUS_NONE
	_detail_use_button.pressed.connect(
		_on_detail_use
	)
	root.add_child(
		_detail_use_button
	)

	_detail_salvage_button = Button.new()
	_detail_salvage_button.text = "PHÂN GIẢI • +1 MẢNH RƯƠNG"
	_detail_salvage_button.custom_minimum_size.y = 42
	_detail_salvage_button.focus_mode = Control.FOCUS_NONE
	_detail_salvage_button.pressed.connect(
		_on_detail_salvage
	)
	root.add_child(
		_detail_salvage_button
	)


func _show_item_detail(
	item: Dictionary,
	allow_use: bool
) -> void:
	if (
		_facade == null
		or _detail_overlay == null
	):
		return

	_detail_item = item.duplicate(true)
	_detail_allow_use = allow_use

	for child in _detail_icon_host.get_children():
		_detail_icon_host.remove_child(
			child
		)
		child.queue_free()

	var icon = PetHomeItemIconScript.new()
	icon.custom_minimum_size = Vector2(
		104,
		104
	)
	icon.configure(
		item,
		palette
	)
	_detail_icon_host.add_child(
		icon
	)

	var rarity := String(
		item.get(
			"rarity",
			"common"
		)
	)
	var quality := String(
		item.get(
			"quality",
			"normal"
		)
	)

	_detail_title.text = ViDisplay.item_name(
		String(
			item.get(
				"display_name",
				"Vật phẩm"
			)
		)
	)
	_detail_meta.text = (
		"%s • %s"
		% [
			_facade.rarity_label(
				rarity
			),
			_facade.quality_label(
				quality
			),
		]
	)
	_detail_meta.add_theme_color_override(
		"font_color",
		_rarity_color(
			rarity
		)
	)
	_detail_effect.text = _facade.describe_item(
		item
	)

	var detail_lines: Array[String] = []
	var mods := _mods(
		item
	)

	if not mods.is_empty():
		detail_lines.append(
			mods
		)

	if StringName(
		item.get(
			"item_type",
			""
		)
	) == ItemGenerator.TYPE_GENE:
		var gene_context := _gene_context_text(
			item
		)

		if not gene_context.is_empty():
			detail_lines.append(
				gene_context
			)

	if detail_lines.is_empty():
		detail_lines.append(
			"Không có thuộc tính phụ."
		)

	_detail_mods.text = "\n".join(
		detail_lines
	)

	var usable := (
		allow_use
		and _facade.can_use_item(
			item
		)
	)
	_detail_use_button.visible = allow_use
	_detail_use_button.disabled = not usable
	_detail_use_button.text = (
		"DÙNG"
		if usable
		else "CHƯA THỂ DÙNG"
	)
	_detail_salvage_button.visible = allow_use
	_detail_salvage_button.disabled = not allow_use

	_layout_overlay()
	_detail_overlay.visible = true


func _hide_item_detail() -> void:
	if _detail_overlay != null:
		_detail_overlay.visible = false

	_detail_item = {}
	_detail_allow_use = false


func _on_detail_use() -> void:
	if (
		_detail_item.is_empty()
		or not _detail_allow_use
	):
		return

	var uid := String(
		_detail_item.get(
			"uid",
			""
		)
	)

	if uid.is_empty():
		return

	_hide_item_detail()
	_emit_item_use(
		uid
	)

func _on_detail_salvage() -> void:
	if (
		_detail_item.is_empty()
		or not _detail_allow_use
	):
		return

	var uid := String(
		_detail_item.get(
			"uid",
			""
		)
	)

	if uid.is_empty():
		return

	_hide_item_detail()
	item_salvage_requested.emit(
		uid
	)


func _gene_context_text(
	item: Dictionary
) -> String:
	if _facade == null:
		return ""

	var context := _facade.gene_item_context(
		item
	)

	if context.is_empty():
		return ""

	var stages_value: Variant = context.get(
		"allowed_stages",
		[]
	)
	var stage_labels: Array[String] = []

	if typeof(stages_value) == TYPE_ARRAY:
		for stage_value in stages_value as Array:
			stage_labels.append(
				PetHomeTheme.stage_label(
					int(stage_value)
				)
			)

	var current_score := float(
		context.get(
			"current_score",
			0.0
		)
	)
	var item_score := float(
		context.get(
			"item_score",
			0.0
		)
	)
	var projected_score := float(
		context.get(
			"projected_score",
			current_score + item_score
		)
	)
	var current_tier_label := String(
		context.get(
			"current_tier_label",
			"Chưa biểu hiện"
		)
	)
	var projected_tier_label := String(
		context.get(
			"projected_tier_label",
			current_tier_label
		)
	)
	var next_threshold := float(
		context.get(
			"next_threshold",
			0.0
		)
	)
	var element_lock := String(
		context.get(
			"element_lock",
			""
		)
	)
	var element_compatible := bool(
		context.get(
			"element_compatible",
			true
		)
	)
	var lines: Array[String] = [
		"Bộ phận: %s" % _gene_locus_label(
			StringName(
				context.get(
					"locus",
					""
				)
			)
		),
		"Hướng: %s" % _gene_value_label(
			StringName(
				context.get(
					"direction",
					""
				)
			)
		),
		"Giai đoạn dùng được: %s" % (
			" • ".join(
				stage_labels
			)
			if not stage_labels.is_empty()
			else "Không có"
		),
		"Điểm hiện tại: %d • Vật phẩm +%d → %d"
		% [
			int(round(current_score)),
			int(round(item_score)),
			int(round(projected_score)),
		],
		"Biểu hiện: %s → %s"
		% [
			current_tier_label,
			projected_tier_label,
		],
	]

	if next_threshold > 0.0:
		lines.append(
			"Mốc tiếp theo: %d điểm"
			% int(
				round(
					next_threshold
				)
			)
		)
	else:
		lines.append(
			"Biểu hiện đã đạt cấp Cực đại."
		)

	if not element_lock.is_empty():
		lines.append(
			"Hệ yêu cầu: %s • %s"
			% [
				ViDisplay.element_label(
					StringName(element_lock)
				),
				(
					"phù hợp thú cưng hiện tại"
					if element_compatible
					else "giữ lại cho thú cưng hoặc kế thừa phù hợp"
				),
			]
		)

	if bool(
		context.get(
			"evolution_plan_pending",
			false
		)
	):
		lines.append(
			"Kế hoạch tiến hóa đã khóa: vật phẩm được giữ lại."
		)

	lines.append(
		"Điểm gen cộng dồn qua các giai đoạn; cơ chế tiến hóa đọc cấp biểu hiện từ tổng điểm."
	)

	return "\n".join(
		lines
	)


func _gene_locus_label(
	locus: StringName
) -> String:
	return ViDisplay.locus_label(
		locus
	)


func _gene_value_label(
	value: StringName
) -> String:
	return ViDisplay.trait_value(
		value
	)


func _mods(item: Dictionary) -> String:
	var parts: Array[String] = []
	var effects_value: Variant = item.get(
		"secondary_effects",
		[]
	)

	if typeof(effects_value) == TYPE_ARRAY:
		for raw_effect in effects_value as Array:
			if typeof(raw_effect) != TYPE_DICTIONARY:
				continue

			var effect := raw_effect as Dictionary
			var polarity := String(
				effect.get(
					"polarity",
					""
				)
			)
			var sign := (
				"+"
				if polarity == "positive"
				else "-"
			)
			var label := String(
				effect.get(
					"label",
					"Hiệu ứng"
				)
			)
			var level_label := String(
				effect.get(
					"level_label",
					""
				)
			)

			parts.append(
				"%s%s %s"
				% [
					sign,
					label,
					level_label,
				]
			)

	if not parts.is_empty():
		return "  ".join(parts)

	for value in item.get("properties", []):
		parts.append(
			"+"
			+ _facade.property_label(
				StringName(value)
			)
		)
	for value in item.get("defects", []):
		parts.append(
			"-"
			+ _facade.defect_label(
				StringName(value)
			)
		)

	return "  ".join(parts)

func _add_filter(label: String, filter_type: StringName) -> void:
	var button := Button.new()
	button.text = label
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(
		_open_filter.bind(filter_type)
	)
	_filters.add_child(button)

func _action_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(101, 52)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color(0.16,0.11,0.27,0.97), Color(0.55,0.41,0.79,0.92)))
	return button

func _style(bg: Color, border: Color) -> StyleBoxFlat:
	return PetHomeTheme.panel_style(Color(palette.get("panel", Color("171229")), bg.a), palette.get("accent", Color("a98af4")))


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color(0.50, 0.82, 0.58)
		"rare":
			return Color(0.44, 0.65, 1.0)
		"epic":
			return Color(0.76, 0.47, 1.0)
		"legendary":
			return Color(1.0, 0.72, 0.28)
		"mythic":
			return Color(0.96, 0.42, 0.86)
		_:
			return Color(0.68, 0.68, 0.74)

func _duration(seconds: int) -> String:
	var safe := maxi(0, seconds)
	var h := int(safe / 3600)
	var m := int((safe % 3600) / 60)
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm" % m
	return "<1m"


func _hide_toast() -> void:
	_toast.visible = false


func _emit_chest_open() -> void:
	if _chest_animating:
		return
	chest_open_requested.emit()


func _open_inventory_all() -> void:
	open_inventory()


func _close_overlay() -> void:
	_hide_item_detail()
	var was_visible := (
		_overlay != null
		and _overlay.visible
	)
	_overlay.visible = false
	if was_visible:
		overlay_closed.emit()


func _emit_item_use(uid: String) -> void:
	item_use_requested.emit(uid)


func _emit_entertainment() -> void:
	entertainment_requested.emit()


func _open_filter(filter_type: StringName) -> void:
	open_inventory(filter_type)
