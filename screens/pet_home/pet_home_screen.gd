class_name PetHomeScreen
extends Control


const PetHomeThemeScript = preload(
	"res://screens/pet_home/pet_home_theme.gd"
)
const PetHomeDrawerScript = preload(
	"res://screens/pet_home/pet_home_drawer.gd"
)
const PetHomeLogoScript = preload(
	"res://screens/pet_home/pet_home_logo.gd"
)
const PetSceneProfileScript = preload(
	"res://features/evolution/domain/pet_scene_profile.gd"
)


var _game := InfantGameFacade.new()
var _hud: PetHomeGameplayUI
var _hub: EntertainmentHubUI
var _game_tick: float = 0.0
var _paused: bool = false
var _skip_tick: bool = false
var _theme: Dictionary = {}
var _data: Dictionary = {}

var _background: TextureRect
var _name_label: Label
var _growth_bar: ProgressBar
var _fullness_bar: ProgressBar
var _menu_button: Button
var _drawer
var _section_overlay: Control
var _section_title: Label
var _section_body: VBoxContainer
var _active_section: StringName = &""
var _crystal_status_value: Label
var _crystal_stage_value: Label
var _crystal_timer_value: Label
var _crystal_running: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not _load_pet():
		push_error(
			"PetHomeScreen: không load được pet hiện tại."
		)
		return

	_build_background()
	_build_main_hud()
	_build_drawer()
	_build_section_overlay()
	_setup_gameplay()


func _unhandled_input(
	event: InputEvent
) -> void:
	if (
		event.is_action_pressed(
			"ui_cancel"
		)
		and _drawer != null
		and _drawer.is_open()
	):
		_drawer.close_drawer()
		get_viewport().set_input_as_handled()


func _load_pet() -> bool:
	_data = EvolutionSaveService.new().load_data()

	if _data.is_empty():
		return false

	var identity_value: Variant = _data.get(
		"identity",
		{}
	)
	var genome_value: Variant = _data.get(
		"genome",
		{}
	)
	var visual_value: Variant = _data.get(
		"current_visual",
		{}
	)
	var scene_value: Variant = _data.get(
		"scene_profile",
		{}
	)

	if (
		typeof(identity_value) != TYPE_DICTIONARY
		or typeof(genome_value) != TYPE_DICTIONARY
		or typeof(visual_value) != TYPE_DICTIONARY
		or typeof(scene_value) != TYPE_DICTIONARY
	):
		return false

	var identity := PetIdentity.from_dict(
		identity_value as Dictionary
	)
	var genome := PetGenome.from_dict(
		genome_value as Dictionary
	)
	var visual := PetVisualRecord.from_dict(
		visual_value as Dictionary
	)
	var scene = PetSceneProfileScript.from_dict(
		scene_value as Dictionary
	)

	if (
		identity == null
		or genome == null
		or visual == null
		or scene == null
		or not FileAccess.file_exists(
			visual.image_path
		)
	):
		return false

	_data["_identity_object"] = identity
	_data["_genome_object"] = genome
	_data["_visual_object"] = visual
	_data["_scene_object"] = scene

	_theme = PetHomeThemeScript.for_element(
		identity.element()
	)

	return true


func _build_background() -> void:
	var visual = _data.get(
		"_visual_object"
	)

	var image := Image.new()
	var error := image.load(
		visual.image_path
	)

	if error != OK:
		push_error(
			"PetHomeScreen: không load được ảnh PetHome."
		)
		return

	_background = TextureRect.new()
	_background.name = "PetHomeVisual"
	_background.texture = (
		ImageTexture.create_from_image(
			image
		)
	)
	_background.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	_background.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	_background.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	add_child(_background)


