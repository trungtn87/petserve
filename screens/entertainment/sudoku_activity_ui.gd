class_name SudokuActivityUI
extends Control

signal back_requested
signal reward_received
signal match_finished(result: StringName)
var palette: Dictionary = {}
var game_api: InfantGameFacade
var _state: Dictionary = {}
var _selected := -1
var _board: SudokuBoard
var _message: Label
var _progress: Label
var _difficulty: OptionButton
var _notes: Button
var _undo: Button
var _claim: Button
var _confirm: ConfirmationDialog
var _help: AcceptDialog
var _announced := ""
var _numbers: Array[Button] = []

func _ready() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 5)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(_button("‹", func() -> void: back_requested.emit()))
	var title := _label("SUDOKU", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_button("?", func() -> void: _help.popup_centered(Vector2i(290, 0))))
	var settings := HBoxContainer.new()
	root.add_child(settings)
	_difficulty = OptionButton.new()
	for level in 3:
		_difficulty.add_item(SudokuRules.NAMES[level])
	_difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty.custom_minimum_size.y = 40
	settings.add_child(_difficulty)
	settings.add_child(_button("Ván mới", _new_match))
	_progress = _label("", 12)
	root.add_child(_progress)
	_board = SudokuBoard.new()
	_board.palette = palette
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size.y = 150
	_board.cell_selected.connect(func(index: int) -> void: _selected = index; _sync())
	root.add_child(_board)
	var tools := HBoxContainer.new()
	root.add_child(tools)
	_notes = _button("Ghi chú", func() -> void: pass)
	_notes.toggle_mode = true
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(_notes)
	tools.add_child(_button("Xóa", func() -> void: _enter(0)))
	_undo = _button("Hoàn tác", func() -> void: _apply(game_api.undo_sudoku()))
	tools.add_child(_undo)
	var numbers := GridContainer.new()
	numbers.columns = 9
	numbers.add_theme_constant_override("h_separation", 2)
	root.add_child(numbers)
	for value in range(1, 10):
		var button := _button(str(value), _enter.bind(value))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		numbers.add_child(button)
		_numbers.append(button)
	_claim = _button("NHẬN THƯỞNG", _settle)
	root.add_child(_claim)
	_message = _label("", 11)
	root.add_child(_message)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Chơi ván mới?"
	_confirm.dialog_text = "Ván đang chơi sẽ được thay bằng đề mới."
	_confirm.ok_button_text = "Ván mới"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(_restart)
	add_child(_confirm)
	_help = AcceptDialog.new()
	_help.title = "Cách chơi Sudoku"
	_help.ok_button_text = "Đã hiểu"
	_help.dialog_text = "Điền số 1–9 vào ô trống.\nMỗi hàng, cột và vùng 3×3 có đủ 9 số, không trùng.\n\nChạm ô rồi chọn số. Số cho sẵn không thể sửa.\nGhi chú: ghi nhiều số nhỏ để suy luận.\nSố đỏ: đang trùng trong hàng, cột hoặc vùng.\nXóa và Hoàn tác giúp sửa số hoặc ghi chú.\n\nKhông giới hạn thời gian hay số lần sai.\nThoát game vẫn giữ ván dở và ghi chú.\nMọi độ khó dùng chung: 1 rương/ngày. Chơi thêm 1 mảnh/ván, tối đa 10 mảnh/ngày.\nMỗi ván chỉ nhận thưởng một lần."
	add_child(_help)

func open_activity() -> void:
	visible = true
	_message.text = "Chạm ô trống rồi chọn số • Không giới hạn thời gian."
	if game_api != null:
		_apply(game_api.open_sudoku())
		_difficulty.select(int(_state.get("level", 0)))

func close_activity() -> void:
	visible = false
	_confirm.hide()
	_help.hide()

func _apply(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_state = result.get("state", _state)
		_sync()
	if result.has("message"):
		_message.text = str(result.message)
	elif not bool(result.get("ok", false)):
		_message.text = "Chưa lưu được thay đổi. Hãy thử lại."

func _sync() -> void:
	if _state.is_empty():
		return
	_board.show_state(_state, _selected)
	var filled := 81 - (_state.board as Array).count(0)
	var done := bool(_state.complete)
	var settled := bool(_state.settled)
	_progress.text = "%s • %d/81 ô • Thưởng hằng ngày" % [SudokuRules.NAMES[int(_state.level)], filled]
	_claim.visible = done and not settled
	_undo.disabled = settled or (_state.history as Array).is_empty()
	_notes.disabled = done
	for button in _numbers:
		button.disabled = done or _selected < 0 or int(_state.puzzle[_selected]) != 0
	if done:
		_message.text = "Đã nhận thưởng. Chọn Ván mới để chơi tiếp." if settled else "Hoàn thành! Bấm Nhận thưởng."
		if not settled and _announced != str(_state.match_id):
			_announced = str(_state.match_id)
			match_finished.emit(&"win")

func _enter(value: int) -> void:
	if _selected >= 0 and game_api != null:
		_apply(game_api.enter_sudoku(_selected, value, _notes.button_pressed and value != 0))

func _new_match() -> void:
	if bool(_state.get("complete", false)) and not bool(_state.get("settled", false)):
		_message.text = "Nhận thưởng trước khi chơi ván mới."
	elif not _state.is_empty() and not bool(_state.get("complete", false)):
		_confirm.popup_centered(Vector2i(280, 0))
	else:
		_restart()

func _restart() -> void:
	_selected = -1
	_notes.button_pressed = false
	_apply(game_api.open_sudoku(_difficulty.selected, true))
	if not bool(_state.get("complete", false)):
		_message.text = "Chạm ô trống rồi chọn số."

func _settle() -> void:
	var result := game_api.settle_sudoku()
	_apply(result)
	if bool(result.get("ok", false)):
		reward_received.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _confirm.visible or _help.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.keycode
	if code >= KEY_1 and code <= KEY_9:
		_enter(code - KEY_0)
	elif code == KEY_BACKSPACE or code == KEY_DELETE:
		_enter(0)
	else:
		return
	get_viewport().set_input_as_handled()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
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
