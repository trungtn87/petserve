class_name JigsawActivityUI
extends Control


signal back_requested
signal match_finished(result: StringName)

const MIN_ZOOM := 0.65
const MAX_ZOOM := 3.0
const DRAG_THRESHOLD := 9.0

var game_api: InfantGameFacade
var palette: Dictionary = {}
var current_image_path := ""

var _session := JigsawSession.new()
var _texture: Texture2D
var _level: OptionButton
var _reference: Button
var _rotate: Button
var _board: JigsawBoard
var _scroll: ScrollContainer
var _tray_scroll: ScrollContainer
var _tray: HBoxContainer
var _progress: Label
var _message: Label
var _confirm: ConfirmationDialog
var _selected := -1
var _pending_level := -1
var _dragging := false
var _pressed_piece := -1
var _press_position := Vector2.ZERO
var _ghost: JigsawPiece
var _announced := false
var _zoom_factor := 1.0
var _touches: Dictionary = {}
var _pinching := false
var _pinch_distance := 0.0
var _pinch_zoom_start := 1.0


func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 7)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var back := _button("‹", func() -> void: back_requested.emit())
	back.custom_minimum_size = Vector2(42, 42)
	back.tooltip_text = "Quay lại"
	header.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title := _label("GHÉP HÌNH PET", 15)
	title_box.add_child(title)

	_progress = _label("", 10)
	_progress.add_theme_color_override(
		"font_color",
		palette.get("accent", Color.WHITE)
	)
	title_box.add_child(_progress)

	var restart := _button("↻", _new_match)
	restart.custom_minimum_size = Vector2(42, 42)
	restart.tooltip_text = "Ván mới"
	header.add_child(restart)

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	root.add_child(mode_row)

	_level = OptionButton.new()
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index in range(JigsawSession.COUNTS.size()):
		_level.add_item(
			"%d mảnh • %d rương" % [
				JigsawSession.COUNTS[index],
				index + 1,
			]
		)
	_level.item_selected.connect(_on_level_selected)
	mode_row.add_child(_level)

	_reference = _button("👁 Mẫu", func() -> void: pass)
	_reference.toggle_mode = true
	_reference.toggled.connect(
		func(value: bool) -> void:
			_board.show_reference = value
			_board.queue_redraw()
	)
	mode_row.add_child(_reference)

	_rotate = _button("↻ Xoay", _rotate_selected)
	_rotate.disabled = true
	mode_row.add_child(_rotate)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.06, 0.05, 0.10, 0.96),
			palette.get("accent", Color("a98af4"))
		)
	)
	root.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 6)
	board_margin.add_theme_constant_override("margin_top", 6)
	board_margin.add_theme_constant_override("margin_right", 6)
	board_margin.add_theme_constant_override("margin_bottom", 6)
	board_panel.add_child(board_margin)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 180
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.resized.connect(_resize_board)
	board_margin.add_child(_scroll)

	_board = JigsawBoard.new()
	_board.drop_requested.connect(_place)
	_scroll.add_child(_board)

	var tray_label := _label("KHAY CHỜ • kéo mảnh vào ảnh", 9)
	tray_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tray_label.add_theme_color_override(
		"font_color",
		palette.get("muted", Color.WHITE)
	)
	root.add_child(tray_label)

	_tray_scroll = ScrollContainer.new()
	_tray_scroll.custom_minimum_size.y = 82
	_tray_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tray_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_tray_scroll)

	_tray = HBoxContainer.new()
	_tray.add_theme_constant_override("separation", 4)
	_tray_scroll.add_child(_tray)

	_message = _label("", 10)
	_message.custom_minimum_size.y = 30
	root.add_child(_message)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Bắt đầu ván mới?"
	_confirm.dialog_text = "Tiến độ ván hiện tại sẽ được thay thế."
	_confirm.ok_button_text = "Bắt đầu"
	_confirm.cancel_button_text = "Giữ ván cũ"
	_confirm.confirmed.connect(_restart)
	_confirm.canceled.connect(_cancel_level_change)
	add_child(_confirm)

	_ghost = JigsawPiece.new()
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 100
	_ghost.size = Vector2(76, 76)
	_ghost.visible = false
	add_child(_ghost)


func open_activity() -> void:
	AudioService.play("open")
	visible = true
	_touches.clear()
	_pinching = false
	_dragging = false
	_ghost.hide()

	if not FileAccess.file_exists(current_image_path):
		_message.text = "Chưa có ảnh pet hiện tại để ghép."
		_board.texture = null
		_board.queue_redraw()
		return

	var restored := _session.restore(
		AtomicJson.read(JigsawSession.SAVE_PATH)
	)
	if (
		restored
		and _session.image_path == current_image_path
		and _load_texture(current_image_path)
	):
		_level.select(_session.level)
		_reference.button_pressed = false
		_zoom_factor = 1.0
		_sync()
		if _session.complete():
			_claim_reward()
		return

	_level.select(0)
	_restart()


