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
var _final_record_service := FinalRecordService.new()
var _final_record_renderer := FinalRecordRenderer.new()
var _hud: PetHomeGameplayUI
var _hub: EntertainmentHubUI
var _game_tick: float = 0.0
var _paused: bool = false
var _skip_tick: bool = false
var _suppress_exit_save: bool = false
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
var _section_tabs: HBoxContainer
var _section_tab_buttons: Dictionary = {}
var _section_body: VBoxContainer
var _active_section: StringName = &""
var _crystal_slot_views: Dictionary = {}
var _crystal_unlocked_slots: int = 0


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
	call_deferred("_maybe_open_final_record")


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

	var growth_percent := (
		100
		if genome.stage() >= StageLifecycle.FINAL_STAGE
		else clampi(
			int(
				round(
					genome.body_growth()
						* 100.0
				)
			),
			0,
			100
		)
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
			"THÚ CƯNG"
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
	_menu_button.anchor_top = 0.900
	_menu_button.anchor_right = 0.955
	_menu_button.anchor_bottom = 0.965
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
	bar.set_meta("title_label", label)
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
	_drawer.set_menu_button(_menu_button)
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

	_section_tabs = HBoxContainer.new()
	_section_tabs.visible = false
	_section_tabs.add_theme_constant_override(
		"separation",
		6
	)
	root.add_child(_section_tabs)

	_add_pet_info_tab_button(
		"THÔNG TIN",
		&"info"
	)
	_add_pet_info_tab_button(
		"KỸ NĂNG & GEN",
		&"skills_gene"
	)
	_add_pet_info_tab_button(
		"TIẾN HÓA",
		&"evolution"
	)

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
			_open_pet_info_tab(
				&"evolution"
			)
		&"achievement":
			_open_achievements()
		&"settings":
			_open_settings()


func _add_pet_info_tab_button(
	label_text: String,
	tab_id: StringName
) -> void:
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(
		0,
		46
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	button.clip_text = true
	button.pressed.connect(
		_open_pet_info_tab.bind(
			tab_id
		)
	)
	_section_tabs.add_child(button)
	_section_tab_buttons[tab_id] = button


func _open_pet_info() -> void:
	_open_pet_info_tab(
		&"info"
	)


func _open_pet_info_tab(
	tab_id: StringName
) -> void:
	_prepare_section(
		"Thông tin thú cưng",
		&"pet_info"
	)
	_section_tabs.visible = true

	for key in _section_tab_buttons:
		var button := (
			_section_tab_buttons[key]
			as Button
		)
		if button != null:
			button.disabled = (
				StringName(key)
				== tab_id
			)

	match tab_id:
		&"skills_gene":
			_populate_pet_skills_gene_tab()
		&"evolution":
			_populate_pet_evolution_tab()
		_:
			_populate_pet_info_tab()

	_section_overlay.visible = true


func _populate_pet_info_tab() -> void:
	var identity = _data.get(
		"_identity_object"
	)
	var genome = _data.get(
		"_genome_object"
	)

	_add_info_row(
		"Tên",
		str(
			_data.get(
				"pet_name",
				"THÚ CƯNG"
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
		"Loài",
		ViDisplay.species_label(
			identity.species()
		)
	)
	_add_info_row(
		"Giai đoạn",
		PetHomeThemeScript.stage_label(
			genome.stage()
		)
	)
	_add_info_row(
		"Thế hệ",
		str(
			identity.generation()
			+ 1
		)
	)
	_add_mythic_name_row(
		identity,
		genome
	)

	var gameplay_state := _game.snapshot()
	var inherited_items_value: Variant = gameplay_state.get(
		"legacy_inherited_items",
		[]
	)
	if (
		typeof(inherited_items_value) == TYPE_ARRAY
		and not (
			inherited_items_value as Array
		).is_empty()
	):
		_add_info_row(
			"Kế thừa",
			"%d vật phẩm từ đời trước"
			% (
				inherited_items_value as Array
			).size()
		)
	else:
		var inherited_value: Variant = gameplay_state.get(
			"legacy_inherited_item",
			{}
		)
		if (
			typeof(inherited_value) == TYPE_DICTIONARY
			and not (
				inherited_value as Dictionary
			).is_empty()
		):
			_add_info_row(
				"Kế thừa",
				_legacy_item_label(
					inherited_value as Dictionary
				)
			)


func _populate_pet_skills_gene_tab() -> void:
	var state := _game.snapshot()
	var skills_value: Variant = state.get(
		"skills",
		[]
	)

	if (
		typeof(skills_value) != TYPE_ARRAY
		or (skills_value as Array).is_empty()
	):
		_add_info_row(
			"Kỹ năng",
			"Chưa có"
		)
	else:
		_add_skill_rows(
			state
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
	_add_last_evolution_row()


func _add_mythic_name_row(
	identity: PetIdentity,
	genome: PetGenome
) -> void:
	if (
		identity == null
		or genome == null
	):
		return

	var name := ""
	var catalog := SpeciesMythicMutationCatalog.new()
	var definitions := catalog.load_default()

	# Mythic Destiny is intentionally hidden until the branch actually
	# awakens in the Genome. Stage-1 hints stay visual only so players
	# can notice something unusual without the UI revealing the answer.
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
		"Biến dị huyền ảo",
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
	var unlimited := bool(
		state.get(
			"gene_unlimited",
			false
		)
	)
	var lifetime_used := int(
		state.get(
			"gene_items_used_lifetime",
			used
		)
	)

	if unlimited:
		_add_info_row(
			"Vật phẩm gen hiện tại",
			"Đã dùng %d • Không giới hạn" % used
		)
	elif limit <= 0:
		_add_info_row(
			"Vật phẩm gen hiện tại",
			"Không dùng ở giai đoạn này"
		)
	else:
		_add_info_row(
			"Vật phẩm gen hiện tại",
			"%d / %d"
			% [
				used,
				limit,
			]
		)

	if lifetime_used > 0:
		_add_info_row(
			"Gen đã dùng toàn đời",
			"%d vật phẩm" % lifetime_used
		)

	_add_lifetime_gene_score_rows(
		state
	)

	if limit <= 0:
		return

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
				"Định hướng hiện tại"
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
			"Định hướng hiện tại",
			"Chưa dùng gen ở giai đoạn này"
		)
	else:
		_add_info_row(
			"Kết quả",
			"Chưa khóa • chốt khi tiến hóa"
		)


func _add_lifetime_gene_score_rows(
	state: Dictionary
) -> void:
	var scores_value: Variant = state.get(
		"gene_scores",
		{}
	)

	if typeof(scores_value) != TYPE_DICTIONARY:
		return

	var scores := scores_value as Dictionary
	var keys: Array = scores.keys()
	keys.sort()
	var index := 0

	for raw_key in keys:
		var key := String(raw_key)
		var score := float(
			scores.get(
				raw_key,
				0.0
			)
		)

		if score <= 0.0:
			continue

		var parts := key.split(
			".",
			false,
			1
		)

		if parts.size() != 2:
			continue

		var locus := StringName(
			parts[0]
		)
		var direction := StringName(
			parts[1]
		)

		_add_info_row(
			(
				"Điểm gen tích lũy"
				if index == 0
				else ""
			),
			"%s → %s: +%.0f"
			% [
				_trait_label(
					locus
				),
				_trait_value(
					direction
				),
				score,
			]
		)
		index += 1


func _gene_display_name(
	gene_id: String
) -> String:
	return ViDisplay.gene_name(
		gene_id
	)


func _add_last_evolution_gene_rows(
	plan: Dictionary
) -> void:
	var items_value: Variant = plan.get(
		"gene_items_used",
		[]
	)
	var used_count := 0

	if typeof(items_value) == TYPE_ARRAY:
		for raw_item in items_value as Array:
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue

			var item := raw_item as Dictionary
			var gene_id := String(
				item.get(
					"gene_id",
					""
				)
			)
			var locus := StringName(
				String(
					item.get(
						"locus",
						""
					)
				)
			)
			var direction := StringName(
				String(
					item.get(
						"direction",
						""
					)
				)
			)
			var score := float(
				item.get(
					"score",
					item.get(
						"influence",
						0.0
					)
				)
			)

			_add_info_row(
				(
					"Gen đã dùng"
					if used_count == 0
					else ""
				),
				"%s • %s → %s (+%.0f)"
				% [
					_gene_display_name(
						gene_id
					),
					_trait_label(
						locus
					),
					_trait_value(
						direction
					),
					score,
				]
			)
			used_count += 1

	var resolution_value: Variant = plan.get(
		"gene_resolution",
		{}
	)

	if typeof(resolution_value) != TYPE_DICTIONARY:
		return

	var resolution := resolution_value as Dictionary
	var changes_value: Variant = resolution.get(
		"selected_changes",
		[]
	)

	if typeof(changes_value) != TYPE_ARRAY:
		return

	var expression_index := 0

	for raw_change in changes_value as Array:
		if typeof(raw_change) != TYPE_DICTIONARY:
			continue

		var change := raw_change as Dictionary
		var gene_id := String(
			change.get(
				"gene_id",
				""
			)
		)
		var locus := StringName(
			String(
				change.get(
					"locus",
					""
				)
			)
		)
		var resolved_trait := StringName(
			String(
				change.get(
					"resolved_trait",
					change.get(
						"direction",
						""
					)
				)
			)
		)
		var influence := float(
			change.get(
				"influence",
				0.0
			)
		)

		_add_info_row(
			(
				"Gen biểu hiện"
				if expression_index == 0
				else ""
			),
			"%s • %s → %s (+%.0f)"
			% [
				_gene_display_name(
					gene_id
				),
				_trait_label(
					locus
				),
				_trait_value(
					resolved_trait
				),
				influence,
			]
		)
		expression_index += 1


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

	_add_last_evolution_gene_rows(
		plan
	)

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
			"Tự nhiên • giữ nguyên đặc tính gen"
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
	return ViDisplay.locus_label(
		locus
	)


func _trait_value(
	trait_id: StringName
) -> String:
	return ViDisplay.trait_value(
		trait_id
	)


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
	AudioService.play("open")
	_active_section = section_id
	_crystal_slot_views.clear()
	_crystal_unlocked_slots = 0
	_section_title.text = title
	if _section_tabs != null:
		_section_tabs.visible = false

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
	AudioService.play("close")
	_active_section = &""
	_crystal_slot_views.clear()
	_crystal_unlocked_slots = 0
	_section_overlay.visible = false


func _setup_gameplay() -> void:
	var identity: PetIdentity = _data.get("_identity_object")
	var genome: PetGenome = _data.get("_genome_object")
	_game.setup(
		identity.lineage_seed(),
		genome.stage(),
		identity.element(),
		int(
			_data.get(
				"egg_stage",
				1
			)
		)
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
	_hub.energy_2048_api = _game
	_hub.energy_2048_reward_received.connect(_refresh_gameplay)
	_hub.tetris_reward_received.connect(_refresh_gameplay)
	_hub.sudoku_reward_received.connect(_refresh_gameplay)
	_hub.breakout_reward_received.connect(_refresh_gameplay)
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
	var final_form := bool(
		state.get(
			"final_form",
			false
		)
	)
	_growth_bar.value = (
		100
		if final_form
		else int(
			state.get(
				"growth_percent",
				0
			)
		)
	)
	var growth_title: Label = _growth_bar.get_meta(
		"title_label"
	)
	if growth_title != null:
		growth_title.text = (
			"Hình thái cuối"
			if final_form
			else "Trưởng thành"
		)
	_fullness_bar.value = clampf(
		float(
			state.get(
				"food_percent",
				0
			)
		),
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
		"Hình thái cuối • chuyển sang kế thừa"
		if final_form
		else (
			"Sẵn sàng tiến hóa"
			if naturally_ready
			else (
				"Có thể tiến hóa ngay nhờ thiên phú THỬ NGHIỆM"
				if can_evolve
				else "Trưởng thành theo thời gian và vật phẩm"
			)
		)
	)
	_fullness_bar.tooltip_text = "Thức ăn còn %d phút" % int(int(state.get("food_seconds", 0)) / 60)
	_refresh_crystallization_section()

func _notification(what: int) -> void:
	if _hud == null or _suppress_exit_save:
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
			identity.element(),
			int(
				_data.get(
					"egg_stage",
					1
				)
			)
		)
		_paused = false
		_skip_tick = true

func _exit_tree() -> void:
	if (
		_hud != null
		and not _suppress_exit_save
	):
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
	var unlocked_slots := int(
		crystal.get(
			"unlocked_slots",
			1
		)
	)
	var running_count := int(
		crystal.get(
			"running_count",
			0
		)
	)
	var crystal_text := (
		"Đang chạy %d/%d ô"
		% [
			running_count,
			unlocked_slots,
		]
		if running_count > 0
		else "Sẵn sàng • %d ô" % unlocked_slots
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
	_section_button("HÒM VẬT PHẨM", func(): _close_section(); _hud.open_inventory())
	_section_button("KẾT TINH NGUYÊN TỐ", _open_crystallization)
	_section_overlay.visible = true


func _open_crystallization() -> void:
	_prepare_section(
		"Kết tinh nguyên tố",
		&"crystallization"
	)
	var crystal := _crystallization_snapshot()
	var element_id := StringName(
		crystal.get(
			"element_id",
			"neutral"
		)
	)
	var unlocked_slots := clampi(
		int(
			crystal.get(
				"unlocked_slots",
				1
			)
		),
		1,
		4
	)
	_crystal_unlocked_slots = unlocked_slots

	_add_info_row(
		"Nguyên tố",
		PetHomeThemeScript.element_label(
			element_id
		)
	)

	var hint := Label.new()
	hint.text = (
		"Mỗi giai đoạn thú cưng mở thêm 1 ô kết tinh. "
		+ "Mỗi ô chạy và hủy độc lập."
	)
	hint.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	hint.add_theme_font_size_override(
		"font_size",
		11
	)
	hint.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	_section_body.add_child(
		hint
	)

	var grid := GridContainer.new()
	grid.name = "CrystallizationSlots"
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
	_section_body.add_child(
		grid
	)

	var slots_value: Variant = crystal.get(
		"slots",
		[]
	)
	var slots: Array = []
	if typeof(slots_value) == TYPE_ARRAY:
		slots = slots_value as Array

	for slot_index in range(4):
		var slot: Dictionary = {}
		if (
			slot_index < slots.size()
			and typeof(
				slots[slot_index]
			) == TYPE_DICTIONARY
		):
			slot = (
				slots[slot_index]
				as Dictionary
			)

		_build_crystallization_slot_card(
			grid,
			slot_index,
			slot,
			slot_index < unlocked_slots
		)

	_section_overlay.visible = true


func _build_crystallization_slot_card(
	parent: GridContainer,
	slot_index: int,
	slot: Dictionary,
	unlocked: bool
) -> void:
	var running := (
		unlocked
		and bool(
			slot.get(
				"running",
				false
			)
		)
	)

	var panel := PanelContainer.new()
	panel.name = (
		"CrystallizationSlot%d"
		% (slot_index + 1)
	)
	panel.custom_minimum_size = Vector2(
		0,
		178
	)
	panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color.a = (
		0.94
		if unlocked
		else 0.48
	)
	var accent: Color = _theme.get(
		"accent",
		Color.WHITE
	)
	var border := accent
	border.a = (
		0.72
		if unlocked
		else 0.18
	)
	panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			border,
			12
		)
	)
	parent.add_child(
		panel
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		10
	)
	margin.add_theme_constant_override(
		"margin_top",
		9
	)
	margin.add_theme_constant_override(
		"margin_right",
		10
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		9
	)
	panel.add_child(
		margin
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(
		"separation",
		5
	)
	margin.add_child(
		box
	)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(
		"separation",
		5
	)
	box.add_child(
		header
	)

	var title := Label.new()
	title.text = "Ô %d" % (slot_index + 1)
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title.add_theme_font_size_override(
		"font_size",
		15
	)
	title.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	header.add_child(
		title
	)

	var status := Label.new()
	status.text = _crystal_slot_status(
		running,
		unlocked
	)
	status.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	status.add_theme_font_size_override(
		"font_size",
		9
	)
	status.add_theme_color_override(
		"font_color",
		(
			accent
			if unlocked
			else _theme.get(
				"muted",
				Color.WHITE
			)
		)
	)
	header.add_child(
		status
	)

	var stage_label := Label.new()
	stage_label.text = (
		"Giai đoạn %s"
		% _crystal_stage_name(
			int(
				slot.get(
					"stage",
					1
				)
			)
		)
		if running
		else (
			"Mở ở giai đoạn %s"
			% _crystal_stage_name(
				slot_index + 1
			)
			if not unlocked
			else "Giai đoạn —"
		)
	)
	stage_label.add_theme_font_size_override(
		"font_size",
		11
	)
	stage_label.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	box.add_child(
		stage_label
	)

	var timer := Label.new()
	timer.text = (
		_format_crystal_time(
			int(
				slot.get(
					"remaining_seconds",
					0
				)
			)
		)
		if running
		else "—"
	)
	timer.add_theme_font_size_override(
		"font_size",
		16
	)
	timer.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	box.add_child(
		timer
	)

	var last_result := Label.new()
	last_result.text = (
		_crystal_last_result_text(
			slot
		)
		if unlocked
		else ""
	)
	last_result.custom_minimum_size.y = 18
	last_result.clip_text = true
	last_result.add_theme_font_size_override(
		"font_size",
		9
	)
	last_result.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	box.add_child(
		last_result
	)

	var spacer := Control.new()
	spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	box.add_child(
		spacer
	)

	var action := Button.new()
	action.focus_mode = Control.FOCUS_NONE
	action.custom_minimum_size.y = 38
	if not unlocked:
		action.text = (
			"KHÓA • STAGE %s"
			% _crystal_stage_name(
				slot_index + 1
			)
		)
		action.disabled = true
	elif running:
		action.text = "HỦY"
		action.pressed.connect(
			_cancel_crystallization.bind(
				slot_index
			)
		)
	else:
		action.text = "BẮT ĐẦU"
		action.pressed.connect(
			_start_crystallization.bind(
				slot_index
			)
		)
	box.add_child(
		action
	)

	_crystal_slot_views[
		slot_index
	] = {
		"running": running,
		"status": status,
		"stage": stage_label,
		"timer": timer,
		"last_result": last_result,
	}


func _crystal_slot_status(
	running: bool,
	unlocked: bool
) -> String:
	if not unlocked:
		return "CHƯA MỞ"
	if running:
		return "ĐANG KẾT TINH"
	return "SẴN SÀNG"


func _crystal_last_result_text(
	slot: Dictionary
) -> String:
	var value: Variant = slot.get(
		"last_result",
		{}
	)
	if typeof(value) != TYPE_DICTIONARY:
		return "Gần nhất: —"

	var last := value as Dictionary
	if last.is_empty():
		return "Gần nhất: —"

	return (
		"Gần nhất: %s"
		% String(
			last.get(
				"display_name",
				"Vật phẩm"
			)
		)
	)


func _start_crystallization(
	slot_index: int
) -> void:
	var result := _game.start_crystallization(
		slot_index
	)
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


func _cancel_crystallization(
	slot_index: int
) -> void:
	var result := _game.cancel_crystallization(
		slot_index
	)
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
	var unlocked_slots := clampi(
		int(
			crystal.get(
				"unlocked_slots",
				1
			)
		),
		1,
		4
	)

	if unlocked_slots != _crystal_unlocked_slots:
		call_deferred(
			"_open_crystallization"
		)
		return

	var slots_value: Variant = crystal.get(
		"slots",
		[]
	)
	if typeof(slots_value) != TYPE_ARRAY:
		return

	var slots := slots_value as Array
	for slot_index in range(4):
		if (
			slot_index >= slots.size()
			or typeof(
				slots[slot_index]
			) != TYPE_DICTIONARY
		):
			continue

		var view_value: Variant = (
			_crystal_slot_views.get(
				slot_index,
				{}
			)
		)
		if typeof(view_value) != TYPE_DICTIONARY:
			continue

		var view := view_value as Dictionary
		var slot := slots[slot_index] as Dictionary
		var unlocked := (
			slot_index
			< unlocked_slots
		)
		var running := (
			unlocked
			and bool(
				slot.get(
					"running",
					false
				)
			)
		)

		if bool(
			view.get(
				"running",
				false
			)
		) != running:
			call_deferred(
				"_open_crystallization"
			)
			return

		var status := view.get(
			"status"
		) as Label
		var stage_label := view.get(
			"stage"
		) as Label
		var timer := view.get(
			"timer"
		) as Label
		var last_result := view.get(
			"last_result"
		) as Label

		if status != null:
			status.text = _crystal_slot_status(
				running,
				unlocked
			)
		if stage_label != null:
			stage_label.text = (
				"Giai đoạn %s"
				% _crystal_stage_name(
					int(
						slot.get(
							"stage",
							1
						)
					)
				)
				if running
				else (
					"Mở ở giai đoạn %s"
					% _crystal_stage_name(
						slot_index + 1
					)
					if not unlocked
					else "Giai đoạn —"
				)
			)
		if timer != null:
			timer.text = (
				_format_crystal_time(
					int(
						slot.get(
							"remaining_seconds",
							0
						)
					)
				)
				if running
				else "—"
			)
		if last_result != null:
			last_result.text = (
				_crystal_last_result_text(
					slot
				)
				if unlocked
				else ""
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
		4:
			return "IV"
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
	if _hud._chest_animating:
		return
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
	_hub.pet_image_path = str((_data.get("current_visual", {}) as Dictionary).get("image_path", ""))
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
		true,
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


func _reward(match_id: String) -> void:
	var result := _game.claim_caro_win_reward(match_id)
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
		),
		bool(
			result.get(
				"rewarded",
				false
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
		true
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
		true,
		stage_index
	)

func _open_evolution() -> void:
	_open_pet_info_tab(
		&"evolution"
	)


func _populate_pet_evolution_tab() -> void:
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

	if stage_index >= StageLifecycle.FINAL_STAGE:
		_add_info_row(
			"Giai đoạn",
			PetHomeTheme.stage_label(
				stage_index
			)
		)
		_add_info_row(
			"Trạng thái",
			"Đã đạt hình thái cuối"
		)
		_add_info_row(
			"Tiếp theo",
			"Xem thành tích đời thú cưng → chọn di sản → đời sau"
		)
		_section_button(
			"XEM THÀNH TÍCH ĐỜI THÚ CƯNG",
			_open_current_final_record
		)
		_section_button(
			"CHỌN DI SẢN",
			_open_legacy_inheritance
		)
		return

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
		"Thời hạn",
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

	if can_evolve:
		_add_info_row(
			"Trạng thái",
			"SẴN SÀNG TIẾN HÓA"
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
			"Thiếu trưởng thành",
			_format_stage_time(
				growth_remaining
			)
		)


func _open_legacy_inheritance() -> void:
	_prepare_section(
		"Kế thừa đời sau"
	)
	_add_info_row(
		"Quy tắc",
		(
			"Chọn đúng 1 kỹ năng đang có để giữ cho đời sau. "
			+ "Toàn bộ vật phẩm trong Hòm vật phẩm sẽ tự động chuyển sang đời sau."
		)
	)

	var state := _game.snapshot()
	var skills_value: Variant = state.get(
		"skills",
		[]
	)
	var selectable := 0

	if typeof(skills_value) == TYPE_ARRAY:
		for raw in skills_value as Array:
			if typeof(raw) != TYPE_DICTIONARY:
				continue

			var skill := raw as Dictionary
			var skill_id := String(
				skill.get(
					"skill_id",
					""
				)
			)
			var display_name := String(
				skill.get(
					"display_name",
					PetSkillCatalog.display_name(
						StringName(skill_id)
					)
				)
			)

			if (
				skill_id.is_empty()
				or not PetSkillCatalog.is_valid(
					StringName(skill_id)
				)
			):
				continue

			selectable += 1
			_add_info_row(
				"Kỹ năng",
				_legacy_skill_detail(
					skill,
					state
				)
			)
			_section_button(
				"GIỮ • " + display_name,
				Callable(
					self,
					"_open_legacy_confirmation"
				).bind(
					skill_id
				)
			)

	if selectable == 0:
		_add_info_row(
			"Kỹ năng",
			"Thú cưng hiện tại không có kỹ năng hợp lệ để kế thừa."
		)

	_section_overlay.visible = true


func _open_legacy_confirmation(
	skill_id: String
) -> void:
	if not _owns_skill(
		skill_id
	):
		_hud.show_message(
			"Kỹ năng kế thừa không còn hợp lệ."
		)
		return

	var skill := _legacy_skill_data(
		skill_id
	)

	if skill.is_empty():
		_hud.show_message(
			"Không đọc được thông tin kỹ năng kế thừa."
		)
		return

	var state := _game.snapshot()
	var inventory := _game.inventory()

	_prepare_section(
		"Xác nhận kế thừa"
	)
	_add_info_row(
		"Kỹ năng",
		_legacy_skill_detail(
			skill,
			state
		)
	)
	_add_info_row(
		"Rương đồ",
		_legacy_inventory_summary(
			inventory
		)
	)
	_add_info_row(
		"Đời cũ",
		"Sẽ kết thúc sau khi xác nhận."
	)
	_add_info_row(
		"Đời mới",
		(
			"Kỹ năng đã chọn chiếm Ô 1; các ô còn lại tiếp tục ngẫu nhiên theo giai đoạn. "
			+ "Toàn bộ vật phẩm hiện có được chuyển nguyên trạng."
		)
	)
	_section_button(
		"XÁC NHẬN & BẮT ĐẦU ĐỜI SAU",
		Callable(
			self,
			"_start_next_generation"
		).bind(
			skill_id
		)
	)
	_section_button(
		"CHỌN LẠI KỸ NĂNG",
		_open_legacy_inheritance
	)
	_section_overlay.visible = true


func _start_next_generation(
	skill_id: String
) -> void:
	var state := _game.snapshot()

	if not bool(
		state.get(
			"final_form",
			false
		)
	):
		_hud.show_message(
			"Thú cưng chưa đạt hình thái cuối."
		)
		return

	if not _owns_skill(
		skill_id
	):
		_hud.show_message(
			"Kỹ năng kế thừa không còn hợp lệ."
		)
		return

	var identity := _data.get(
		"_identity_object"
	) as PetIdentity

	if identity == null:
		_hud.show_message(
			"Không đọc được thú cưng hiện tại."
		)
		return

	var inventory := _game.inventory()

	if not _game.save():
		_hud.show_message(
			"Không lưu được đời hiện tại."
		)
		return

	var final_record_result := (
		_final_record_service.ensure_current_record()
	)
	if not bool(
		final_record_result.get(
			"ok",
			false
		)
	):
		_hud.show_message(
			"Không lưu được thành tích đời thú cưng: "
			+ String(
				final_record_result.get(
					"error",
					"lỗi không xác định"
				)
			)
		)
		return

	var prepared := LegacyInheritanceService.new().prepare(
		identity,
		inventory,
		StringName(skill_id)
	)

	if not bool(
		prepared.get(
			"ok",
			false
		)
	):
		_hud.show_message(
			String(
				prepared.get(
					"error",
					"Không chuẩn bị được kế thừa."
				)
			)
		)
		return

	_suppress_exit_save = true

	var egg_deleted := SaveService.new().delete_save()
	var hatch_deleted := HatchSaveService.new().delete_save()

	SaveManager.delete_meta()
	var meta_deleted := not SaveManager.has_meta_save()

	var evolution_deleted := (
		EvolutionSaveService.new().delete_data()
	)

	if (
		not egg_deleted
		or not hatch_deleted
		or not meta_deleted
		or not evolution_deleted
	):
		_suppress_exit_save = false
		_game.save()
		_hud.show_message(
			"Chưa reset được đời cũ. Hãy thử lại."
		)
		return

	var error := get_tree().change_scene_to_file(
		"res://scenes/main.tscn"
	)

	if error != OK:
		_suppress_exit_save = false
		_hud.show_message(
			"Không mở được đời mới."
		)


func _legacy_skill_data(
	skill_id: String
) -> Dictionary:
	var skills_value: Variant = _game.snapshot().get(
		"skills",
		[]
	)

	if typeof(skills_value) != TYPE_ARRAY:
		return {}

	for raw in skills_value as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var skill := raw as Dictionary

		if String(
			skill.get(
				"skill_id",
				""
			)
		) == skill_id:
			return skill.duplicate(true)

	return {}


func _legacy_skill_detail(
	skill: Dictionary,
	state: Dictionary
) -> String:
	var skill_id := String(
		skill.get(
			"skill_id",
			""
		)
	)
	var name := String(
		skill.get(
			"display_name",
			PetSkillCatalog.display_name(
				StringName(skill_id)
			)
		)
	)
	var description := String(
		skill.get(
			"description",
			PetSkillCatalog.description(
				StringName(skill_id)
			)
		)
	).strip_edges()
	var detail := name

	if not description.is_empty():
		detail += "\n" + description

	if skill_id == "night_eater":
		var start_hour := clampi(
			int(
				state.get(
					"skill_night_window_start_hour",
					0
				)
			),
			0,
			23
		)
		var end_hour := posmod(
			start_hour + 6,
			24
		)
		detail += (
			"\nKhung giờ của thú cưng: %02d:00–%02d:00."
			% [
				start_hour,
				end_hour,
			]
		)
	elif skill_id == "picky_eater":
		var preference := String(
			state.get(
				"skill_food_preference",
				""
			)
		)
		var food_names := {
			"fish": "Cá",
			"meat": "Thịt",
			"fruit": "Trái cây",
			"milk_nectar": "Sữa / mật",
		}

		if not preference.is_empty():
			detail += (
				"\nNhóm thức ăn ưa thích: %s."
				% String(
					food_names.get(
						preference,
						preference
					)
				)
			)

	return detail


func _legacy_inventory_summary(
	items: Array
) -> String:
	if items.is_empty():
		return (
			"Rương đang trống. Không có vật phẩm để chuyển."
		)

	return (
		"Chuyển tự động toàn bộ %d vật phẩm hiện có sang đời sau; không cần chọn từng món."
		% items.size()
	)


func _add_skill_rows(
	state: Dictionary
) -> void:
	var skills_value: Variant = state.get(
		"skills",
		[]
	)

	if typeof(skills_value) != TYPE_ARRAY:
		return

	for raw in skills_value as Array:
		if typeof(raw) != TYPE_DICTIONARY:
			continue

		var skill := raw as Dictionary
		var slot := int(
			skill.get(
				"slot",
				0
			)
		)
		var skill_id := String(
			skill.get(
				"skill_id",
				""
			)
		)
		var name := String(
			skill.get(
				"display_name",
				PetSkillCatalog.display_name(
					StringName(skill_id)
				)
			)
		)
		var description := String(
			skill.get(
				"description",
				PetSkillCatalog.description(
					StringName(skill_id)
				)
			)
		).strip_edges()
		var source := String(
			skill.get(
				"source",
				""
			)
		)
		var suffix := ""

		if source == "legacy":
			suffix = " • Kế thừa"
		elif source == "egg_stage4":
			suffix = " • Trứng giai đoạn 4"

		var detail := name + suffix

		if not description.is_empty():
			detail += "\n" + description

		if skill_id == "night_eater":
			var start_hour := clampi(
				int(
					state.get(
						"skill_night_window_start_hour",
						0
					)
				),
				0,
				23
			)
			var end_hour := posmod(
				start_hour + 6,
				24
			)
			detail += (
				"\nKhung giờ của thú cưng: %02d:00–%02d:00."
				% [
					start_hour,
					end_hour,
				]
			)
		elif skill_id == "picky_eater":
			var preference := String(
				state.get(
					"skill_food_preference",
					""
				)
			)
			var food_names := {
				"fish": "Cá",
				"meat": "Thịt",
				"fruit": "Trái cây",
				"milk_nectar": "Sữa / mật",
			}
			if not preference.is_empty():
				detail += (
					"\nNhóm thức ăn ưa thích: %s."
					% String(
						food_names.get(
							preference,
							preference
						)
					)
				)

		_add_info_row(
			"Kỹ năng %d" % slot,
			detail
		)


func _owns_skill(
	skill_id: String
) -> bool:
	if skill_id.is_empty():
		return false

	var skills_value: Variant = _game.snapshot().get(
		"skills",
		[]
	)

	if typeof(skills_value) != TYPE_ARRAY:
		return false

	for raw in skills_value as Array:
		if (
			typeof(raw) == TYPE_DICTIONARY
			and String(
				(raw as Dictionary).get(
					"skill_id",
					""
				)
			) == skill_id
		):
			return true

	return false


func _legacy_item_label(
	item: Dictionary
) -> String:
	if item.is_empty():
		return "Không có vật phẩm"

	var display_name := ViDisplay.item_name(
		String(
			item.get(
				"display_name",
				item.get(
					"base_display_name",
					"Vật phẩm"
				)
			)
		)
	)
	var rarity := String(
		item.get(
			"rarity",
			""
		)
	).strip_edges()

	if display_name.is_empty():
		display_name = "Vật phẩm"

	if rarity.is_empty():
		return display_name

	return "%s • %s" % [
		display_name,
		ViDisplay.rarity_label(
			rarity
		),
	]


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


func _maybe_open_final_record() -> void:
	if _hud == null:
		return

	var state := _game.snapshot()
	if not bool(
		state.get(
			"final_form",
			false
		)
	):
		return

	var result := (
		_final_record_service.ensure_current_record()
	)
	if not bool(
		result.get(
			"ok",
			false
		)
	):
		return

	var record_value: Variant = result.get(
		"record",
		{}
	)
	if typeof(record_value) != TYPE_DICTIONARY:
		return

	var record := record_value as Dictionary
	if bool(
		record.get(
			"presented",
			false
		)
	):
		return

	await _show_final_record(
		record,
		true
	)


func _open_current_final_record() -> void:
	var result := (
		_final_record_service.ensure_current_record()
	)
	if not bool(
		result.get(
			"ok",
			false
		)
	):
		_hud.show_message(
			String(
				result.get(
					"error",
					"Chưa tạo được thành tích đời thú cưng."
				)
			)
		)
		return

	var record_value: Variant = result.get(
		"record",
		{}
	)
	if typeof(record_value) != TYPE_DICTIONARY:
		return

	await _show_final_record(
		record_value as Dictionary,
		false
	)


func _open_final_record_by_id(
	record_id: String
) -> void:
	var record := _final_record_service.get_record(
		record_id
	)

	if record.is_empty():
		_hud.show_message(
			"Không tìm thấy thành tích cuối đời."
		)
		return

	await _show_final_record(
		record,
		false
	)


func _show_final_record(
	record: Dictionary,
	mark_as_presented: bool
) -> void:
	_prepare_section(
		"Thành tích đời thú cưng",
		&"final_record"
	)

	_add_info_row(
		"Thú cưng",
		String(
			record.get(
				"display_name",
				"Thú cưng"
			)
		)
	)
	_add_info_row(
		"Đời",
		"#%d"
		% (
			int(
				record.get(
					"generation",
					0
				)
			)
			+ 1
		)
	)

	var loading := Label.new()
	loading.text = "Đang dựng ảnh kỷ niệm 4 giai đoạn..."
	loading.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	loading.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	_section_body.add_child(
		loading
	)
	_section_overlay.visible = true

	var preview := await _final_record_renderer.render_preview(
		record,
		self,
		Vector2i(
			960,
			540
		)
	)

	if _active_section != &"final_record":
		return

	if is_instance_valid(loading):
		loading.queue_free()

	if preview == null or preview.is_empty():
		_add_info_row(
			"Ảnh",
			"Không dựng được ảnh xem trước."
		)
	else:
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(
			0,
			168
		)
		texture_rect.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)
		texture_rect.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)
		texture_rect.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)
		texture_rect.texture = (
			ImageTexture.create_from_image(
				preview
			)
		)
		_section_body.add_child(
			texture_rect
		)

	var record_id := String(
		record.get(
			"record_id",
			""
		)
	)
	_section_button(
		"LƯU ẢNH 16:9",
		Callable(
			self,
			"_save_final_record"
		).bind(
			record_id
		)
	)
	_section_button(
		"BẢNG THÀNH TÍCH",
		_open_achievements
	)

	if bool(
		_game.snapshot().get(
			"final_form",
			false
		)
	):
		_section_button(
			"CHỌN DI SẢN",
			_open_legacy_inheritance
		)

	if (
		mark_as_presented
		and not record_id.is_empty()
	):
		_final_record_service.mark_presented(
			record_id
		)


func _save_final_record(
	record_id: String
) -> void:
	var record := _final_record_service.get_record(
		record_id
	)

	if record.is_empty():
		_hud.show_message(
			"Không tìm thấy thành tích cuối đời."
		)
		return

	_hud.show_message(
		"Đang lưu ảnh 16:9..."
	)
	var result := await _final_record_renderer.export_png(
		record,
		self
	)

	if not bool(
		result.get(
			"ok",
			false
		)
	):
		_hud.show_message(
			String(
				result.get(
					"error",
					"Không lưu được ảnh."
				)
			)
		)
		return

	var gallery_path := String(
		result.get(
			"gallery_path",
			""
		)
	)

	_hud.show_message(
		(
			"Đã lưu vào thư mục Pictures/PetVerse."
			if not gallery_path.is_empty()
			else "Đã lưu thành tích cuối đời trong dữ liệu PetVerse."
		)
	)


func _open_achievements() -> void:
	_prepare_section(
		"Bảng thành tích",
		&"achievements"
	)
	var entries := (
		_final_record_service.list_collection()
	)

	_add_info_row(
		"Đã mở",
		str(entries.size())
	)

	if entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = (
			"Chưa có thú cưng nào hoàn thành vòng đời."
		)
		empty_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		empty_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		empty_label.add_theme_color_override(
			"font_color",
			_theme.get(
				"muted",
				Color.WHITE
			)
		)
		_section_body.add_child(
			empty_label
		)
	else:
		for entry in entries:
			_add_achievement_tile(
				entry
			)

	_section_overlay.visible = true


func _add_achievement_tile(
	entry: Dictionary
) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 116
	panel.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	var panel_color: Color = _theme.get(
		"panel",
		Color("#171229")
	)
	panel_color = panel_color.lightened(
		0.04
	)
	panel_color.a = 0.94
	var accent: Color = _theme.get(
		"accent",
		Color.WHITE
	)
	var border := accent
	border.a = 0.34
	panel.add_theme_stylebox_override(
		"panel",
		PetHomeThemeScript.panel_style(
			panel_color,
			border,
			14
		)
	)
	_section_body.add_child(
		panel
	)

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
	panel.add_child(
		margin
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(
		row
	)

	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(
		62,
		96
	)
	thumb.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	thumb.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	thumb.texture = _achievement_thumbnail(
		String(
			entry.get(
				"thumbnail_path",
				""
			)
		)
	)
	row.add_child(
		thumb
	)

	var text_root := VBoxContainer.new()
	text_root.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	row.add_child(
		text_root
	)

	var name_label := Label.new()
	name_label.text = String(
		entry.get(
			"display_name",
			"Thú cưng"
		)
	)
	name_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	name_label.add_theme_color_override(
		"font_color",
		_theme.get(
			"text",
			Color.WHITE
		)
	)
	text_root.add_child(
		name_label
	)

	var count_label := Label.new()
	count_label.text = (
		"Hoàn thành ×%d"
		% int(
			entry.get(
				"completion_count",
				1
			)
		)
	)
	count_label.add_theme_color_override(
		"font_color",
		_theme.get(
			"muted",
			Color.WHITE
		)
	)
	text_root.add_child(
		count_label
	)

	var record_id := String(
		entry.get(
			"latest_record_id",
			""
		)
	)
	if not record_id.is_empty():
		var view := Button.new()
		view.text = "XEM"
		view.custom_minimum_size.y = 34
		view.pressed.connect(
			Callable(
				self,
				"_open_final_record_by_id"
			).bind(
				record_id
			)
		)
		text_root.add_child(
			view
		)


func _achievement_thumbnail(
	path: String
) -> Texture2D:
	if path.strip_edges().is_empty():
		return null

	var image := Image.load_from_file(
		path
	)

	if image == null:
		return null

	image.resize(
		96,
		144,
		Image.INTERPOLATE_LANCZOS
	)
	return ImageTexture.create_from_image(
		image
	)


func _open_settings() -> void:
	_prepare_section("Cài đặt")
	_audio_toggle("Âm thanh", "sound", true)
	_audio_toggle("Hiệu ứng bấm / mở / đóng", "effects", true)
	_audio_volume("Âm lượng hiệu ứng", "effects_volume", 0.65)
	_audio_toggle("Nhạc nền", "music", true)
	_audio_volume("Âm lượng nhạc", "music_volume", 0.45)
	_section_button("Kết nối 2 người • Wi-Fi / Bluetooth", _open_local_connection)
	_section_button("Dữ liệu • Sao lưu / Khôi phục", _open_backup)
	_section_button("Lưu tiến trình", func(): _hud.show_message("Đã lưu" if _game.save() else "Chưa lưu được. Hãy thử lại."))
	_section_overlay.visible = true


func _audio_toggle(label: String, key: String, fallback: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label
	toggle.button_pressed = bool(AudioService.settings.get(key, fallback))
	toggle.toggled.connect(func(enabled: bool) -> void:
		if not AudioService.set_setting(key, enabled):
			_hud.show_message("Chưa lưu được cài đặt âm thanh.")
	)
	_section_body.add_child(toggle)

func _audio_volume(label: String, key: String, fallback: float) -> void:
	var title := Label.new()
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(AudioService.settings.get(key, fallback)) * 100
	slider.custom_minimum_size.y = 32
	title.text = "%s • %d%%" % [label, int(slider.value)]
	slider.value_changed.connect(func(value: float) -> void:
		title.text = "%s • %d%%" % [label, int(value)]
		if not AudioService.set_setting(key, value / 100.0):
			_hud.show_message("Chưa lưu được cài đặt âm thanh.")
	)
	_section_body.add_child(title)
	_section_body.add_child(slider)


func _open_local_connection() -> void:
	_prepare_section("Kết nối 2 người")
	var panel := LocalConnectionPanel.new()
	_section_body.add_child(panel)
	_section_overlay.visible = true


func _open_backup() -> void:
	_prepare_section("Sao lưu / Khôi phục")
	var panel := BackupPanel.new()
	panel.save_callback = _game.save
	panel.restore_started.connect(func():
		_suppress_exit_save = true
		_paused = true
	)
	panel.restore_failed.connect(func():
		_suppress_exit_save = not BackupService.recovery_ok
		_paused = not BackupService.recovery_ok
	)
	_section_body.add_child(panel)
	_section_overlay.visible = true
