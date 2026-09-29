class_name PetHomeGameplayUI
extends Control

var palette: Dictionary = {}
var dialogs_only: bool = false

signal chest_open_requested
signal item_use_requested(uid: String)
signal entertainment_requested
signal evolution_requested

var _facade: InfantGameFacade
var _pet_name_label: Label
var _growth_bar: ProgressBar
var _growth_label: Label
var _food_label: Label
var _state_label: Label
var _chest_button: Button
var _inventory_button: Button
var _entertainment_button: Button
var _overlay: Control
var _overlay_panel: PanelContainer
var _title: Label
var _list: VBoxContainer
var _filters: HBoxContainer
var _toast: Label
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
	_food_label.text = (
		"Thức ăn  "
		+ _duration(
			int(
				s.get(
					"food_seconds",
					0
				)
			)
		)
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
			"Sẵn sàng tiến hóa"
			if ready
			else (
				"Có thể tiến hóa ngay [TEST]"
				if can_evolve
				else (
					"Còn ~"
					+ _duration(
						int(
							s.get(
								"growth_remaining_seconds",
								0
							)
						)
					)
				)
			)
		)

	var pending := int(s.get("pending_chests", 0))
	_chest_button.text = "RƯƠNG • %d" % pending if pending > 0 else "RƯƠNG"
	_chest_button.disabled = pending <= 0
	_inventory_button.text = "KHO • %d" % int(s.get("inventory_count", 0))

func open_inventory(filter_type: StringName = &"") -> void:
	if _facade == null:
		return
	_title.text = "KHO ĐỒ"
	_filters.visible = true
	_fill(_facade.inventory(filter_type), true)
	_layout_overlay()
	_overlay.visible = true

func show_chest_rewards(items: Array[Dictionary]) -> void:
	_title.text = "RƯƠNG"
	_filters.visible = false
	_fill(items, false)
	_layout_overlay()
	_overlay.visible = true
	refresh_status(_facade.snapshot())

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
	_pet_name_label.text = "PET"
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
	_evolve_button.offset_top = -126
	_evolve_button.offset_bottom = -78
	_evolve_button.visible = false
	_evolve_button.pressed.connect(func(): evolution_requested.emit())
	add_child(_evolve_button)

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

	_inventory_button = _action_button("KHO")
	_inventory_button.pressed.connect(_open_inventory_all)
	actions.add_child(_inventory_button)

	_entertainment_button = _action_button("CHƠI")
	_entertainment_button.pressed.connect(_emit_entertainment)
	actions.add_child(_entertainment_button)

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
	_add_filter("Khác", ItemGenerator.TYPE_FUTURE_FRAGMENT)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_list)


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
	_overlay_panel.size = Vector2(
		maxf(
			1.0,
			viewport_size.x
			- side_margin * 2.0
		),
		maxf(
			180.0,
			viewport_size.y
			- top_margin
			- bottom_margin
		)
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
		_list.add_child(empty)
		return
	for item in items:
		_list.add_child(_item_card(item, allow_use))

func _item_card(item: Dictionary, allow_use: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.11,0.07,0.18,0.96), _rarity_color(String(item.get("rarity","common")))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name := Label.new()
	name.text = String(item.get("display_name", "Vật phẩm"))
	name.add_theme_font_size_override("font_size", 14)
	info.add_child(name)

	var rarity := String(item.get("rarity","common"))
	var quality := String(item.get("quality","normal"))
	var meta := Label.new()
	meta.text = "%s • %s" % [_facade.rarity_label(rarity), _facade.quality_label(quality)]
	meta.add_theme_color_override("font_color", _rarity_color(rarity))
	meta.add_theme_font_size_override("font_size", 12)
	info.add_child(meta)

	var effect := Label.new()
	effect.text = _facade.describe_item(item)
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", 12)
	info.add_child(effect)

	var mods := _mods(item)
	if not mods.is_empty():
		var mod_label := Label.new()
		mod_label.text = mods
		mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_label.add_theme_font_size_override("font_size", 12)
		info.add_child(mod_label)

	if allow_use:
		var usable := _facade.can_use_item(
			item
		)
		var button := Button.new()
		button.text = "Dùng" if usable else "Khóa"
		button.disabled = not usable
		if usable:
			button.pressed.connect(
				_emit_item_use.bind(String(item.get("uid", "")))
			)
		row.add_child(button)
	return panel

func _mods(item: Dictionary) -> String:
	var parts: Array[String] = []
	for value in item.get("properties", []):
		parts.append("+" + _facade.property_label(StringName(value)))
	for value in item.get("defects", []):
		parts.append("-" + _facade.defect_label(StringName(value)))
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
	chest_open_requested.emit()


func _open_inventory_all() -> void:
	open_inventory()


func _close_overlay() -> void:
	_overlay.visible = false


func _emit_item_use(uid: String) -> void:
	item_use_requested.emit(uid)


func _emit_entertainment() -> void:
	entertainment_requested.emit()


func _open_filter(filter_type: StringName) -> void:
	open_inventory(filter_type)
