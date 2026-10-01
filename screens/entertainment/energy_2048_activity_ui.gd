class_name Energy2048ActivityUI
extends Control

signal back_requested
signal reward_received
signal match_finished(result: StringName)

var palette: Dictionary = {}
var game_api: InfantGameFacade
var _state: Dictionary = {}
var _board: Energy2048Board
var _score: Label
var _goal: Label
var _reward: Label
var _message: Label
var _finish: Button
var _restart: Button
var _confirm: ConfirmationDialog
var _help: AcceptDialog
var _announced_match := ""

func _ready() -> void:
	_build_ui()

func open_activity() -> void:
	visible = true
	_message.text = "Vuốt để ghép ô • Không giới hạn thời gian."
	if game_api != null:
		_apply(game_api.open_energy_2048())

func close_activity() -> void:
	visible = false
	_confirm.hide()
	_help.hide()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := _button("‹", func() -> void: back_requested.emit())
	back.custom_minimum_size.x = 42
	top.add_child(back)
	var title := _label("2048 • GHÉP NĂNG LƯỢNG", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var help := _button("?", func() -> void: _help.popup_centered(Vector2i(270, 0)))
	help.custom_minimum_size.x = 42
	top.add_child(help)
	_score = _label("", 13)
	root.add_child(_score)
	_goal = _label("", 12)
	root.add_child(_goal)
	_board = Energy2048Board.new()
	_board.palette = palette
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.move_requested.connect(_move)
	root.add_child(_board)
	_reward = _label("", 12)
	root.add_child(_reward)
	_finish = _button("KẾT THÚC & NHẬN THƯỞNG", _request_finish)
	root.add_child(_finish)
	_restart = _button("CHƠI VÁN MỚI", _new_match)
	root.add_child(_restart)
	_message = _label("", 11)
	root.add_child(_message)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Kết thúc ván?"
	_confirm.ok_button_text = "Kết thúc"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(_claim)
	add_child(_confirm)
	_help = AcceptDialog.new()
	_help.title = "Cách chơi 2048"
	_help.ok_button_text = "Đã hiểu"
	_help.dialog_text = "Vuốt 4 hướng để dồn ô.\nHai ô cùng số ghép thành ô gấp đôi.\nMỗi ô ghép tối đa 1 lần mỗi lượt.\n\nÔ lớn nhất → mảnh rương:\n128 → 1  |  256 → 2  |  512 → 3\n1024 → 5  |  2048 → 10\nChỉ nhận mốc cao nhất, không cộng dồn.\nĐủ 10 mảnh tự ghép thành 1 rương.\n\nHết đường đi vẫn nhận thưởng.\nRời màn hình giữ nguyên ván chơi."
	add_child(_help)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(callback)
	return button

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _confirm.visible or _help.visible or event.is_echo():
		return
	var directions := {"ui_left": Vector2i.LEFT, "ui_right": Vector2i.RIGHT, "ui_up": Vector2i.UP, "ui_down": Vector2i.DOWN}
	for action in directions:
		if event.is_action_pressed(action):
			_move(directions[action])
			get_viewport().set_input_as_handled()
			return

func _move(direction: Vector2i) -> void:
	if game_api == null or _board.busy() or _confirm.visible or _help.visible:
		return
	var previous := Energy2048Rules.fragments(Energy2048Rules.largest(_state.get("board", [])))
	var result := game_api.move_energy_2048(direction)
	_apply(result)
	if bool(result.get("ok", false)) and _state.get("status", "") == "playing":
		var current := Energy2048Rules.fragments(Energy2048Rules.largest(_state.get("board", [])))
		if current > previous:
			_message.text = "Đạt mốc mới! Thưởng hiện tại: %d mảnh." % current

func _apply(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_message.text = str(result.get("message", "Không thể lưu ván. Thử lại nhé."))
		return
	_state = result.get("state", _state)
	_board.show_board(_state, result.get("motion", {}))
	_sync()
	if result.has("message"):
		_message.text = str(result.message)

func _sync() -> void:
	var largest := Energy2048Rules.largest(_state.get("board", []))
	var amount := Energy2048Rules.fragments(largest)
	var settled := bool(_state.get("settled", false))
	var status := str(_state.get("status", "playing"))
	_score.text = "Điểm %d   •   Kỷ lục %d" % [int(_state.get("score", 0)), int(_state.get("best_score", 0))]
	_goal.text = "Đã đạt 2048!"
	for milestone in Energy2048Rules.MILESTONES:
		if largest < milestone:
			_goal.text = "Đạt ô %d → %d mảnh rương" % [milestone, Energy2048Rules.fragments(milestone)]
			break
	_reward.text = ("Đã nhận: %d mảnh" if settled else "Thưởng hiện tại: %d mảnh") % amount
	_finish.visible = not settled
	_finish.text = "KẾT THÚC & NHẬN THƯỞNG" if status == "playing" else "NHẬN THƯỞNG"
	_restart.visible = settled
	if status in ["won", "lost"]:
		_message.text = "Đạt 2048! Nhận thưởng để chơi ván mới." if status == "won" else "Hết đường đi. Bạn vẫn được nhận thưởng."
		if settled:
			_message.text = "Đã nhận thưởng ván này. Bạn có thể chơi ván mới."
		var match_id := str(_state.get("match_id", ""))
		if match_id != _announced_match and not settled:
			_announced_match = match_id
			match_finished.emit(&"win" if status == "won" else &"lose")

func _request_finish() -> void:
	if _state.is_empty() or _board.busy():
		return
	if _state.get("status", "playing") != "playing":
		_claim()
		return
	var amount := Energy2048Rules.fragments(Energy2048Rules.largest(_state.board))
	_confirm.dialog_text = "Kết thúc ván và nhận %d mảnh rương?\nBạn không thể chơi tiếp ván này." % amount
	_confirm.popup_centered(Vector2i(270, 0))

func _claim() -> void:
	if game_api == null:
		return
	var result := game_api.finish_energy_2048()
	_apply(result)
	if bool(result.get("ok", false)):
		reward_received.emit()

func _new_match() -> void:
	if game_api != null:
		_apply(game_api.restart_energy_2048())
		if _state.get("status", "") == "playing":
			_message.text = "Vuốt để ghép ô • Không giới hạn thời gian."