func _build_main_hud() -> void:
	var genome = _data.get(
		"_genome_object"
	)

	var growth_percent := clampi(
		int(
			round(
				genome.body_growth()
				* 100.0
			)
		),
		0,
		100
	)
	var fullness_percent := _current_fullness_percent()

	var panel := PanelContainer.new()
	panel.name = "PetSummary"
	panel.anchor_left = 0.045
	panel.anchor_top = 0.035
	panel.anchor_right = 0.50
	panel.anchor_bottom = 0.195
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color.a = 0.82

	var accent: Color = _theme.get(
		"accent",
		Color.WHITE
	)
	var soft_accent := accent
	soft_accent.a = 0.62

	panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			soft_accent,
			15
		)
	)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		10
	)
	margin.add_theme_constant_override(
		"margin_top",
		8
	)
	margin.add_theme_constant_override(
		"margin_right",
		10
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		8
	)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		4
	)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		7
	)
	box.add_child(header)

	var logo = PetHomeLogoScript.new()
	logo.custom_minimum_size = Vector2(
		28,
		28
	)
	logo.configure(
		accent,
		panel_color
	)
	header.add_child(logo)

	_name_label = Label.new()
	_name_label.text = str(
		_data.get(
			"pet_name",
			"PET"
		)
	)
	_name_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_name_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	_name_label.add_theme_font_size_override(
		"font_size",
		17
	)
	_name_label.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	header.add_child(_name_label)

	_growth_bar = _add_meter(
		box,
		"Trưởng thành",
		growth_percent,
		accent
	)
	_fullness_bar = _add_meter(
		box,
		"Độ no",
		fullness_percent,
		accent
	)

	_menu_button = Button.new()
	_menu_button.name = "MenuButton"
	_menu_button.text = "☰"
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.anchor_left = 0.855
	_menu_button.anchor_top = 0.035
	_menu_button.anchor_right = 0.955
	_menu_button.anchor_bottom = 0.100
	_menu_button.add_theme_font_size_override(
		"font_size",
		19
	)
	_menu_button.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	var menu_bg := panel_color
	menu_bg.a = 0.80

	_menu_button.add_theme_stylebox_override(
		"normal",
		PetHomeThemeScript.panel_style(
			menu_bg,
			accent,
			13
		)
	)
	_menu_button.add_theme_stylebox_override(
		"hover",
		PetHomeThemeScript.panel_style(
			panel_color.lightened(0.08),
			accent,
			13
		)
	)
	_menu_button.pressed.connect(
		_on_menu_pressed
	)
	add_child(_menu_button)


func _add_meter(
	parent: VBoxContainer,
	label_text: String,
	percent: int,
	accent: Color
) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		8
	)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	label.add_theme_font_size_override(
		"font_size",
		10
	)
	label.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	row.add_child(label)

	var value := Label.new()
	value.text = "%d%%" % percent
	value.add_theme_font_size_override(
		"font_size",
		10
	)
	value.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	row.add_child(value)

	var bar := ProgressBar.new()
	bar.set_meta("value_label", value)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = percent
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(
		0,
		10
	)

	var track := PetHomeThemeScript.panel_style(
		Color(0.02, 0.02, 0.04, 0.48),
		Color(0.0, 0.0, 0.0, 0.0),
		6
	)
	bar.add_theme_stylebox_override(
		"background",
		track
	)

	var fill_color := accent
	fill_color.a = 0.92
	var fill := PetHomeThemeScript.panel_style(
		fill_color,
		fill_color,
		6
	)
	bar.add_theme_stylebox_override(
		"fill",
		fill
	)

	parent.add_child(bar)

	return bar


func _current_fullness_percent() -> int:
	var state_value: Variant = _data.get(
		"pet_home_state",
		{}
	)

	if typeof(state_value) != TYPE_DICTIONARY:
		return 100

	var state := state_value as Dictionary

	if state.has(
		"fullness_percent"
	):
		return clampi(
			int(
				state.get(
					"fullness_percent",
					100
				)
			),
			0,
			100
		)

	if state.has(
		"fullness"
	):
		var fullness := float(
			state.get(
				"fullness",
				1.0
			)
		)

		if fullness <= 1.0:
			fullness *= 100.0

		return clampi(
			int(
				round(
					fullness
				)
			),
			0,
			100
		)

	return 100


func _build_drawer() -> void:
	_drawer = PetHomeDrawerScript.new()
	_drawer.name = "SideDrawer"
	add_child(_drawer)
	_drawer.configure(
		_theme
	)
	_drawer.action_requested.connect(
		_on_drawer_action
	)


func _build_section_overlay() -> void:
	_section_overlay = Control.new()
	_section_overlay.name = "SectionOverlay"
	_section_overlay.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	_section_overlay.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	_section_overlay.visible = false
	add_child(_section_overlay)

	var scrim := ColorRect.new()
	scrim.set_anchors_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.01,
		0.01,
		0.02,
		0.62
	)
	_section_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.07
	panel.anchor_top = 0.10
	panel.anchor_right = 0.93
	panel.anchor_bottom = 0.90

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color.a = 0.97

	panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			_theme.get(
				"accent",
				Color.WHITE
			),
			18
		)
	)
	_section_overlay.add_child(panel)

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
		16
	)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	_section_title = Label.new()
	_section_title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_section_title.add_theme_font_size_override(
		"font_size",
		20
	)
	_section_title.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	header.add_child(_section_title)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(
		40,
		40
	)
	close.pressed.connect(
		_close_section
	)
	header.add_child(close)

	var separator := HSeparator.new()
	separator.modulate = _theme.get(
		"accent",
		Color.WHITE
	)
	separator.modulate.a = 0.45
	root.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	root.add_child(scroll)

	_section_body = VBoxContainer.new()
	_section_body.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	_section_body.add_theme_constant_override(
		"separation",
		8
	)
	scroll.add_child(_section_body)


