class_name JigsawActivityUI
extends Control

signal back_requested
signal match_finished(result: StringName)
var game_api: InfantGameFacade
var palette: Dictionary = {}
var current_image_path := ""
var _session := JigsawSession.new()
var _texture: Texture2D
var _paths: Array[String] = []
var _images: OptionButton
var _level: OptionButton
var _zoom: OptionButton
var _reference: Button
var _board: JigsawBoard
var _scroll: ScrollContainer
var _tray: HBoxContainer
var _progress: Label
var _message: Label
var _page_label: Label
var _previous: Button
var _next: Button
var _confirm: ConfirmationDialog
var _page := 0
var _selected := -1
var _dragging := false
var _ghost: JigsawPiece
var _announced := false
const PAGE_SIZE := 3

func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_button("‹", func() -> void: back_requested.emit()))
	var title := _label("GHÉP HÌNH PET", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Ván mới", _new_match))
	var options := HBoxContainer.new()
	root.add_child(options)
	_images = OptionButton.new()
	_images.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_images.custom_minimum_size.x = 100
	_images.clip_text = true
	options.add_child(_images)
	_level = OptionButton.new()
	for amount in JigsawSession.COUNTS:
		_level.add_item("%d mảnh" % amount)
	options.add_child(_level)
	_progress = _label("", 12)
	root.add_child(_progress)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 100
	_scroll.resized.connect(_resize_board)
	root.add_child(_scroll)
	_board = JigsawBoard.new()
	_board.drop_requested.connect(_place)
	_scroll.add_child(_board)
	var tools := HBoxContainer.new()
	root.add_child(tools)
	_reference = _button("Ảnh mẫu", func() -> void: pass)
	_reference.toggle_mode = true
	_reference.toggled.connect(func(value: bool) -> void: _board.show_reference = value; _board.queue_redraw())
	_reference.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(_reference)
	_zoom = OptionButton.new()
	for scale in 3:
		_zoom.add_item("Zoom ×%d" % (scale + 1))
	_zoom.item_selected.connect(func(_index: int) -> void: _resize_board())
	tools.add_child(_zoom)
	tools.add_child(_button("Bỏ chọn", func() -> void: _select(-1)))
	_tray = HBoxContainer.new()
	_tray.custom_minimum_size.y = 76
	root.add_child(_tray)
	var pages := HBoxContainer.new()
	root.add_child(pages)
	_previous = _button("‹", func() -> void: _page -= 1; _sync_tray())
	pages.add_child(_previous)
	_page_label = _label("", 11)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_page_label)
	_next = _button("›", func() -> void: _page += 1; _sync_tray())
	pages.add_child(_next)
	_message = _label("", 11)
	root.add_child(_message)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Chơi ván mới?"
	_confirm.dialog_text = "Ván dở sẽ được thay bằng ảnh và độ khó đã chọn."
	_confirm.ok_button_text = "Ván mới"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(_restart)
	add_child(_confirm)
	_ghost = JigsawPiece.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 50
	_ghost.size = Vector2(100, 100)
	_ghost.visible = false
	add_child(_ghost)

func open_activity() -> void:
	AudioService.play("open")
	visible = true
	_discover_images()
	if _session.image_path.is_empty():
		_session.restore(AtomicJson.read(JigsawSession.SAVE_PATH))
	if not _session.image_path.is_empty() and _load_texture(_session.image_path, _session.level):
		_level.select(_session.level)
		var selected_path := _paths.find(_session.image_path)
		if selected_path >= 0:
			_images.select(selected_path)
		_sync()
		if _session.complete():
			_claim_reward()
	elif not _paths.is_empty():
		_restart()
	else:
		_message.text = "Chưa có ảnh pet. Tạo ảnh pet ở PetHome rồi mở lại."
		_board.texture = null
		_board.queue_redraw()

func close_activity() -> void:
	visible = false
	_dragging = false
	_ghost.hide()
	_confirm.hide()

func _discover_images() -> void:
	_paths.clear()
	_images.clear()
	if FileAccess.file_exists(current_image_path):
		_paths.append(current_image_path)
	for directory in ["user://pet_renders", "user://final_records"]:
		_scan(directory)
	for index in _paths.size():
		_images.add_item("Pet hiện tại" if _paths[index] == current_image_path else "Ảnh pet %d" % (index + 1))
	_images.disabled = _paths.is_empty()

func _scan(directory: String, depth: int = 0) -> void:
	if depth > 3:
		return
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file in files:
		var path := directory.path_join(file)
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] and not _paths.has(path):
			_paths.append(path)
	for folder in dir.get_directories():
		_scan(directory.path_join(folder), depth + 1)