func close_activity() -> void:
	visible = false
	_dragging = false
	_pressed_piece = -1
	_selected = -1
	_touches.clear()
	_pinching = false
	_ghost.hide()
	_confirm.hide()


func _load_texture(path: String) -> bool:
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		return false

	var factor := minf(
		1.0,
		1600.0 / maxf(source.get_width(), source.get_height())
	)
	source.convert(Image.FORMAT_RGBA8)
	if factor < 1.0:
		source.resize(
			maxi(1, int(source.get_width() * factor)),
			maxi(1, int(source.get_height() * factor)),
			Image.INTERPOLATE_LANCZOS
		)

	_texture = ImageTexture.create_from_image(source)
	return true


func _on_level_selected(index: int) -> void:
	_pending_level = clampi(index, 0, 2)
	_new_match()


func _new_match() -> void:
	if not FileAccess.file_exists(current_image_path):
		_message.text = "Chưa có ảnh pet hiện tại."
		return

	if not _session.image_path.is_empty() and not _session.complete():
		_confirm.popup_centered(Vector2i(290, 0))
		return

	_restart()


func _cancel_level_change() -> void:
	_pending_level = -1
	if not _session.image_path.is_empty():
		_level.select(_session.level)


func _restart() -> void:
	var target_level := (
		_pending_level
		if _pending_level >= 0
		else _level.selected
	)
	_pending_level = -1
	target_level = clampi(target_level, 0, 2)
	_level.select(target_level)

	if not _load_texture(current_image_path):
		_message.text = "Không đọc được ảnh pet hiện tại."
		return

	var candidate := JigsawSession.new()
	candidate.start(current_image_path, target_level)

	if not AtomicJson.write(
		JigsawSession.SAVE_PATH,
		candidate.snapshot()
	):
		_message.text = "Chưa lưu được ván mới. Hãy thử lại."
		if not _session.image_path.is_empty():
			_level.select(_session.level)
		return

	_session = candidate
	_selected = -1
	_announced = false
	_reference.button_pressed = false
	_zoom_factor = 1.0
	_sync()


func _sync() -> void:
	_board.session = _session
	_board.texture = _texture
	_board.selected = _selected
	_progress.text = "%d/%d • thưởng %d rương" % [
		_session.placed.size(),
		_session.count(),
		_session.reward_chests(),
	]
	_rotate.disabled = _selected < 0

	if _session.complete():
		_message.text = "Hoàn thành ảnh pet!"
	elif _selected >= 0:
		_message.text = "Kéo mảnh vào đúng vị trí • xoay đủ 4 hướng bằng nút ↻."
	else:
		_message.text = "Chọn mảnh trong khay • kéo để xếp • dùng 2 ngón để zoom."

	_sync_tray()
	call_deferred("_resize_board")
	_board.queue_redraw()


func _resize_board() -> void:
	if (
		_board == null
		or _scroll == null
		or _texture == null
		or _session.image_path.is_empty()
	):
		return

	var available := _scroll.size - Vector2(12, 12)
	if available.x <= 8 or available.y <= 8:
		return

	var dimensions := _texture.get_size()
	var fit := maxf(
		0.01,
		minf(
			available.x / maxf(1.0, dimensions.x),
			available.y / maxf(1.0, dimensions.y)
		)
	)
	var target_size := dimensions * fit * _zoom_factor
	_board.custom_minimum_size = target_size
	_board.size = target_size
	_board.queue_redraw()


func _set_zoom(value: float) -> void:
	var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, _zoom_factor):
		return
	_zoom_factor = next_zoom
	_resize_board()


func _sync_tray() -> void:
	for child in _tray.get_children():
		_tray.remove_child(child)
		child.queue_free()

	for index in _session.remaining():
		var piece := JigsawPiece.new()
		piece.session = _session
		piece.texture = _texture
		piece.index = index
		piece.selected = index == _selected
		piece.rotation_steps = _session.rotation_steps(index)
		piece.custom_minimum_size = Vector2(58, 74)
		piece.gui_input.connect(
			_piece_input.bind(index, piece)
		)
		_tray.add_child(piece)


func _piece_input(
	event: InputEvent,
	index: int,
	piece: Control
) -> void:
	if _pinching:
		return

	if event is InputEventScreenTouch and event.pressed:
		_prepare_piece_press(
			index,
			piece.get_global_transform() * event.position
		)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_prepare_piece_press(
			index,
			get_global_mouse_position()
		)


func _prepare_piece_press(
	index: int,
	global_position: Vector2
) -> void:
	_selected = index
	_pressed_piece = index
	_press_position = global_position
	_board.selected = index
	_rotate.disabled = false
	_sync_tray()
	_board.queue_redraw()


func _begin_drag(
	index: int,
	global_position: Vector2
) -> void:
	if index < 0 or _pinching:
		return

	_dragging = true
	_ghost.session = _session
	_ghost.texture = _texture
	_ghost.index = index
	_ghost.selected = true
	_ghost.rotation_steps = _session.rotation_steps(index)
	_update_ghost(global_position)
	_ghost.show()
	_ghost.queue_redraw()