func _on_menu_pressed() -> void:
	if _drawer == null:
		return

	if _drawer.is_open():
		_drawer.close_drawer()
	else:
		_drawer.open_drawer()


func _on_drawer_action(
	action_id: StringName
) -> void:
	_drawer.close_drawer()
	match action_id:
		&"pet_info":
			_open_pet_info()
		&"chest":
			_open_storage()
		&"entertainment":
			_open_games()
		&"evolution":
			_open_evolution()
		&"settings":
			_open_settings()


func _open_pet_info() -> void:
	var identity = _data.get(
		"_identity_object"
	)
	var genome = _data.get(
		"_genome_object"
	)
	var scene = _data.get(
		"_scene_object"
	)

	_prepare_section(
		"Thông tin pet"
	)

	_add_info_row(
		"Tên",
		str(
			_data.get(
				"pet_name",
				"PET"
			)
		)
	)
	_add_info_row(
		"Hệ",
		PetHomeThemeScript.element_label(
			identity.element()
		)
	)
	_add_info_row(
		"Giai đoạn",
		PetHomeThemeScript.stage_label(
			genome.stage()
		)
	)
	var gameplay_state := _game.snapshot()
	_add_info_row(
		"Trưởng thành",
		"%d%%" % int(
			gameplay_state.get(
				"growth_percent",
				0
			)
		)
	)
	if bool(
		gameplay_state.get(
			"instant_evolution_talent",
			false
		)
	):
		_add_info_row(
			"Thiên phú",
			"Bẻ cong thời gian [TEST]"
		)
	_add_info_row(
		"Loài",
		String(
			identity.species()
		).capitalize()
	)
	_add_mythic_name_row(
		identity,
		genome
	)
	_add_info_row(
		"Thế hệ",
		str(
			identity.generation()
			+ 1
		)
	)
	_add_info_row(
		"Phong cách",
		String(
			scene.palette_id
		).replace(
			"_",
			" "
		).capitalize()
	)
	_add_current_trait_rows(
		genome
	)
	_add_gene_choice_rows(
		gameplay_state
	)
	_add_last_evolution_row()

	_section_overlay.visible = true


func _add_mythic_name_row(
	identity: PetIdentity,
	genome: PetGenome
) -> void:
	if (
		identity == null
		or genome == null
	):
		return

	var destiny_value: Variant = _data.get(
		"mythic_destiny",
		{}
	)
	var name := ""

	if typeof(destiny_value) == TYPE_DICTIONARY:
		name = (
			SpeciesMythicDestinyService.new()
			.display_name_for(
				destiny_value as Dictionary,
				identity
			)
		)

	if name.is_empty():
		var catalog := SpeciesMythicMutationCatalog.new()
		var definitions := catalog.load_default()

		for mutation_id in genome.mutation_ids():
			var definition := catalog.find_by_id(
				definitions,
				mutation_id
			)

			if (
				definition != null
				and definition.species()
					== identity.species()
			):
				name = definition.display_name()
				break

	if name.is_empty():
		return

	_add_info_row(
		"Thú thần thoại",
		name
	)


func _add_current_trait_rows(
	genome: PetGenome
) -> void:
	if genome == null:
		return

	var added := 0

	for locus in PetGenomeSchema.VISUAL_LOCI:
		var trait_id := genome.get_trait(
			locus,
			PetGenomeSchema.BASE_TRAIT
		)

		if trait_id == PetGenomeSchema.BASE_TRAIT:
			continue

		_add_info_row(
			(
				"Đang có"
				if added == 0
				else ""
			),
			"%s: %s"
			% [
				_trait_label(
					locus
				),
				_trait_value(
					trait_id
				),
			]
		)
		added += 1

	if added == 0:
		_add_info_row(
			"Đang có",
			"Cơ bản"
		)


