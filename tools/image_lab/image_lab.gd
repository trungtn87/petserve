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
var generate := Button.new()
var controls: VBoxContainer
var busy := false
var last_path := ""

func _ready() -> void:
	var config := PetRenderConfig.load_default()
	renderer = ProxyPetRenderer.new(config)
	add_child(renderer)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	scroll.add_child(controls)
	_label("AI IMAGE LAB • PetVerse", controls)
	_label("Tạo lần lượt Stage 1 → Final. Gene dùng ở stage trước sẽ biểu hiện khi tiến hóa. Mỗi lần bấm tạo sẽ gọi AI thật.", controls)
	for index in range(ELEMENTS.size()):
		element.add_item(["Kim", "Mộc", "Thủy", "Hỏa", "Thổ", "Quang", "Ám"][index])
	element.select(6)
	controls.add_child(element)
	_label("Seed (giữ nguyên để so sánh Gene)", controls)
	seed_input.min_value = 1
	seed_input.max_value = 2147483646
	seed_input.value = int(Time.get_unix_time_from_system()) % 2147483646 + 1
	controls.add_child(seed_input)
	_button("Bắt đầu lượt test / đổi hệ và seed", _reset, controls)
	_button("Đời mới: random dáng bẩm sinh", _new_lineage, controls)
	_label("Ảnh muốn tạo", controls)
	for stage in range(1, 6):
		target.add_item("Stage %d" % stage if stage < 5 else "Final (sau Stage 4)")
	controls.add_child(target)
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
	_label("Ảnh trước tiến hóa", controls)
	_image_box(source)
	_label("Ảnh kết quả", controls)
	_image_box(output)
	_button("Mở thư mục ảnh và prompt", func(): OS.shell_open(ProjectSettings.globalize_path("user://pet_renders")), controls)
	_reset()
	if config == null or not config.is_configured():
		status.text = "Chưa cấu hình proxy tạo ảnh trong data/evolution/render/proxy_dev.json."

func _label(text: String, parent: Node) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func _button(text: String, action: Callable, parent: Node) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _image_box(rect: TextureRect) -> void:
	rect.custom_minimum_size = Vector2(0, 420)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	controls.add_child(rect)

func _new_lineage() -> void:
	if busy:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var next_seed := rng.randi_range(1, 2147483646)
	if next_seed == int(seed_input.value):
		next_seed = next_seed % 2147483646 + 1
	seed_input.value = next_seed

func _reset() -> void:
	if busy:
		return
	session.reset(StringName(ELEMENTS[element.selected]), int(seed_input.value))
	target.select(0)
	output.texture = null
	last_path = ""
	status.text = "Sẵn sàng. Dữ liệu test độc lập với pet đang chơi."
	_refresh()

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
	info.text = "Stage 1: ảnh mới nở, chưa áp dụng Gene." if stage == 1 else "Chọn Gene dùng ở Stage %d → tạo ảnh %s. Có thể thêm nhiều Gene, độ hiếm và số lượng; bỏ trống để tiến hóa tự nhiên." % [stage - 1, target.get_item_text(target.selected)]
	source.texture = null
	output.texture = null
	if session.snapshots.has(stage - 1):
		source.texture = _texture(session.snapshots[stage - 1].current_visual.image_path)
	if session.snapshots.has(stage):
		output.texture = _texture(session.snapshots[stage].current_visual.image_path)
	for index in range(1, 5):
		target.set_item_disabled(index, not session.snapshots.has(index))

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
	report["result"] = {"model": String(result.model_id), "metadata": result.metadata, "image_path": result.image_path}
	report["gene_state"] = session.pending_genes.to_dict()
	var saved := AtomicJson.write(result.image_path.get_basename() + ".json", report)
	status.text = "Đã tạo • %s • %.1f giây\n%s%s" % [result.model_id, (Time.get_ticks_msec() - started) / 1000.0, ProjectSettings.globalize_path(last_path), "" if saved else "\nKhông lưu được báo cáo prompt."]
	# A new preview generates a fresh output key, preventing cached-image false comparisons.
	request = null
	generate.disabled = true
	for index in range(1, 5):
		target.set_item_disabled(index, not session.snapshots.has(index))

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
