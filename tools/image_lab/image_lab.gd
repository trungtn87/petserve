extends Control

const Session = preload("res://tools/image_lab/image_lab_session.gd")
const ELEMENTS := ["metal", "wood", "water", "fire", "earth", "light", "dark"]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
var session := Session.new()
var renderer: ProxyPetRenderer
var request: PetRenderRequest
var element := OptionButton.new()
var seed_input := SpinBox.new()
var target := OptionButton.new()
var rows := VBoxContainer.new()
var prompt := TextEdit.new()
var status := Label.new()
var info := Label.new()
var source := TextureRect.new()
var output := TextureRect.new()
var source_label: Label
var output_label: Label
var generate := Button.new()
var controls: VBoxContainer
var render_mode := OptionButton.new()
var preset_active := false
var busy := false
var last_path := ""

func _ready() -> void:
	var config := PetRenderConfig.load_default()
	renderer = ProxyPetRenderer.new(config)
	add_child(renderer)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 8)
	margin.add_child(controls)
	_label("AI IMAGE LAB • PetVerse", controls)
	_label("Flow mặc định: random đúng PetHome (loài + hệ từ run seed), rồi tạo Stage 1 → 4. Stage 2–4 nhận bộ Gene random hợp lệ nhưng prompt/render vẫn dùng nguyên production pipeline.", controls)
	for index in range(ELEMENTS.size()):
		element.add_item(["Kim", "Mộc", "Thủy", "Hỏa", "Thổ", "Quang", "Ám"][index])
	element.select(6)
	controls.add_child(element)
	_label("Seed (giữ nguyên để so sánh Gene)", controls)
	seed_input.min_value = 1
	seed_input.max_value = 2147483646
	seed_input.value = int(Time.get_unix_time_from_system()) % 2147483646 + 1
	controls.add_child(seed_input)
	_button("Random pet + hệ mới", _new_lineage, controls)
	_button("Auto Stage 1 → 4 • random Gene", _run_random_four_stages, controls)
	_button("Manual hệ + seed hiện tại", _reset, controls)
	_label("Ảnh muốn tạo", controls)
	for stage in range(1, 6):
		target.add_item("Stage %d" % stage if stage < 5 else "Final (sau Stage 4)")
	controls.add_child(target)
	_label("Chế độ thử ảnh", controls)
	render_mode.add_item("Theo game: ảnh tham chiếu từ Stage 3")
	render_mode.add_item("Thử dựng ảnh mới: cùng hình thái đích")
	controls.add_child(render_mode)
	render_mode.item_selected.connect(func(_index: int): _invalidate())
	_button("Nạp mẫu Mộc vừa test (seed + Gene)", _load_wood_preset, controls)
	target.item_selected.connect(func(_index: int): _refresh())
	element.item_selected.connect(func(_index: int): _reset())
	seed_input.value_changed.connect(func(_value: float): _reset())
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(info)
	controls.add_child(rows)
	_button("+ Thêm Gene", _add_gene, controls)
	_button("Xem câu lệnh của game", _prepare, controls)
	prompt.custom_minimum_size.y = 210
	prompt.editable = false
	prompt.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	controls.add_child(prompt)
	_button("Sao chép câu lệnh", func(): DisplayServer.clipboard_set(prompt.text), controls)
	generate.text = "Tạo ảnh AI"
	generate.pressed.connect(_render)
	controls.add_child(generate)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status)
	source_label = _label("Ảnh trước tiến hóa", controls)
	_image_box(source)
	output_label = _label("Ảnh kết quả", controls)
	_image_box(output)
	_button("Mở thư mục ảnh và prompt", func(): OS.shell_open(ProjectSettings.globalize_path("user://pet_renders")), controls)
	_new_lineage()
	if config == null or not config.is_configured():
		status.text = "Chưa cấu hình proxy tạo ảnh trong data/evolution/render/proxy_dev.json."

func _label(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, action: Callable, parent: Node) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _image_box(rect: TextureRect) -> void:
	rect.custom_minimum_size = Vector2(0, 340)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	controls.add_child(rect)