func _add_gene_choice_rows(
	state: Dictionary
) -> void:
	var used := int(
		state.get(
			"gene_items_used",
			0
		)
	)
	var limit := int(
		state.get(
			"gene_item_limit",
			0
		)
	)

	if limit <= 0:
		_add_info_row(
			"Gene Item",
			"Không dùng ở stage này"
		)
		return

	_add_info_row(
		"Gene Item",
		"%d / %d"
		% [
			used,
			limit,
		]
	)

	var development_value: Variant = state.get(
		"gene_development",
		{}
	)

	if typeof(
		development_value
	) != TYPE_DICTIONARY:
		return

	var items_value: Variant = (
		development_value as Dictionary
	).get(
		"gene_items",
		[]
	)

	if typeof(items_value) != TYPE_ARRAY:
		return

	var index := 0

	for raw_value in items_value as Array:
		if typeof(raw_value) != TYPE_DICTIONARY:
			continue

		var item := raw_value as Dictionary
		var locus := StringName(
			str(
				item.get(
					"locus",
					""
				)
			)
		)
		var direction := StringName(
			str(
				item.get(
					"direction",
					""
				)
			)
		)
		var influence := float(
			item.get(
				"influence",
				0.0
			)
		)

		_add_info_row(
			(
				"Đang định hướng"
				if index == 0
				else ""
			),
			"%s → %s (+%.0f)"
			% [
				_trait_label(
					locus
				),
				_trait_value(
					direction
				),
				influence,
			]
		)
		index += 1

	if index == 0:
		_add_info_row(
			"Đang định hướng",
			"Chưa dùng Gene"
		)
	else:
		_add_info_row(
			"Kết quả",
			"Chưa khóa • chốt khi tiến hóa"
		)


func _add_last_evolution_row() -> void:
	var history_value: Variant = _data.get(
		"evolution_history",
		[]
	)

	if (
		typeof(history_value) != TYPE_ARRAY
		or (history_value as Array).is_empty()
	):
		return

	var raw_value: Variant = (
		history_value as Array
	).back()

	if typeof(raw_value) != TYPE_DICTIONARY:
		return

	var plan := raw_value as Dictionary
	var mode := StringName(
		str(
			plan.get(
				"resolution_mode",
				""
			)
		)
	)
	var deltas_value: Variant = plan.get(
		"deltas",
		[]
	)
	var deltas: Array[Dictionary] = []

	if typeof(deltas_value) == TYPE_ARRAY:
		for delta_value in deltas_value as Array:
			if typeof(delta_value) == TYPE_DICTIONARY:
				deltas.append(
					(delta_value as Dictionary).duplicate(
						true
					)
				)

	if deltas.is_empty():
		var legacy_delta_value: Variant = plan.get(
			"delta",
			{}
		)

		if (
			typeof(legacy_delta_value) == TYPE_DICTIONARY
			and not (
				legacy_delta_value as Dictionary
			).is_empty()
		):
			deltas.append(
				(legacy_delta_value as Dictionary).duplicate(
					true
				)
			)

	if (
		mode == StageEvolutionResolver.MODE_NATURAL
		and deltas.is_empty()
	):
		_add_info_row(
			"Tiến hóa gần nhất",
			"Tự nhiên • giữ nguyên Gene trait"
		)
	else:
		var index := 0

		for delta in deltas:
			var locus := StringName(
				str(
					delta.get(
						"target_trait",
						""
					)
				)
			)
			var from_trait := StringName(
				str(
					delta.get(
						"from_trait",
						""
					)
				)
			)
			var to_trait := StringName(
				str(
					delta.get(
						"to_trait",
						""
					)
				)
			)

			if (
				String(locus).is_empty()
				or String(from_trait).is_empty()
				or String(to_trait).is_empty()
			):
				continue

			_add_info_row(
				(
					"Tiến hóa gần nhất"
					if index == 0
					else ""
				),
				"%s: %s → %s"
				% [
					_trait_label(
						locus
					),
					_trait_value(
						from_trait
					),
					_trait_value(
						to_trait
					),
				]
			)
			index += 1

	var mythic_value: Variant = plan.get(
		"mythic_resolution",
		{}
	)

	if typeof(mythic_value) != TYPE_DICTIONARY:
		return

	var mythic := mythic_value as Dictionary
	var mythic_mode := StringName(
		str(
			mythic.get(
				"mode",
				"none"
			)
		)
	)
	var mythic_name := String(
		mythic.get(
			"display_name",
			""
		)
	).strip_edges()

	if (
		mythic_name.is_empty()
		or mythic_mode not in [
				SpeciesMythicMutationResolver.MODE_AWAKEN,
				SpeciesMythicMutationResolver.MODE_CONTINUE,
			]
	):
		return

	_add_info_row(
		"Thần thoại",
		(
			"Thức tỉnh %s"
			% mythic_name
			if mythic_mode
				== SpeciesMythicMutationResolver.MODE_AWAKEN
			else "Tiếp tục %s"
				% mythic_name
		)
	)


