class_name CaroActivityUI
extends Control
signal reward_requested(match_id: String)
signal back_requested
signal match_finished(result: StringName)
const CHANNEL := "gomoku-v1"
var palette: Dictionary = {}
var connection: LocalConnectionService
var _game := TicTacToeGame.new()
var _is_open := false
var _mode := 0 # pet / shared device / connected devices
var _thinking := false
var _ticket := 0
var _reward_claimed := 0
var _reward_max := 4
var _reward_enabled := true
var _round_id := ""
var _network_active := false
var _guest_ready := false
var _remote_ready := false
var _finished := false
var _board: GomokuBoard
var _status_label: Label
var _reward_label: Label
var _message_label: Label
var _mode_select: OptionButton
var _place: Button
var _new_round_button: Button
var _zoom := false

func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	if connection == null:
		connection = get_node_or_null("/root/LocalConnection")
	if connection != null:
		connection.message_received.connect(_on_message)
		connection.status_changed.connect(_connection_changed)
	_build_ui()

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",11)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.add_theme_font_size_override("font_size",12)
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation",5)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_button("‹",_back))
	var title := _label("GOMOKU • 15×15")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("Phóng",_toggle_zoom))
	_mode_select = OptionButton.new()
	for text in ["1 người • Đấu với pet", "2 người • Cùng máy", "2 người • Wi-Fi / Bluetooth"]:
		_mode_select.add_item(text)
	_mode_select.item_selected.connect(_change_mode)
	root.add_child(_mode_select)
	root.add_child(_label("Chọn ô → Đặt quân • ≥5 quân thắng"))
	_reward_label = _label("")
	root.add_child(_reward_label)
	_status_label = _label("")
	root.add_child(_status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_board = GomokuBoard.new()
	_board.custom_minimum_size = Vector2(270,270)
	scroll.add_child(_board)
	_board.cell_selected.connect(_select_cell)
	_message_label = _label("")
	root.add_child(_message_label)
	var actions := HBoxContainer.new()
	root.add_child(actions)
	_place = _button("Đặt quân",_place_selected)
	_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_place)
	_new_round_button = _button("Ván mới",_start_new_round)
	_new_round_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_new_round_button)

func open_activity() -> void:
	AudioService.play("open")
	_is_open = true
	visible = true
	_start_new_round()

func close_activity() -> void:
	if _mode == 2 and _is_open:
		_send({"type":"leave", "id":_round_id})
	_ticket += 1
	_thinking = false
	_network_active = false
	_guest_ready = false
	_remote_ready = false
	_round_id = ""
	_is_open = false
	visible = false

func set_reward_status(claimed: int, maximum: int, enabled: bool) -> void:
	_reward_claimed = claimed
	_reward_max = maxi(0, maximum)
	_reward_enabled = enabled
	_update_reward_label()

func show_reward_message(message: String) -> void:
	_message_label.text = message

func _update_reward_label() -> void:
	if _reward_label == null:
		return
	_reward_label.text = "1 rương/ngày • Thêm tối đa 10 mảnh"

func _change_mode(index: int) -> void:
	if _mode == 2:
		_send({"type":"leave", "id":_round_id})
	_mode = index
	_network_active = false
	_guest_ready = false
	_remote_ready = false
	_start_new_round()

func _reset_round() -> void:
	_ticket += 1
	if _mode != 2:
		_round_id = "gomoku_" + Crypto.new().generate_random_bytes(16).hex_encode()
	_game.reset()
	_thinking = false
	_finished = false
	_board.selected = -1
	_update_reward_label()

func _start_new_round() -> void:
	if _mode == 2:
		if connection == null or not connection.connected():
			_abort("Kết nối 2 người trong Giải trí trước, rồi cả hai chọn Gomoku qua mạng.")
			return
		if _network_active and not _finished:
			_message_label.text = "Chơi hết ván hoặc đổi chế độ để rời ván."
			return
		if not connection.is_host:
			_guest_ready = true
			_send({"type":"ready"})
			_message_label.text = "Đã sẵn sàng • Đợi chủ phòng bắt đầu"
			_render_board()
			return
		if not _remote_ready:
			_message_label.text = "Đợi khách chọn chế độ qua mạng và bấm Sẵn sàng."
			_render_board()
			return
		_remote_ready = false
		_round_id = str(Time.get_ticks_usec()) + "-" + str(randi())
		_network_active = _send({"type":"start", "id":_round_id})
		if not _network_active:
			_abort("Không gửi được ván mới. Kết nối lại.")
			return
	_reset_round()
	_message_label.text = "Bạn là Đen" if _mode == 0 or (_mode == 2 and connection.is_host) else ("Bạn là Trắng" if _mode == 2 else "Hai người thay phiên đặt quân")
	_render_board()

func _local_side() -> int:
	return TicTacToeGame.PLAYER if connection.is_host else TicTacToeGame.PET

