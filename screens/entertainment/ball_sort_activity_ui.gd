class_name BallSortActivityUI
extends Control


signal back_requested
signal match_finished(result: StringName)


var palette: Dictionary = {}
var game_api: InfantGameFacade

var _game: BallSortGame
var _board: BallSortBoard
var _level_label: Label
var _status_label: Label
var _message_label: Label
var _prev_button: Button
var _next_button: Button
var _undo_button: Button
var _continue_button: Button
var _level := 1
var _unlocked := 1
var _settled := false
var _best_moves: Dictionary = {}


func _ready() -> void:
	_build_ui()


func open_activity() -> void:
	var progress := (
		game_api.ball_sort_progress()
		if game_api != null
		else {"unlocked": 1, "last_level": 1, "best_moves": {}}
	)
	_unlocked = maxi(1, int(progress.get("unlocked", 1)))
	var best_raw: Variant = progress.get("best_moves", {})
	_best_moves = (
		(best_raw as Dictionary).duplicate(true)
		if typeof(best_raw) == TYPE_DICTIONARY
		else {}
	)
	_level = _unlocked
	_start_level(_level)
	visible = true


func close_activity() -> void:
	visible = false


func _start_level(level: int) -> void:
	_level = clampi(level, 1, maxi(1, _unlocked))
	_game = BallSortGame.new()
	_game.start_level(_level)
	_board.set_game(_game)
	_settled = false
	_continue_button.visible = false
	_continue_button.text = "MÀN TIẾP THEO"
	_message_label.text = "Chạm một ống để chọn tinh thể trên cùng."
	_sync()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var back := Button.new()
	back.text = "‹"
	back.custom_minimum_size = Vector2(44, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)

	var title := Label.new()
	title.text = "XẾP TINH THỂ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	header.add_child(title)

	var restart := Button.new()
	restart.text = "↻"
	restart.custom_minimum_size = Vector2(44, 42)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_restart)
	header.add_child(restart)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	root.add_child(level_row)

	_prev_button = Button.new()
	_prev_button.text = "‹"
	_prev_button.custom_minimum_size = Vector2(48, 40)
	_prev_button.pressed.connect(func() -> void: _change_level(-1))
	level_row.add_child(_prev_button)

	_level_label = Label.new()
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 13)
	level_row.add_child(_level_label)

	_next_button = Button.new()
	_next_button.text = "›"
	_next_button.custom_minimum_size = Vector2(48, 40)
	_next_button.pressed.connect(func() -> void: _change_level(1))
	level_row.add_child(_next_button)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override(
		"font_color",
		palette.get("muted", Color.WHITE)
	)
	root.add_child(_status_label)

	_board = BallSortBoard.new()
	_board.palette = palette
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.tube_pressed.connect(_on_tube_pressed)
	root.add_child(_board)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size.y = 36
	root.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	root.add_child(actions)

	_undo_button = Button.new()
	_undo_button.text = "↶ Hoàn tác"
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.custom_minimum_size.y = 44
	_undo_button.pressed.connect(_undo)
	actions.add_child(_undo_button)

	var hint_button := Button.new()
	hint_button.text = "💡 Gợi ý"
	hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_button.custom_minimum_size.y = 44
	hint_button.pressed.connect(_hint)
	actions.add_child(hint_button)

	_continue_button = Button.new()
	_continue_button.text = "MÀN TIẾP THEO"
	_continue_button.custom_minimum_size.y = 46
	_continue_button.visible = false
	_continue_button.pressed.connect(_continue)
	root.add_child(_continue_button)


func _on_tube_pressed(index: int) -> void:
	if _game == null:
		return

	var result := _game.tap_tube(index)
	_message_label.text = String(result.get("message", ""))
	_board.queue_redraw()
	_sync()

	if bool(result.get("complete", false)):
		_settle_completed_level()


func _settle_completed_level() -> void:
	if _settled or _game == null or not _game.is_solved():
		return

	if game_api == null:
		_settled = true
		_unlocked = maxi(_unlocked, _level + 1)
		_message_label.text = "Hoàn thành màn %d • %d bước." % [_level, _game.moves()]
		_continue_button.visible = true
		match_finished.emit(BallSortGame.RESULT_WON)
		_sync()
		return

	var result := game_api.complete_ball_sort_level(_level, _game.moves())
	_message_label.text = String(result.get("message", ""))

	if not bool(result.get("ok", false)):
		_continue_button.text = "THỬ LƯU LẠI"
		_continue_button.visible = true
		return

	_settled = true
	var progress: Dictionary = result.get("progress", {})
	_unlocked = maxi(_unlocked, int(progress.get("unlocked", _level + 1)))
	var best_raw: Variant = progress.get("best_moves", {})
	if typeof(best_raw) == TYPE_DICTIONARY:
		_best_moves = (best_raw as Dictionary).duplicate(true)
	_continue_button.text = "MÀN TIẾP THEO"
	_continue_button.visible = true
	match_finished.emit(BallSortGame.RESULT_WON)
	_sync()


func _continue() -> void:
	if _game == null:
		return

	if not _settled:
		_settle_completed_level()
		if not _settled:
			return

	_start_level(mini(_unlocked, _level + 1))


func _change_level(offset: int) -> void:
	var target := _level + offset
	if target < 1 or target > _unlocked:
		return
	_start_level(target)


func _undo() -> void:
	if _game == null:
		return
	var result := _game.undo()
	_message_label.text = String(result.get("message", ""))
	_board.queue_redraw()
	_sync()


func _hint() -> void:
	if _game == null:
		return
	var result := _game.hint()
	_message_label.text = String(result.get("message", ""))
	if bool(result.get("ok", false)):
		var source := int(result.get("from", -1))
		if source >= 0:
			_game.tap_tube(source)
			_board.queue_redraw()
	_sync()


func _restart() -> void:
	if _game == null:
		return
	_game.restart()
	_settled = false
	_continue_button.visible = false
	_continue_button.text = "MÀN TIẾP THEO"
	_message_label.text = "Đã chơi lại màn %d." % _level
	_board.queue_redraw()
	_sync()


func _sync() -> void:
	if _game == null:
		return

	var config := _game.config()
	var rank := String(config.get("rank", "NORMAL"))
	var best := int(_best_moves.get(str(_level), 0))
	_level_label.text = "MÀN %d • %s" % [_level, rank]
	_status_label.text = "%d màu • %d ống trống • Độ khó %d • %d bước%s" % [
		int(config.get("color_count", 3)),
		int(config.get("empty_tubes", 2)),
		_game.difficulty_score(),
		_game.moves(),
		(" • Kỷ lục %d" % best) if best > 0 else "",
	]
	_prev_button.disabled = _level <= 1
	_next_button.disabled = _level >= _unlocked
	_undo_button.disabled = not _game.can_undo()
	if _game.is_solved():
		_continue_button.visible = true