func _trait_label(
	locus: StringName
) -> String:
	match locus:
		&"body":
			return "Cơ thể"
		&"eyes":
			return "Mắt"
		&"ears":
			return "Tai"
		&"whiskers":
			return "Râu"
		&"fur":
			return "Lông"
		&"coat":
			return "Vân lông"
		&"tail":
			return "Đuôi"
		&"paws":
			return "Bàn chân"
		&"mane":
			return "Bờm"
		&"mark":
			return "Dấu"
		&"structure":
			return "Cấu trúc"
		&"aura":
			return "Hào quang"
		_:
			return String(
				locus
			).replace(
				"_",
				" "
			).capitalize()


func _trait_value(
	trait_id: StringName
) -> String:
	if trait_id == PetGenomeSchema.BASE_TRAIT:
		return "Cơ bản"

	return String(
		trait_id
	).replace(
		"_",
		" "
	).capitalize()


func _open_placeholder(
	title: String
) -> void:
	_prepare_section(
		title
	)

	var label := Label.new()
	label.text = (
		"Lối vào %s đã sẵn sàng. "
		+ "Nội dung chức năng sẽ được nối ở bước tiếp theo."
	) % title
	label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	label.add_theme_font_size_override(
		"font_size",
		13
	)
	label.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	_section_body.add_child(label)

	_section_overlay.visible = true


func _prepare_section(
	title: String,
	section_id: StringName = &""
) -> void:
	_active_section = section_id
	_crystal_status_value = null
	_crystal_stage_value = null
	_crystal_timer_value = null
	_section_title.text = title

	for child in _section_body.get_children():
		child.queue_free()


func _add_info_row(
	label_text: String,
	value_text: String
) -> Label:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_theme_constant_override(
		"separation",
		10
	)
	_section_body.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92
	label.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN
	)
	label.vertical_alignment = (
		VERTICAL_ALIGNMENT_TOP
	)
	label.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	row.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	value.size_flags_vertical = (
		Control.SIZE_SHRINK_BEGIN
	)
	value.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	value.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	value.vertical_alignment = (
		VERTICAL_ALIGNMENT_TOP
	)
	value.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	row.add_child(value)
	return value


func _close_section() -> void:
	_active_section = &""
	_crystal_status_value = null
	_crystal_stage_value = null
	_crystal_timer_value = null
	_section_overlay.visible = false


func _setup_gameplay() -> void:
	var identity: PetIdentity = _data.get("_identity_object")
	var genome: PetGenome = _data.get("_genome_object")
	_game.setup(
		identity.lineage_seed(),
		genome.stage(),
		identity.element()
	)
	theme = PetHomeGameplayTheme.build(_theme)
	_hud = PetHomeGameplayUI.new()
	_hud.palette = _theme
	_hud.dialogs_only = true
	add_child(_hud)
	_hud.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_hud.bind(_game)
	_hud.item_use_requested.connect(_use_item)
	_hud.item_salvage_requested.connect(_salvage_item)
	_hub = EntertainmentHubUI.new()
	_hub.palette = _theme
	add_child(_hub)
	_hub.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_hub.caro_win_reward_requested.connect(_reward)
	_hub.obstacle_reward_requested.connect(_reward_obstacle)
	_hub.snake_reward_requested.connect(_reward_snake)
	_refresh_gameplay()

func _process(delta: float) -> void:
	if _hud == null or _paused:
		return
	if _skip_tick:
		_skip_tick = false
		return
	_game.tick(delta)
	_game_tick += delta
	if _game_tick >= 0.5:
		_game_tick = 0.0
		_refresh_gameplay()

func _refresh_gameplay() -> void:
	var state := _game.snapshot()
	_hud.refresh_status(state)
	_growth_bar.value = int(state.get("growth_percent", 0))
	var duration_seconds := maxi(
		1,
		int(
			state.get(
				"duration_seconds",
				1
			)
		)
	)
	_fullness_bar.value = clampf(
		float(
			state.get(
				"food_seconds",
				0
			)
		) / float(duration_seconds) * 100.0,
		0,
		100
	)
	for bar in [_growth_bar, _fullness_bar]:
		var label: Label = bar.get_meta("value_label")
		label.text = "%d%%" % int(bar.value)
	var naturally_ready := bool(
		state.get(
			"ready_to_evolve",
			false
		)
	)
	var can_evolve := bool(
		state.get(
			"can_evolve",
			naturally_ready
		)
	)
	_growth_bar.tooltip_text = (
		"Sẵn sàng tiến hóa"
		if naturally_ready
		else (
			"Có thể tiến hóa ngay nhờ thiên phú TEST"
			if can_evolve
			else "Trưởng thành theo thời gian và vật phẩm"
		)
	)
	_fullness_bar.tooltip_text = "Thức ăn còn %d phút" % int(int(state.get("food_seconds", 0)) / 60)
	_refresh_crystallization_section()