func _new_lineage() -> void:
	if busy:
		return
	preset_active = false
	var next_seed := RandomService.new().create_run_seed()
	seed_input.set_value_no_signal(next_seed)
	var randomized := session.reset_random(next_seed)
	if not randomized.get("ok", false):
		status.text = String(randomized.get("error", "Không random được pet."))
		return
	_sync_element_from_identity()
	target.select(0)
	output.texture = null
	last_path = ""
	_refresh()
	status.text = "Đời mới • %s • hệ %s • seed %d" % [
		String(session.identity.species()).to_upper(),
		PetElementCatalog.display_name(session.identity.element()),
		next_seed,
	]

func _reset() -> void:
	if busy:
		return
	var seed_value := int(seed_input.value)
	var species := PetSpeciesCatalog.pick_for_seed(seed_value)
	session.reset(
		StringName(ELEMENTS[element.selected]),
		seed_value,
		species
	)
	target.select(0)
	output.texture = null
	last_path = ""
	status.text = "Manual • %s • hệ %s • seed %d" % [
		String(session.identity.species()).to_upper(),
		PetElementCatalog.display_name(session.identity.element()),
		seed_value,
	]
	_refresh()


func _sync_element_from_identity() -> void:
	if session.identity == null:
		return
	var index := ELEMENTS.find(String(session.identity.element()))
	if index >= 0:
		element.select(index)

func _invalidate() -> void:
	request = null
	prompt.text = ""
	generate.disabled = true

func _refresh() -> void:
	_invalidate()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var stage := target.selected + 1
	var stage_note := "Stage 1: ảnh mới nở, chưa áp dụng Gene." if stage == 1 else "Chọn Gene dùng ở Stage %d → tạo ảnh %s. Có thể thêm nhiều Gene, độ hiếm và số lượng; bỏ trống để tiến hóa tự nhiên." % [stage - 1, target.get_item_text(target.selected)]
	var identity_note := ""
	if session.identity != null:
		identity_note = "Pet %s • hệ %s • seed %d\n" % [
			String(session.identity.species()).to_upper(),
			PetElementCatalog.display_name(session.identity.element()),
			session.identity.lineage_seed(),
		]
	info.text = identity_note + stage_note
	source.texture = null
	output.texture = null
	if session.snapshots.has(stage - 1):
		source.texture = _texture(session.snapshots[stage - 1].current_visual.image_path)
	if session.snapshots.has(stage):
		output.texture = _texture(session.snapshots[stage].current_visual.image_path)
	var show_source := source.texture != null
	source.visible = show_source
	if source_label != null:
		source_label.visible = show_source
	for index in range(1, 5):
		target.set_item_disabled(index, not session.snapshots.has(index))

	if preset_active and element.selected == 1 and int(seed_input.value) == 1420288088:
		_fill_wood_preset()

func _add_gene() -> void:
	if busy or target.selected == 0:
		return
	var allowed: Array[GeneDefinition] = session.available_genes(target.selected)
	if allowed.is_empty():
		return
	_invalidate()
	var row := VBoxContainer.new()
	var choice := OptionButton.new()
	for gene in allowed:
		choice.add_item(gene.display_name())
		choice.set_item_metadata(choice.item_count - 1, String(gene.id()))
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(choice)
	var detail := HBoxContainer.new()
	row.add_child(detail)
	var rarity := OptionButton.new()
	for value in RARITIES:
		rarity.add_item("%s (+%d)" % [ViDisplay.rarity_label(value), int(ItemGenerator.new().gene_score_for_rarity(value))])
	detail.add_child(rarity)
	var count := SpinBox.new()
	count.min_value = 1
	count.max_value = 100
	count.value = 1
	detail.add_child(count)
	_button("Xóa", func(): rows.remove_child(row); row.queue_free(); _invalidate(), detail)
	choice.item_selected.connect(func(_index: int): _invalidate())
	rarity.item_selected.connect(func(_index: int): _invalidate())
	count.value_changed.connect(func(_value: float): _invalidate())
	row.set_meta("choice", choice)
	row.set_meta("rarity", rarity)
	row.set_meta("count", count)
	rows.add_child(row)