func _can_place() -> bool:
	return _is_open and not _thinking and _game.result() == TicTacToeGame.RESULT_PLAYING and (_mode == 1 or (_mode == 0 and _game.turn == 1) or (_mode == 2 and _network_active and _game.turn == _local_side()))

func _select_cell(index: int) -> void:
	if _can_place() and _game.board()[index] == 0:
		_board.selected = index
		_render_board()

func _place_selected() -> void:
	var index := _board.selected
	if not _can_place() or index < 0:
		return
	if _mode == 2:
		if connection.is_host:
			_accept_network_move(index,1)
		else:
			if not _send({"type":"move", "id":_round_id, "seq":_game.moves, "index":index}):
				_abort("Không gửi được nước đi. Kết nối lại.")
		return
	if not _game.play(index,_game.turn):
		return
	_after_move()
	if _mode == 0 and not _finished:
		_thinking = true
		_render_board()
		get_tree().create_timer(0.35).timeout.connect(_pet_turn.bind(_ticket),CONNECT_ONE_SHOT)

func _pet_turn(ticket: int) -> void:
	if ticket != _ticket or not _is_open or _mode != 0:
		return
	_game.pet_move()
	_thinking = false
	_after_move()

func _after_move() -> void:
	_board.selected = -1
	if _game.result() != TicTacToeGame.RESULT_PLAYING and not _finished:
		_finished = true
		if _game.result() != TicTacToeGame.RESULT_DRAW:
			_message_label.text = "Đang nhận thưởng..."
			reward_requested.emit(_round_id)
		match_finished.emit(_game.result())
	_render_board()

func _render_board() -> void:
	_board.cells = _game.board()
	_board.last_move = _game.last_move
	_board.winning = _game.winning_cells
	_board.enabled = _can_place()
	_board.queue_redraw()
	_place.disabled = not _can_place() or _board.selected < 0
	_new_round_button.text = "Sẵn sàng" if _mode == 2 and connection != null and not connection.is_host else "Ván mới"
	_status_label.text = "Lượt Đen" if _game.turn == 1 else "Lượt Trắng"
	if _thinking:
		_status_label.text = "Pet đang nghĩ..."
	elif _mode == 2 and not _network_active:
		_status_label.text = "Chờ ván 2 người"
	elif _finished:
		_status_label.text = "Hòa!" if _game.result() == TicTacToeGame.RESULT_DRAW else ("Đen thắng!" if _game.result() == TicTacToeGame.RESULT_PLAYER else "Trắng thắng!")

func _send(data: Dictionary) -> bool:
	return connection != null and connection.send_message(CHANNEL,data)

func _accept_network_move(index: int, side: int) -> void:
	var seq := _game.moves
	if not _game.play(index, side):
		return
	if not _send({"type":"played", "id":_round_id, "seq":seq, "index":index,"side":side}):
		_abort("Mất kết nối • Ván dừng")
		return
	_after_move()

func _on_message(channel: String, data: Dictionary) -> void:
	if channel != CHANNEL or not _is_open or _mode != 2 or connection == null or not connection.connected():
		return
	var kind := str(data.get("type",""))
	if kind == "ready" and connection.is_host and (not _network_active or _finished):
		_remote_ready = true
		_message_label.text = "Khách sẵn sàng • Chủ phòng bấm Ván mới"
	elif kind == "start" and not connection.is_host and _guest_ready and (not _network_active or _finished):
		var id := str(data.get("id",""))
		if id.is_empty() or id.length() > 80:
			return
		_round_id = id
		_guest_ready = false
		_network_active = true
		_reset_round()
		_message_label.text = "Bạn là Trắng • Đợi Đen đi trước"
		_render_board()
	elif kind == "leave":
		_remote_ready = false
		_guest_ready = false
		_abort("Người kia đã rời Gomoku. Bấm Sẵn sàng để chơi lại.")
	elif _network_active and str(data.get("id","")) == _round_id:
		if kind in ["move","played"]:
			for key in ["seq","index"]:
				if not data.get(key) is float and not data.get(key) is int:
					return
				if float(data[key]) != float(int(data[key])):
					return
			if int(data.seq) != _game.moves:
				return
			if kind == "move" and connection.is_host:
				_accept_network_move(int(data.index),2)
			elif kind == "played" and not connection.is_host:
				if int(data.get("side",0)) != _game.turn or not _game.play(int(data.index),_game.turn):
					_abort("Dữ liệu ván không khớp • Chơi lại ván mới")
					return
				_after_move()

func _connection_changed() -> void:
	if _is_open and _mode == 2 and not connection.connected():
		_remote_ready = false
		_guest_ready = false
		_abort("Mất kết nối • Kết nối lại rồi chơi ván mới")

func _abort(message: String) -> void:
	_network_active = false
	_message_label.text = message
	_render_board()

func _toggle_zoom() -> void:
	_zoom = not _zoom
	_board.custom_minimum_size = Vector2(450,450) if _zoom else Vector2(270,270)

func _back() -> void:
	close_activity()
	back_requested.emit()
