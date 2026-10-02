class_name CaroActivityUI
extends Control


signal reward_requested
signal back_requested
signal match_finished(result: StringName)


const PET_THINK_DELAY: float = 0.55


var palette: Dictionary = {}

var _game: TicTacToeGame = TicTacToeGame.new()
var _is_open: bool = false
var _pet_turn_pending: bool = false
var _reward_claimed: int = 0
var _reward_max: int = 4
var _reward_enabled: bool = true
var _turn_ticket: int = 0

var _status_label: Label
var _reward_label: Label
var _message_label: Label
var _cells: Array[Button] = []
var _new_round_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_activity() -> void:
	visible = true
	_is_open = true
	_start_new_round()


func close_activity() -> void:
	_turn_ticket += 1
	_pet_turn_pending = false
	visible = false
	_is_open = false


func set_reward_status(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_reward_claimed = reward_claimed
	_reward_max = max(
		0,
		reward_max
	)
	_reward_enabled = reward_enabled
	_update_reward_label()


func show_reward_message(
	message: String
) -> void:
	if _message_label != null:
		_message_label.text = message


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_theme_constant_override(
		"separation",
		10
	)
	add_child(
		root
	)

	var header := HBoxContainer.new()
	root.add_child(
		header
	)

	var back := Button.new()
	back.text = "‹"
	back.custom_minimum_size = Vector2(
		42,
		42
	)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(
		_on_back_pressed
	)
	header.add_child(
		back
	)

	var title := Label.new()
	title.text = "CARO 3×3"
	title.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	title.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	title.add_theme_font_size_override(
		"font_size",
		18
	)
	header.add_child(
		title
	)

	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override(
		"font_size",
		11
	)
	_reward_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	root.add_child(
		_reward_label
	)

	var hint := Label.new()
	hint.text = "Bạn là X • Pet là O"
	hint.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	hint.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		hint
	)

	_status_label = Label.new()
	_status_label.text = "Lượt của bạn"
	_status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_status_label.add_theme_font_size_override(
		"font_size",
		14
	)
	root.add_child(
		_status_label
	)

	var center := CenterContainer.new()
	center.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	root.add_child(
		center
	)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(
		"h_separation",
		7
	)
	grid.add_theme_constant_override(
		"v_separation",
		7
	)
	center.add_child(
		grid
	)

	for index in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(
			78,
			78
		)
		cell.focus_mode = Control.FOCUS_NONE
		cell.add_theme_font_size_override(
			"font_size",
			32
		)
		cell.pressed.connect(
			_on_cell_pressed.bind(
				index
			)
		)
		grid.add_child(
			cell
		)
		_cells.append(
			cell
		)

	_message_label = Label.new()
	_message_label.text = "Thắng để nhận Rương Ấu thể."
	_message_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_message_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	_message_label.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		_message_label
	)

	_new_round_button = Button.new()
	_new_round_button.text = "VÁN MỚI"
	_new_round_button.custom_minimum_size = Vector2(
		0,
		46
	)
	_new_round_button.focus_mode = Control.FOCUS_NONE
	_new_round_button.pressed.connect(
		_start_new_round
	)
	root.add_child(
		_new_round_button
	)

	_update_reward_label()


func _start_new_round() -> void:
	_turn_ticket += 1
	_game.reset()
	_pet_turn_pending = false
	_status_label.text = "Lượt của bạn"
	_message_label.text = (
		"Thắng để nhận Rương Ấu thể."
		if (
			_reward_enabled
			and _reward_claimed < _reward_max
		)
		else "Thắng để nhận 1 mảnh rương."
	)
	_render_board()


func _on_cell_pressed(
	index: int
) -> void:
	if _pet_turn_pending:
		return

	if not _game.player_move(
		index
	):
		return

	_render_board()

	var game_result := _game.result()

	if game_result != TicTacToeGame.RESULT_PLAYING:
		_finish_round(
			game_result
		)
		return

	_pet_turn_pending = true
	_status_label.text = "Pet đang nghĩ..."
	_render_board()

	var ticket := _turn_ticket

	get_tree().create_timer(
		PET_THINK_DELAY
	).timeout.connect(
		_pet_turn.bind(
			ticket
		),
		CONNECT_ONE_SHOT
	)


func _pet_turn(
	ticket: int
) -> void:
	if (
		ticket != _turn_ticket
		or not _is_open
	):
		return

	_game.pet_move()
	_pet_turn_pending = false
	_render_board()

	var game_result := _game.result()

	if game_result != TicTacToeGame.RESULT_PLAYING:
		_finish_round(
			game_result
		)
		return

	_status_label.text = "Lượt của bạn"
	_render_board()


func _finish_round(
	game_result: StringName
) -> void:
	match game_result:
		TicTacToeGame.RESULT_PLAYER:
			_status_label.text = "Bạn thắng!"
			_message_label.text = (
				"Đang nhận Rương Ấu thể..."
				if (
					_reward_enabled
					and _reward_claimed < _reward_max
				)
				else "Đang nhận 1 mảnh rương..."
			)
			reward_requested.emit()

		TicTacToeGame.RESULT_PET:
			_status_label.text = "Pet thắng!"
			_message_label.text = (
				"Pet có vẻ khá đắc ý."
			)

		TicTacToeGame.RESULT_DRAW:
			_status_label.text = "Hòa!"
			_message_label.text = (
				"Không mất gì • thử lại ván khác."
			)

	match_finished.emit(
		game_result
	)
	_render_board()


func _render_board() -> void:
	var board := _game.board()
	var game_over := (
		_game.result()
		!= TicTacToeGame.RESULT_PLAYING
	)

	for index in range(
		_cells.size()
	):
		var cell := _cells[index]
		var value := int(
			board[index]
		)

		match value:
			TicTacToeGame.PLAYER:
				cell.text = "X"
			TicTacToeGame.PET:
				cell.text = "O"
			_:
				cell.text = ""

		cell.disabled = (
			game_over
			or _pet_turn_pending
			or value != TicTacToeGame.EMPTY
		)

	_new_round_button.disabled = (
		_pet_turn_pending
	)


func _update_reward_label() -> void:
	if _reward_label == null:
		return

	var claimed := clampi(
		_reward_claimed,
		0,
		_reward_max
	)

	if not _reward_enabled:
		_reward_label.text = (
			"Ngoài giai đoạn thưởng rương • thắng = 1 mảnh"
		)
		return

	if claimed >= _reward_max:
		_reward_label.text = (
			"Đã hết Rương Caro • thắng = 1 mảnh"
		)
		return

	_reward_label.text = (
		"Rương Caro  %d/%d"
		% [
			claimed,
			_reward_max,
		]
	)


func _on_back_pressed() -> void:
	close_activity()
	back_requested.emit()