func _prepare() -> void:
	if busy:
		return
	var selections: Array[Dictionary] = []
	for row in rows.get_children():
		var choice: OptionButton = row.get_meta("choice")
		var rarity: OptionButton = row.get_meta("rarity")
		var count: SpinBox = row.get_meta("count")
		selections.append({"gene_id": choice.get_item_metadata(choice.selected), "rarity": RARITIES[rarity.selected], "count": int(count.value)})
	var plan: Dictionary = session.prepare(target.selected + 1, selections)
	if not plan.get("ok", false):
		_invalidate()
		status.text = str(plan.get("error", "Không tạo được câu lệnh."))
		return
	request = plan.request
	if render_mode.selected == 1 and target.selected >= 2:
		request.mode = PetRenderRequest.RenderMode.EVOLUTION_TEXT_TO_IMAGE
		request.source_image_path = ""
		request.target_region = &""
		request.edit_strength = 0.0
	prompt.text = renderer._compose_prompt(request)
	generate.disabled = false
	status.text = "Sẵn sàng tạo Stage %d • %s • seed %d" % [target.selected + 1, "Tạo mới" if request.mode != PetRenderRequest.RenderMode.EVOLUTION_IMAGE_EDIT else "Sửa ảnh tham chiếu", request.seed]

func _render() -> void:
	if busy or request == null:
		return
	busy = true
	_set_disabled(controls, true)
	status.text = "AI đang tạo ảnh…"
	var started := Time.get_ticks_msec()
	var result: PetRenderResult = await renderer.render(request)
	busy = false
	_set_disabled(controls, false)
	if not result.success:
		status.text = "%s: %s" % [result.error_code, result.error_message]
		return
	if not session.accept(result):
		status.text = "Có ảnh nhưng game từ chối kết quả tiến hóa; chưa chuyển stage."
		return
	output.texture = _texture(result.image_path)
	last_path = result.image_path
	var report := request.to_debug_dict()
	report["wire_prompt"] = prompt.text
	report["experiment"] = "fresh_target_form" if render_mode.selected == 1 else "production_reference"
	report["morphology"] = preload("res://features/evolution/visual/lineage_morphology.gd").new().resolve(session.identity, target.selected + 1, session.pending_genes.gene_scores_snapshot())
	report["result"] = {"model": String(result.model_id), "metadata": result.metadata, "image_path": result.image_path}
	report["gene_state"] = session.pending_genes.to_dict()
	var saved := AtomicJson.write(result.image_path.get_basename() + ".json", report)
	status.text = "Đã tạo • %s • %.1f giây\n%s%s" % [result.model_id, (Time.get_ticks_msec() - started) / 1000.0, ProjectSettings.globalize_path(last_path), "" if saved else "\nKhông lưu được báo cáo prompt."]
	# A new preview generates a fresh output key, preventing cached-image false comparisons.
	request = null
	generate.disabled = true
	for index in range(1, 5):
		target.set_item_disabled(index, not session.snapshots.has(index))