func _load_texture(path: String, difficulty: int) -> bool:
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		return false
	# Preserve the full source and its aspect ratio; no artificial blank pieces.
	var factor := minf(1.0, 1200.0 / maxf(source.get_width(), source.get_height()))
	source.convert(Image.FORMAT_RGBA8)
	if factor < 1.0:
		source.resize(maxi(1, int(source.get_width() * factor)), maxi(1, int(source.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	_texture = ImageTexture.create_from_image(source)
	return true

func _new_match() -> void:
	if _paths.is_empty():
		return
	if not _session.image_path.is_empty() and not _session.complete():
		_confirm.popup_centered(Vector2i(280, 0))
	else:
		_restart()

func _restart() -> void:
	if _paths.is_empty():
		return
	var path := _paths[_images.selected]
	if not _load_texture(path, _level.selected):
		_message.text = "Không đọc được ảnh này. Hãy chọn ảnh pet khác."
		return
	var candidate := JigsawSession.new()
	candidate.start(path, _level.selected)
	if not AtomicJson.write(JigsawSession.SAVE_PATH, candidate.snapshot()):
		if not _session.image_path.is_empty():
			_load_texture(_session.image_path, _session.level)
		_message.text = "Chưa lưu được ván mới. Hãy thử lại."
		return
	_session = candidate
	_selected = -1
	_page = 0
	_announced = false
	_reference.button_pressed = false
	_zoom.select(0)
	_sync()

func _sync() -> void:
	_board.session = _session
	_board.texture = _texture
	_board.selected = _selected
	_progress.text = "%d / %d mảnh" % [_session.placed.size(), _session.count()]
	_message.text = "Hoàn thành ảnh pet!" if _session.complete() else "Kéo mảnh vào khung, hoặc chọn mảnh rồi chạm vị trí."
	_sync_tray()
	_resize_board()
	_board.queue_redraw()

func _resize_board() -> void:
	if _board == null or _session.image_path.is_empty():
		return
	var available := _scroll.size - Vector2(14, 14)
	var dimensions := _texture.get_size() if _texture != null else Vector2(_session.grid())
	var factor := maxf(.01, minf(available.x / dimensions.x, available.y / dimensions.y)) * (_zoom.selected + 1)
	_board.custom_minimum_size = dimensions * factor
	_board.size = _board.custom_minimum_size
	_board.queue_redraw()

func _sync_tray() -> void:
	for child in _tray.get_children():
		_tray.remove_child(child)
		child.queue_free()
	var remaining := _session.remaining()
	var page_count := maxi(1, ceili(float(remaining.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, page_count - 1)
	_previous.disabled = _page == 0
	_next.disabled = _page == page_count - 1
	_page_label.text = "Mảnh còn lại • %d/%d" % [_page + 1, page_count]
	for item in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, remaining.size())):
		var index := remaining[item]
		var piece := JigsawPiece.new()
		piece.session = _session
		piece.texture = _texture
		piece.index = index
		piece.selected = index == _selected
		piece.custom_minimum_size = Vector2(60, 76)
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		piece.gui_input.connect(_piece_input.bind(index, piece))
		_tray.add_child(piece)

func _piece_input(event: InputEvent, index: int, piece: Control) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_drag(index, piece.get_global_transform() * event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(index, get_global_mouse_position())

func _begin_drag(index: int, global_position: Vector2) -> void:
	_select(index)
	_dragging = true
	_ghost.session = _session
	_ghost.texture = _texture
	_ghost.index = index
	_ghost.selected = true
	_ghost.position = get_global_transform().affine_inverse() * global_position - _ghost.size * .5
	_ghost.show()
	_ghost.queue_redraw()

func _select(index: int) -> void:
	_selected = index
	_board.selected = index
	_sync_tray()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _dragging:
		return
	var position_in_view := Vector2.ZERO
	var released := false
	if event is InputEventScreenDrag:
		position_in_view = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		position_in_view = event.position
		released = true
	elif event is InputEventMouseMotion:
		position_in_view = get_global_mouse_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		position_in_view = get_global_mouse_position()
		released = true
	else:
		return
	_ghost.position = get_global_transform().affine_inverse() * position_in_view - _ghost.size * .5
	if released:
		_dragging = false
		_ghost.hide()
		if Rect2(_scroll.global_position, _scroll.size).has_point(position_in_view):
			_board.try_drop(position_in_view)

func _place(index: int) -> void:
	if not _session.place(index):
		return
	if not AtomicJson.write(JigsawSession.SAVE_PATH, _session.snapshot()):
		_session.placed.erase(index)
		_message.text = "Chưa lưu được mảnh ghép. Hãy thử lại."
		return
	_selected = -1
	_sync()
	if _session.complete() and not _announced:
		_announced = true
		match_finished.emit(&"win")
		_claim_reward()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _claim_reward() -> void:
	if game_api == null:
		return
	var id := "%s:%s:%s" % [_session.image_path, _session.level, _session.seed_value]
	var result := game_api.claim_jigsaw_reward(id)
	_message.text = str(result.get("message", ""))
	if not bool(result.get("ok", false)) and str(result.get("message", "")).begins_with("Chưa lưu"):
		var retry := _button("Nhận thưởng lại", func() -> void: _claim_reward())
		add_child(retry)
		retry.position = Vector2(8, 4)