func _update_ghost(global_position: Vector2) -> void:
	_ghost.position = (
		get_global_transform().affine_inverse()
		* global_position
		- _ghost.size * 0.5
	)


func _finish_drag(global_position: Vector2) -> void:
	var dragged_index := _selected
	_dragging = false
	_pressed_piece = -1
	_ghost.hide()

	if dragged_index < 0:
		return

	_board.selected = dragged_index
	if Rect2(_scroll.global_position, _scroll.size).has_point(global_position):
		_board.try_drop(global_position)
	else:
		_message.text = "Mảnh đã được trả về khay chờ."


func _rotate_selected() -> void:
	if _selected < 0:
		return

	var before := _session.rotation_steps(_selected)
	if not _session.rotate_piece(_selected):
		return

	if not AtomicJson.write(
		JigsawSession.SAVE_PATH,
		_session.snapshot()
	):
		while _session.rotation_steps(_selected) != before:
			_session.rotate_piece(_selected)
		_message.text = "Chưa lưu được hướng xoay. Hãy thử lại."
		return

	_message.text = "Đã xoay mảnh 90°."
	_sync_tray()
	if _dragging:
		_ghost.rotation_steps = _session.rotation_steps(_selected)
		_ghost.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() >= 2:
				_begin_pinch()
			else:
				_handle_piece_motion(event.position)
		else:
			if _pinching:
				_touches.erase(event.index)
				if _touches.size() < 2:
					_end_pinch()
				return

			var release_position: Vector2 = event.position
			_touches.erase(event.index)
			if _dragging:
				_finish_drag(release_position)
			elif (
				_pressed_piece >= 0
				and release_position.distance_to(_press_position)
					< DRAG_THRESHOLD
			):
				_selected = _pressed_piece
				_message.text = "Mảnh đã chọn • dùng ↻ để xoay hoặc kéo vào ảnh."
			_pressed_piece = -1
		return

	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _pinching:
			_update_pinch()
			return
		_handle_piece_motion(event.position)
		return

	if event is InputEventMouseMotion:
		if _pressed_piece >= 0 or _dragging:
			_handle_piece_motion(get_global_mouse_position())
		return

	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		var release_position: Vector2 = get_global_mouse_position()
		if _dragging:
			_finish_drag(release_position)
		_pressed_piece = -1


func _handle_piece_motion(position: Vector2) -> void:
	if _pinching or _pressed_piece < 0:
		return

	if (
		not _dragging
		and position.distance_to(_press_position) >= DRAG_THRESHOLD
	):
		_begin_drag(_pressed_piece, position)

	if _dragging:
		_update_ghost(position)


func _begin_pinch() -> void:
	if _touches.size() < 2:
		return

	_pinching = true
	_dragging = false
	_pressed_piece = -1
	_ghost.hide()
	_pinch_distance = _touch_distance()
	_pinch_zoom_start = _zoom_factor


func _update_pinch() -> void:
	if not _pinching or _touches.size() < 2:
		return

	var distance := _touch_distance()
	if _pinch_distance <= 1.0:
		return

	_set_zoom(
		_pinch_zoom_start
		* distance
		/ _pinch_distance
	)


func _end_pinch() -> void:
	_pinching = false
	_pinch_distance = 0.0
	_pinch_zoom_start = _zoom_factor


func _touch_distance() -> float:
	if _touches.size() < 2:
		return 0.0

	var keys := _touches.keys()
	var first: Vector2 = _touches[keys[0]]
	var second: Vector2 = _touches[keys[1]]
	return first.distance_to(second)


func _place(index: int) -> void:
	if index < 0 or index >= _session.count():
		return

	if not _session.is_upright(index):
		_message.text = "Mảnh đúng vị trí nhưng đang sai hướng • xoay lại rồi thả."
		return

	if not _session.place(index):
		return

	if not AtomicJson.write(
		JigsawSession.SAVE_PATH,
		_session.snapshot()
	):
		_session.placed.erase(index)
		_message.text = "Chưa lưu được mảnh ghép. Hãy thử lại."
		return

	_selected = -1
	_sync()

	if _session.complete() and not _announced:
		_announced = true
		match_finished.emit(&"win")
		_claim_reward()


func _button(
	text: String,
	callback: Callable
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(callback)
	return button


func _label(
	text: String,
	font_size: int
) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _claim_reward() -> void:
	if game_api == null:
		return

	var id := "%s:%s:%s" % [
		_session.image_path,
		_session.level,
		_session.seed_value,
	]
	var result := game_api.claim_jigsaw_reward(id)
	_message.text = str(result.get("message", ""))

	if (
		not bool(result.get("ok", false))
		and str(result.get("message", "")).begins_with("Chưa lưu")
	):
		_message.text += " • Mở lại game để thử nhận lại."



func _panel_style(
	bg: Color,
	border: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