func _run_random_four_stages() -> void:
	if busy:
		return
	_new_lineage()
	if session.identity == null:
		return

	busy = true
	_set_disabled(controls, true)
	var run_lines: Array[String] = []
	run_lines.append(
		"%s • hệ %s • seed %d" % [
			String(session.identity.species()).to_upper(),
			PetElementCatalog.display_name(session.identity.element()),
			session.identity.lineage_seed(),
		]
	)
	var failed := ""

	for stage in range(1, 5):
		var selections: Array[Dictionary] = []
		if stage > 1:
			selections = session.random_gene_selections(stage - 1)
			if selections.is_empty():
				failed = "Stage %d không có Gene hợp lệ để random." % stage
				break

		var plan: Dictionary = session.prepare(stage, selections)
		if not plan.get("ok", false):
			failed = "Stage %d: %s" % [
				stage,
				String(plan.get("error", "Không tạo được request.")),
			]
			break

		request = plan.request
		prompt.text = renderer._compose_prompt(request)
		status.text = "Đang tạo Stage %d/4 • %s" % [
			stage,
			_selection_summary(selections),
		]
		var result: PetRenderResult = await renderer.render(request)
		if not result.success:
			failed = "Stage %d • %s: %s" % [
				stage,
				result.error_code,
				result.error_message,
			]
			break
		if not session.accept(result):
			failed = "Stage %d có ảnh nhưng production commit từ chối." % stage
			break

		output.texture = _texture(result.image_path)
		last_path = result.image_path
		_write_random_report(result, stage, selections)
		run_lines.append(
			"Stage %d: %s" % [
				stage,
				_selection_summary(selections),
			]
		)
		request = null
		await get_tree().process_frame

	busy = false
	_set_disabled(controls, false)
	request = null
	generate.disabled = true

	if not failed.is_empty():
		status.text = "Dừng auto run. %s\n%s" % [
			failed,
			"\n".join(run_lines),
		]
		return

	target.set_item_disabled(3, false)
	target.select(3)
	_refresh()
	status.text = "Hoàn tất random Stage 1 → 4 bằng production pipeline.\n%s" % "\n".join(run_lines)


func _selection_summary(selections: Array[Dictionary]) -> String:
	if selections.is_empty():
		return "base form"
	var parts: Array[String] = []
	for selection in selections:
		parts.append(
			"%s[%s]" % [
				String(selection.get("gene_id", "")),
				String(selection.get("rarity", "")),
			]
		)
	return ", ".join(parts)


func _write_random_report(
	result: PetRenderResult,
	stage: int,
	selections: Array[Dictionary]
) -> void:
	if request == null:
		return
	var report := request.to_debug_dict()
	report["wire_prompt"] = prompt.text
	report["experiment"] = "auto_random_pethome_4stage"
	report["identity"] = {
		"pet_id": String(session.identity.pet_id()),
		"species": String(session.identity.species()),
		"element": String(session.identity.element()),
		"lineage_seed": session.identity.lineage_seed(),
		"generation": session.identity.generation(),
	}
	report["random_gene_items"] = selections.duplicate(true)
	report["morphology"] = preload("res://features/evolution/visual/lineage_morphology.gd").new().resolve(
		session.identity,
		stage,
		session.pending_genes.gene_scores_snapshot()
	)
	report["result"] = {
		"model": String(result.model_id),
		"metadata": result.metadata,
		"image_path": result.image_path,
	}
	report["gene_state"] = session.pending_genes.to_dict()
	AtomicJson.write(result.image_path.get_basename() + ".json", report)


func _set_disabled(node: Node, value: bool) -> void:
	if node is BaseButton:
		(node as BaseButton).disabled = value
	if node is SpinBox:
		(node as SpinBox).editable = not value
	for child in node.get_children():
		_set_disabled(child, value)

func _texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null else null

func _load_wood_preset() -> void:
	if busy:
		return
	preset_active = true
	element.select(1)
	seed_input.set_value_no_signal(1420288088)
	_reset()
	status.text = "Đã nạp mẫu Mộc. Tạo từ Stage 1; Gene mẫu tự điền khi chọn stage tiếp theo."

func _fill_wood_preset() -> void:
	var stages := {
		2: [["aura_wood", "rare", 1], ["ears_softfan", "epic", 1]],
		3: [["eyes_moon", "uncommon", 1], ["mane_astral", "epic", 1], ["paws_luminous", "epic", 1]],
		4: [["aura_wood", "epic", 1], ["ears_rounded", "epic", 1], ["tail_fluffy", "legendary", 2], ["whiskers_starlight", "rare", 1]],
	}
	for values in stages.get(target.selected + 1, []):
		_add_gene()
		var row := rows.get_child(rows.get_child_count() - 1)
		var choice: OptionButton = row.get_meta("choice")
		for index in range(choice.item_count):
			if String(choice.get_item_metadata(index)) == String(values[0]):
				choice.select(index)
		(row.get_meta("rarity") as OptionButton).select(RARITIES.find(String(values[1])))
		(row.get_meta("count") as SpinBox).value = int(values[2])
