class_name TetrisActivityUI
extends Control

signal back_requested
signal reward_received
signal match_finished(result: StringName)

const NAMES := ["I", "O", "T", "S", "Z", "J", "L"]
var palette: Dictionary = {}
var game_api: InfantGameFacade
var _state: Dictionary = {}
var _board: TetrisBoard
var _score: Label
var _preview: Label
var _reward: Label
var _message: Label
var _new: Button
var _claim: Button
var _pause: Button
var _confirm: ConfirmationDialog
var _help: AcceptDialog
var _ranking: AcceptDialog
var _controls: Array[Button] = []
var _paused := false
var _horizontal := 0
var _repeat_elapsed := 0.0
var _repeat_started := false
var _soft_held := false
var _soft_elapsed := 0.0
var _announced_match := ""

func _ready() -> void:
	_build_ui()

func open_activity() -> void:
	visible = true
	_paused = false
	_pause.text = "Dừng"
	_state = {}
	_message.text = "Chơi vô hạn • Chỉ xóa hàng mới được điểm."
	if game_api != null:
		_apply(game_api.start_tetris())

func close_activity() -> void:
	visible = false
	_release_inputs()
	_confirm.hide()
	_help.hide()
	_ranking.hide()
	if game_api != null:
		game_api.abandon_tetris()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_paused = true
		_release_inputs()
		if _pause != null:
			_pause.text = "Tiếp tục"

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_button("‹", _request_back))
	var title := _label("TETRIS", 14)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Top", _show_ranking))
	header.add_child(_button("?", func() -> void: _release_inputs(); _help.popup_centered(Vector2i(290,0))))
	_pause = _button("Dừng", _toggle_pause)
	header.add_child(_pause)
	_score = _label("", 12)
	root.add_child(_score)
	_preview = _label("", 11)
	root.add_child(_preview)
	_board = TetrisBoard.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_board)
	_reward = _label("", 11)
	root.add_child(_reward)
	var directions := HBoxContainer.new()
	directions.add_theme_constant_override("separation", 8)
	root.add_child(directions)
	var left := _button("◀", func() -> void: pass)
	left.button_down.connect(func() -> void: _begin_horizontal(-1))
	left.button_up.connect(func() -> void: _horizontal = 0)
	var right := _button("▶", func() -> void: pass)
	right.button_down.connect(func() -> void: _begin_horizontal(1))
	right.button_up.connect(func() -> void: _horizontal = 0)
	var rotate := _button("Xoay ↻", func() -> void: _action("rotate"))
	for button in [left, rotate, right]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		directions.add_child(button)
		_controls.append(button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var hold := _button("Giữ", func() -> void: _action("hold"))
	var down := _button("Xuống ▼", func() -> void: pass)
	down.button_down.connect(func() -> void: _soft_held = true; _soft_elapsed = 0.0; _action("down"))
	down.button_up.connect(func() -> void: _soft_held = false)
	var drop := _button("THẢ NGAY", func() -> void: _action("drop"))
	for button in [hold, down, drop]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		_controls.append(button)
	_claim = _button("NHẬN THƯỞNG", _settle)
	root.add_child(_claim)
	_new = _button("CHƠI VÁN MỚI", _new_match)
	root.add_child(_new)
	_message = _label("", 11)
	root.add_child(_message)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Rời Tetris?"
	_confirm.dialog_text = "Ván này sẽ kết thúc và không nhận thưởng."
	_confirm.ok_button_text = "Rời ván"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(func() -> void: back_requested.emit())
	add_child(_confirm)
	_help = AcceptDialog.new()
	_help.title = "Tetris • Chơi vô hạn"
	_help.dialog_text = "Xếp khối để lấp đầy hàng ngang.\nXóa 1/2/3/4 hàng: 100/300/500/800 × cấp.\nCombo: +50 × số combo × cấp.\nChuỗi xóa 4 hàng: +50% điểm cơ bản.\n\nMỗi 6 hàng tăng cấp; tối đa cấp 10.\nTốc độ tối đa: 0,12 giây/ô. Không giới hạn thời gian.\nGiữ 1 khối, xem trước 2 khối, bóng vị trí rơi.\n\n2.000 điểm = 1 mảnh, không giới hạn thưởng.\n10 mảnh tự ghép rương trong Kho.\nVượt top 1: +1 rương, tối đa 1 lần/ngày.\nKỷ lục ban đầu cần vượt: 5.000 điểm.\nThưởng khi thua; rời ván không nhận thưởng.\n\nBàn phím: ← → di chuyển, ↑ xoay, ↓ xuống,\nSpace thả ngay, C giữ khối, P tạm dừng."
	add_child(_help)
	_ranking = AcceptDialog.new()
	_ranking.title = "TOP 10 • TRÊN THIẾT BỊ"
	add_child(_ranking)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(36, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(callback)
	return button

func _blocked() -> bool:
	return _paused or _confirm.visible or _help.visible or _ranking.visible

func _process(delta: float) -> void:
	if not is_visible_in_tree() or game_api == null or _blocked() or _state.get("status", "") != "playing":
		return
	if _horizontal != 0:
		_repeat_elapsed += delta
		var interval := 0.07 if _repeat_started else 0.18
		if _repeat_elapsed >= interval:
			_repeat_elapsed -= interval
			_repeat_started = true
			_action("left" if _horizontal < 0 else "right")
	if _soft_held:
		_soft_elapsed += delta
		if _soft_elapsed >= 0.035:
			_soft_elapsed = 0.0
			_action("down")
	var result := game_api.tick_tetris(delta)
	if bool(result.get("changed", false)):
		_apply(result)

func _begin_horizontal(direction: int) -> void:
	_horizontal = direction
	_repeat_elapsed = 0.0
	_repeat_started = false
	_action("left" if direction < 0 else "right")

func _release_inputs() -> void:
	_horizontal = 0
	_soft_held = false

func _action(action: String) -> void:
	if game_api != null and not _blocked():
		_apply(game_api.action_tetris(action))

func _apply(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		if result.has("message"):
			_message.text = str(result.message)
		return
	_state = result.get("state", _state)
	_sync()
	if result.has("message"):
		_message.text = str(result.message)
	if _state.get("status", "") == "lost" and not bool(_state.get("settled", false)) and _announced_match != str(_state.match_id):
		_announced_match = str(_state.match_id)
		_release_inputs()
		match_finished.emit(&"lose")
		_settle()

func _sync() -> void:
	if _state.is_empty():
		return
	_board.show_state(_state)
	_score.text = "%d điểm • Cấp %d • %d hàng • Top %d" % [_state.score, _state.level, _state.lines, _state.best_score]
	var held := int(_state.held)
	var next: Array = _state.next
	_preview.text = "Giữ: %s  |  Tiếp: %s  %s" % [NAMES[held] if held >= 0 else "—", NAMES[int(next[0])], NAMES[int(next[1])]]
	var playing: bool = _state.status == "playing"
	var settled := bool(_state.settled)
	_reward.text = "%d mảnh • Mỗi 2.000 điểm +1 mảnh" % int(_state.fragments)
	for button in _controls:
		button.disabled = not playing
	_controls[3].disabled = not playing or bool(_state.hold_used)
	_claim.visible = not playing and not settled
	_new.visible = settled
	_pause.disabled = not playing

func _settle() -> void:
	if game_api == null:
		return
	var result := game_api.settle_tetris()
	_apply(result)
	if bool(result.get("ok", false)):
		reward_received.emit()

func _new_match() -> void:
	if game_api != null:
		_paused = false
		_pause.text = "Dừng"
		_release_inputs()
		_apply(game_api.start_tetris())
		_message.text = "Chơi vô hạn • Chỉ xóa hàng mới được điểm."

func _request_back() -> void:
	_release_inputs()
	if not _state.is_empty() and not bool(_state.get("settled", false)):
		_confirm.popup_centered(Vector2i(280, 0))
	else:
		back_requested.emit()

func _toggle_pause() -> void:
	_paused = not _paused
	_release_inputs()
	_pause.text = "Tiếp tục" if _paused else "Dừng"

func _show_ranking() -> void:
	_release_inputs()
	var records := game_api.tetris_records() if game_api != null else {}
	var text := "Mốc top 1: %d điểm\n\n" % TetrisRecords.top_score(records)
	var entries: Array = records.get("entries", [])
	if entries.is_empty():
		text += "Chưa có ván hoàn thành."
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var date := Time.get_datetime_string_from_unix_time(int(entry.at_unix)).substr(0, 10)
		text += "%d. %d điểm • %d hàng • Cấp %d\n    %s\n" % [index + 1, entry.score, entry.lines, entry.level, date]
	_ranking.dialog_text = text + "\nKhông xếp hạng theo thời gian chơi."
	_ranking.popup_centered(Vector2i(290, 0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if key.is_echo():
		return
	if key.keycode in [KEY_LEFT, KEY_RIGHT, KEY_DOWN] and not key.pressed:
		if key.keycode == KEY_DOWN:
			_soft_held = false
		else:
			_horizontal = 0
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or _confirm.visible or _help.visible or _ranking.visible:
		return
	match key.keycode:
		KEY_LEFT: _begin_horizontal(-1)
		KEY_RIGHT: _begin_horizontal(1)
		KEY_UP: _action("rotate")
		KEY_DOWN: _soft_held = true; _action("down")
		KEY_SPACE: _action("drop")
		KEY_C: _action("hold")
		KEY_P: _toggle_pause()
		_: return
	get_viewport().set_input_as_handled()
