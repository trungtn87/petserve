class_name EntertainmentHubUI
extends Control

var palette: Dictionary = {}


signal caro_win_reward_requested
signal match_finished(result: StringName)


const PET_THINK_DELAY: float = 0.55


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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_hub(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_reward_claimed = reward_claimed
	_reward_max = max(0, reward_max)
	_reward_enabled = reward_enabled
	_update_reward_label()
	visible = true
	_is_open = true
	_start_new_round()


func close_hub() -> void:
	_turn_ticket += 1
	_pet_turn_pending = false
	visible = false
	_is_open = false


func is_open() -> bool:
	return _is_open


func set_reward_status(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_reward_claimed = reward_claimed
	_reward_max = max(0, reward_max)
	_reward_enabled = reward_enabled
	_update_reward_label()


func show_reward_message(message: String) -> void:
	_message_label.text = message


func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.015, 0.01, 0.03, 0.94)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.06
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(0.07, 0.045, 0.13, 0.99),
			Color(0.55, 0.42, 0.80, 0.96)
		)
	)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "GIẢI TRÍ • CARO 3×3"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	header.add_child(title)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_hub)
	header.add_child(close)

	_reward_label = Label.new()
	_reward_label.add_theme_font_size_override("font_size", 12)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_reward_label)

	var hint := Label.new()
	hint.text = "Bạn là X • Pet là O"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	root.add_child(hint)

	_status_label = Label.new()
	_status_label.text = "Lượt của bạn"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	root.add_child(_status_label)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	center.add_child(grid)

	for index in range(9):
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(84, 84)
		cell.focus_mode = Control.FOCUS_NONE
		cell.add_theme_font_size_override("font_size", 34)
		cell.pressed.connect(_on_cell_pressed.bind(index))
		grid.add_child(cell)
		_cells.append(cell)

	_message_label = Label.new()
	_message_label.text = "Thắng để nhận Rương Ấu thể."
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_message_label)

	_new_round_button = Button.new()
	_new_round_button.text = "VÁN MỚI"
	_new_round_button.custom_minimum_size = Vector2(0, 48)
	_new_round_button.focus_mode = Control.FOCUS_NONE
	_new_round_button.pressed.connect(_start_new_round)
	root.add_child(_new_round_button)

	_start_new_round()


func _start_new_round() -> void:
	_turn_ticket += 1
	_game.reset()
	_pet_turn_pending = false
	_status_label.text = "Lượt của bạn"
	_message_label.text = (
		"Thắng để nhận Rương Ấu thể."
		if _reward_enabled and _reward_claimed < _reward_max
		else "Có thể chơi tiếp • phần thưởng giai đoạn này đã hết."
	)
	_render_board()


func _on_cell_pressed(index: int) -> void:
	if _pet_turn_pending:
		return

	if not _game.player_move(index):
		return

	_render_board()

	var game_result := _game.result()

	if game_result != TicTacToeGame.RESULT_PLAYING:
		_finish_round(game_result)
		return

	_pet_turn_pending = true
	_status_label.text = "Pet đang nghĩ..."
	_render_board()

	var ticket := _turn_ticket

	get_tree().create_timer(PET_THINK_DELAY).timeout.connect(
		_pet_turn.bind(ticket),
		CONNECT_ONE_SHOT
	)


func _pet_turn(ticket: int) -> void:
	if ticket != _turn_ticket or not _is_open:
		return

	_game.pet_move()
	_pet_turn_pending = false
	_render_board()

	var game_result := _game.result()

	if game_result != TicTacToeGame.RESULT_PLAYING:
		_finish_round(game_result)
		return

	_status_label.text = "Lượt của bạn"
	_render_board()


func _finish_round(game_result: StringName) -> void:
	match game_result:
		TicTacToeGame.RESULT_PLAYER:
			_status_label.text = "Bạn thắng!"
			_message_label.text = (
				"Đang nhận Rương Ấu thể..."
				if _reward_enabled and _reward_claimed < _reward_max
				else "Bạn thắng • không còn rương thưởng."
			)

			if _reward_enabled and _reward_claimed < _reward_max:
				caro_win_reward_requested.emit()

		TicTacToeGame.RESULT_PET:
			_status_label.text = "Pet thắng!"
			_message_label.text = "Pet có vẻ khá đắc ý."

		TicTacToeGame.RESULT_DRAW:
			_status_label.text = "Hòa!"
			_message_label.text = "Không mất gì • thử lại ván khác."

	match_finished.emit(game_result)
	_render_board()


func _render_board() -> void:
	var board := _game.board()
	var game_over := _game.result() != TicTacToeGame.RESULT_PLAYING

	for index in range(_cells.size()):
		var cell := _cells[index]
		var value := int(board[index])

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

	_new_round_button.disabled = _pet_turn_pending


func _update_reward_label() -> void:
	var claimed := clampi(_reward_claimed, 0, _reward_max)

	if not _reward_enabled:
		_reward_label.text = "Rương Ấu thể • giai đoạn thưởng đã kết thúc"
		return

	_reward_label.text = "Rương Caro  %d/%d" % [
		claimed,
		_reward_max,
	]


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	return PetHomeTheme.panel_style(Color(palette.get("panel", Color("171229")), bg.a), palette.get("accent", Color("a98af4")))