func _notification(what: int) -> void:
	if _hud == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_paused = true
		_game.save()
	if what == NOTIFICATION_APPLICATION_RESUMED:
		var identity: PetIdentity = _data.get("_identity_object")
		var genome: PetGenome = _data.get("_genome_object")
		_game.setup(
			identity.lineage_seed(),
			genome.stage(),
			identity.element()
		)
		_paused = false
		_skip_tick = true

func _exit_tree() -> void:
	if _hud != null:
		_game.save()

func _section_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	_section_body.add_child(button)
	return button

func _open_storage() -> void:
	_prepare_section("Kho tài nguyên")
	var state := _game.snapshot()
	var crystal := _crystallization_snapshot()
	var crystal_text := "Sẵn sàng"

	if bool(crystal.get("running", false)):
		crystal_text = (
			"Giai đoạn %s • %s"
			% [
				_crystal_stage_name(
					int(crystal.get("stage", 1))
				),
				_format_crystal_time(
					int(
						crystal.get(
							"remaining_seconds",
							0
						)
					)
				),
			]
		)

	_add_info_row("Rương", str(state.get("pending_chests", 0)))
	_add_info_row("Vật phẩm", str(state.get("inventory_count", 0)))
	_add_info_row(
		"Mảnh rương",
		"%d/%d" % [
			int(state.get("chest_fragments", 0)),
			int(state.get("chest_fragments_required", 10)),
		]
	)
	_add_info_row("Kết tinh", crystal_text)
	_section_button("RƯƠNG • Mở rương kế tiếp", _open_chest)
	_section_button("HÒM ITEM", func(): _close_section(); _hud.open_inventory())
	_section_button("KẾT TINH NGUYÊN TỐ", _open_crystallization)
	_section_overlay.visible = true


func _open_crystallization() -> void:
	_prepare_section(
		"Kết tinh nguyên tố",
		&"crystallization"
	)
	var crystal := _crystallization_snapshot()
	var running := bool(
		crystal.get(
			"running",
			false
		)
	)
	_crystal_running = running
	var element_id := StringName(
		crystal.get(
			"element_id",
			"neutral"
		)
	)

	_add_info_row(
		"Nguyên tố",
		PetHomeThemeScript.element_label(
			element_id
		)
	)
	_crystal_status_value = _add_info_row(
		"Trạng thái",
		(
			"Đang kết tinh"
			if running
			else "Sẵn sàng"
		)
	)
	_crystal_stage_value = _add_info_row(
		"Giai đoạn",
		(
			_crystal_stage_name(
				int(
					crystal.get(
						"stage",
						1
					)
				)
			)
			if running
			else "—"
		)
	)
	_crystal_timer_value = _add_info_row(
		"Còn lại",
		(
			_format_crystal_time(
				int(
					crystal.get(
						"remaining_seconds",
						0
					)
				)
			)
			if running
			else "—"
		)
	)


	var last_value: Variant = crystal.get(
		"last_result",
		{}
	)
	if typeof(last_value) == TYPE_DICTIONARY:
		var last := last_value as Dictionary
		if not last.is_empty():
			_add_info_row(
				"Kết quả gần nhất",
				String(
					last.get(
						"display_name",
						"Vật phẩm"
					)
				)
			)

	if running:
		_section_button(
			"HỦY KẾT TINH",
			_cancel_crystallization
		)
	else:
		_section_button(
			"BẮT ĐẦU KẾT TINH",
			_start_crystallization
		)

	_section_overlay.visible = true


func _start_crystallization() -> void:
	var result := _game.start_crystallization()
	_hud.show_message(
		String(
			result.get(
				"message",
				""
			)
		)
	)

	if bool(result.get("ok", false)):
		_open_crystallization()
		_refresh_gameplay()


func _cancel_crystallization() -> void:
	var result := _game.cancel_crystallization()
	_hud.show_message(
		String(
			result.get(
				"message",
				""
			)
		)
	)

	if bool(result.get("ok", false)):
		_open_crystallization()
		_refresh_gameplay()


