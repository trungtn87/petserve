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
var _undo_button: Button
var _hint_button: Button
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
	_level = maxi(1, level)
	_unlocked = maxi(_unlocked, _level)
	_game = BallSortGame.new()
	_game.start_level(_level)
	_board.set_game(_game)
	_settled = false
	_message_label.text = "Kéo tinh thể trên cùng sang ống phù hợp."
	_sync()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var back := Button.new()
	back.text = "‹"
	back.tooltip_text = "Quay lại"
	back.custom_minimum_size = Vector2(42, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var title := Label.new()
	title.text = "XẾP TINH THỂ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title_box.add_child(title)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override(
		"font_color",
		palette.get("accent", Color.WHITE)
	)
	title_box.add_child(_level_label)

	var restart := Button.new()
	restart.text = "↻"
	restart.tooltip_text = "Chơi lại màn"
	restart.custom_minimum_size = Vector2(42, 42)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_restart)
	header.add_child(restart)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override(
		"font_color",
		palette.get("muted", Color.WHITE)
	)
	root.add_child(_status_label)

	_board = BallSortBoard.new()
	_board.palette = palette
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.tube_drop_requested.connect(_on_tube_drop_requested)
	root.add_child(_board)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size.y = 30
	_message_label.add_theme_font_size_override("font_size", 10)
	root.add_child(_message_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	_undo_button = Button.new()
	_undo_button.text = "↶ Hoàn tác"
	_undo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_undo_button.custom_minimum_size.y = 42
	_undo_button.pressed.connect(_undo)
	actions.add_child(_undo_button)

	_hint_button = Button.new()
	_hint_button.text = "💡 Gợi ý"
	_hint_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_button.custom_minimum_size.y = 42
	_hint_button.pressed.connect(_hint)
	actions.add_child(_hint_button)


func _on_tube_drop_requested(
	source_index: int,
	destination_index: int
) -> void:
	if _game == null or _settled:
		return

	var result := _game.move_ball(source_index, destination_index)
	_message_label.text = String(result.get("message", ""))
	_board.queue_redraw()
	_sync()

	if bool(result.get("complete", false)):
		_settle_completed_level()


func _settle_completed_level() -> void:
	if _settled or _game == null or not _game.is_solved():
		return

	var completed_level := _level
	var completed_moves := _game.moves()

	if game_api == null:
		_settled = true
		_unlocked = maxi(_unlocked, completed_level + 1)
		match_finished.emit(BallSortGame.RESULT_WON)
		_start_level(completed_level + 1)
		return

	var result := game_api.complete_ball_sort_level(
		completed_level,
		completed_moves
	)

	if not bool(result.get("ok", false)):
		_message_label.text = (
			String(result.get("message", "Chưa lưu được tiến trình."))
			+ " • Kéo thêm lần nữa để thử lưu lại."
		)
		return

	_settled = true
	var progress: Dictionary = result.get("progress", {})
	_unlocked = maxi(
		_unlocked,
		int(progress.get("unlocked", completed_level + 1))
	)
	var best_raw: Variant = progress.get("best_moves", {})
	if typeof(best_raw) == TYPE_DICTIONARY:
		_best_moves = (best_raw as Dictionary).duplicate(true)

	match_finished.emit(BallSortGame.RESULT_WON)
	call_deferred("_advance_after_complete", completed_level)


func _advance_after_complete(completed_level: int) -> void:
	if not is_visible_in_tree():
		return
	_start_level(completed_level + 1)


func _undo() -> void:
	if _game == null or _settled:
		return
	var result := _game.undo()
	_message_label.text = String(result.get("message", ""))
	_board.queue_redraw()
	_sync()


func _hint() -> void:
	if _game == null or _settled:
		return
	var result := _game.hint()
	_message_label.text = String(result.get("message", ""))
	_board.queue_redraw()
	_sync()


func _restart() -> void:
	if _game == null:
		return
	_game.restart()
	_settled = false
	_message_label.text = "Đã chơi lại màn %d." % _level
	_board.queue_redraw()
	_sync()


func _sync() -> void:
	if _game == null:
		return

	var config := _game.config()
	var rank := String(config.get("rank", "NORMAL"))
	var best := int(_best_moves.get(str(_level), 0))
	_level_label.text = "Màn %d • %s" % [_level, rank]
	_status_label.text = "%d màu • %d bước%s" % [
		int(config.get("color_count", 3)),
		_game.moves(),
		(" • Kỷ lục %d" % best) if best > 0 else "",
	]
	_undo_button.disabled = not _game.can_undo() or _settled
	_hint_button.disabled = _settled