func _refresh_crystallization_section() -> void:
	if (
		_active_section != &"crystallization"
		or not _section_overlay.visible
	):
		return

	var crystal := _crystallization_snapshot()
	var running := bool(
		crystal.get(
			"running",
			false
		)
	)

	if running != _crystal_running:
		_crystal_running = running
		call_deferred(
			"_open_crystallization"
		)
		return

	if _crystal_status_value != null:
		_crystal_status_value.text = (
			"Đang kết tinh"
			if running
			else "Sẵn sàng"
		)

	if _crystal_stage_value != null:
		_crystal_stage_value.text = (
			_crystal_stage_name(
				int(
					crystal.get(
						"stage",
						1
					)
				)
			)
			if running
			else "—"
		)

	if _crystal_timer_value != null:
		_crystal_timer_value.text = (
			_format_crystal_time(
				int(
					crystal.get(
						"remaining_seconds",
						0
					)
				)
			)
			if running
			else "—"
		)


func _crystallization_snapshot() -> Dictionary:
	var value: Variant = _game.snapshot().get(
		"crystallization",
		{}
	)

	if typeof(value) != TYPE_DICTIONARY:
		return {}

	return (
		value as Dictionary
	).duplicate(true)


func _crystal_stage_name(
	stage: int
) -> String:
	match stage:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		_:
			return "—"


func _format_crystal_time(
	seconds: int
) -> String:
	var safe := maxi(
		0,
		seconds
	)
	var hours := int(
		safe / 3600
	)
	var minutes := int(
		(safe % 3600) / 60
	)
	var secs := safe % 60
	return "%02d:%02d:%02d" % [
		hours,
		minutes,
		secs,
	]

func _open_chest() -> void:
	var items := _game.open_next_chest()
	if items.is_empty():
		_hud.show_message("Không có rương hoặc chưa lưu được. Hãy thử lại.")
		return
	_close_section()
	_hud.show_chest_rewards(items)
	_refresh_gameplay()

func _use_item(uid: String) -> void:
	var result := _game.use_item(uid)
	_hud.show_message(str(result.get("message", "")))
	_hud.open_inventory()
	_refresh_gameplay()

func _salvage_item(uid: String) -> void:
	var result := _game.salvage_item(uid)
	_hud.show_message(
		str(
			result.get(
				"message",
				""
			)
		)
	)
	_hud.open_inventory()
	_refresh_gameplay()


func _open_games() -> void:
	var state := _game.snapshot()
	var stage_index := int(
		state.get(
			"stage_index",
			1
		)
	)
	var ready := bool(
		state.get(
			"ready_to_evolve",
			false
		)
	)
	_hub.open_hub(
		int(
			state.get(
				"caro_rewards_claimed",
				0
			)
		),
		int(
			state.get(
				"caro_rewards_max",
				4
			)
		),
		stage_index == 1 and not ready,
		stage_index,
		int(
			state.get(
				"stage2_activity_rewards_claimed",
				0
			)
		),
		int(
			state.get(
				"stage2_activity_rewards_max",
				4
			)
		),
		stage_index == 2
	)


func _reward() -> void:
	var result := _game.claim_caro_win_reward()
	_hub.show_reward_message(
		str(
			result.get(
				"message",
				""
			)
		)
	)
	_sync_entertainment_reward_state()
	_refresh_gameplay()


func _reward_obstacle(
	score: int,
	match_id: String
) -> void:
	var result := _game.claim_obstacle_run_reward(
		score,
		match_id
	)
	_hub.show_obstacle_reward_message(
		str(
			result.get(
				"message",
				""
			)
		)
	)
	_sync_entertainment_reward_state()
	_refresh_gameplay()


func _reward_snake(
	score: int,
	match_id: String
) -> void:
	var result := _game.claim_snake_hunt_reward(
		score,
		match_id
	)
	_hub.show_snake_reward_message(
		str(
			result.get(
				"message",
				""
			)
		)
	)
	_sync_entertainment_reward_state()
	_refresh_gameplay()


func _sync_entertainment_reward_state() -> void:
	var state := _game.snapshot()
	var stage_index := int(
		state.get(
			"stage_index",
			1
		)
	)
	var ready := bool(
		state.get(
			"ready_to_evolve",
			false
		)
	)

	_hub.set_reward_status(
		int(
			state.get(
				"caro_rewards_claimed",
				0
			)
		),
		int(
			state.get(
				"caro_rewards_max",
				4
			)
		),
		stage_index == 1 and not ready
	)
	_hub.set_stage2_reward_status(
		int(
			state.get(
				"stage2_activity_rewards_claimed",
				0
			)
		),
		int(
			state.get(
				"stage2_activity_rewards_max",
				4
			)
		),
		stage_index == 2,
		stage_index
	)

func _open_evolution() -> void:
	_prepare_section("Tiến hóa")
	var state := _game.snapshot()
	var stage_index := int(
		state.get(
			"stage_index",
			1
		)
	)
	var naturally_ready := bool(
		state.get(
			"ready_to_evolve",
			false
		)
	)
	var can_evolve := bool(
		state.get(
			"can_evolve",
			naturally_ready
		)
	)
	var age_remaining := maxi(
		0,
		int(
			state.get(
				"age_remaining_seconds",
				0
			)
		)
	)
	var growth_remaining := maxi(
		0,
		int(
			state.get(
				"growth_remaining_seconds",
				0
			)
		)
	)

	_add_info_row(
		"Giai đoạn",
		PetHomeTheme.stage_label(
			stage_index
		)
	)
	_add_info_row(
		"Trưởng thành",
		"%d%%"
		% int(
			state.get(
				"growth_percent",
				0
			)
		)
	)
	_add_info_row(
		"Tuổi stage",
		"%d%%"
		% int(
			state.get(
				"age_percent",
				0
			)
		)
	)
	_add_info_row(
		"Deadline",
		(
			"Đã tới hạn"
			if bool(
				state.get(
					"deadline_reached",
					false
				)
			)
			else "Còn " + _format_stage_time(
				age_remaining
			)
		)
	)
	_add_info_row(
		"Thức ăn",
		_format_stage_time(
			maxi(
				0,
				int(
					state.get(
						"food_seconds",
						0
					)
				)
			)
		)
	)

	var genome := _data.get(
		"_genome_object"
	) as PetGenome

	if genome != null:
		_add_current_trait_rows(
			genome
		)

	_add_gene_choice_rows(
		state
	)

	if stage_index >= StageLifecycle.FINAL_STAGE:
		_add_info_row(
			"Trạng thái",
			"Đã đạt hình thái cuối"
		)
	elif can_evolve:
		_add_info_row(
			"Trạng thái",
			"SẴN SÀNG TIẾN HÓA"
		)

		if (
			not naturally_ready
			and bool(
				state.get(
					"instant_evolution_talent",
					false
				)
			)
		):
			_add_info_row(
				"Thiên phú TEST",
				"Bỏ qua thời gian chờ"
			)

		_section_button(
			"TIẾN HÓA → %s"
			% PetHomeTheme.stage_label(
				stage_index + 1
			),
			_evolve
		)
	else:
		_add_info_row(
			"Thiếu Growth",
			_format_stage_time(
				growth_remaining
			)
		)

	_section_overlay.visible = true


func _format_stage_time(
	seconds: int
) -> String:
	seconds = maxi(
		0,
		seconds
	)

	if seconds <= 0:
		return "0 phút"

	var total_minutes := int(
		ceil(
			float(seconds) / 60.0
		)
	)
	var days := int(
		total_minutes / 1440
	)
	var hours := int(
		(
			total_minutes % 1440
		) / 60
	)
	var minutes := total_minutes % 60
	var parts: Array[String] = []

	if days > 0:
		parts.append(
			"%d ngày" % days
		)

	if hours > 0:
		parts.append(
			"%d giờ" % hours
		)

	if (
		minutes > 0
		and days == 0
	):
		parts.append(
			"%d phút" % minutes
		)

	return " ".join(
		parts
	)


func _evolve() -> void:
	var state := _game.snapshot()
	var can_evolve := bool(
		state.get(
			"can_evolve",
			state.get(
				"ready_to_evolve",
				false
			)
		)
	)

	if can_evolve and _game.save():
		get_tree().change_scene_to_file(
			"res://scenes/evolution_update.tscn"
		)

func _open_settings() -> void:
	_prepare_section("Cài đặt")
	var sound := CheckButton.new()
	sound.text = "Âm thanh"
	sound.button_pressed = not AudioServer.is_bus_mute(0)
	sound.toggled.connect(func(enabled: bool): AudioServer.set_bus_mute(0, not enabled))
	_section_body.add_child(sound)
	_section_button("Lưu tiến trình", func(): _hud.show_message("Đã lưu" if _game.save() else "Chưa lưu được. Hãy thử lại."))
	_section_overlay.visible = true
