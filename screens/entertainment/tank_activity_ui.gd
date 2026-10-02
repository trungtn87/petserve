class_name TankActivityUI
extends Control
signal back_requested
signal reward_received
signal match_finished(result: StringName)
var palette: Dictionary = {}
var game_api: InfantGameFacade
var connection: LocalConnectionService
var session: TankSession
var _state: Dictionary = {}
var _maps: Array = TankMaps.all_maps()
var _board: TankBoard
var _controls: TankHandheldControls
var _info: Label
var _message: Label
var _start: Button
var _single: Button
var _claim: Button
var _pause: Button
var _duo := false
var _running := false
var _paused := false
var _slot := 0
var _direction := -1
var _held: Array = []
var _fire := false
var _send_clock := 0.0
var _remote_age := 0.0
var _peer_in_tank := false
var _guest_ready := false
var _accepted := ""
var _settled_id := ""
var _confirm: ConfirmationDialog
var _ranking: AcceptDialog

func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	if connection == null:
		connection = get_node_or_null("/root/LocalConnection")
	if connection != null:
		connection.message_received.connect(_on_message)
		connection.status_changed.connect(_connection_changed)
	var background := ColorRect.new()
	background.color = ArcadeTheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 8
	root.offset_right = -8
	root.offset_top = 8
	root.offset_bottom = -8
	root.add_theme_constant_override("separation",5)
	var header := HBoxContainer.new()
	root.add_child(header)
	header.add_child(_button("‹",_back))
	var title := Label.new()
	title.text = "TANK • BẢO VỆ CĂN CỨ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size",12)
	header.add_child(title)
	header.add_child(_button("Top",_show_ranking))
	_pause = _button("Dừng",_toggle_pause)
	header.add_child(_pause)
	_info = _label("20 map • Vào trận chọn ngẫu nhiên")
	root.add_child(_info)
	var board_space := Control.new()
	board_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board_space)
	_board = TankBoard.new()
	board_space.add_child(_board)
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message = _label("Chơi đơn 5 mạng • Căn cứ 3 HP • Bảo vệ ★ • 1 rương/ngày • Chơi thêm tối đa 10 mảnh")
	root.add_child(_message)
	var modes := HBoxContainer.new()
	root.add_child(modes)
	_single = _button("1 người",func(): _begin(false))
	_single.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(_single)
	_start = _button("2 người",_duo_start)
	_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modes.add_child(_start)
	_claim = _button("Nhận thưởng",_settle)
	_claim.visible = false
	modes.add_child(_claim)
	_controls = TankHandheldControls.new()
	root.add_child(_controls)
	_controls.action_pressed.connect(_press)
	_controls.action_released.connect(_release)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Rời ván sẽ không nhận thưởng."
	_confirm.ok_button_text = "Rời ván"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(_leave)
	add_child(_confirm)
	_ranking = AcceptDialog.new()
	_ranking.title = "TOP 10 • TRÊN THIẾT BỊ"
	add_child(_ranking)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",11)
	return label

func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(32,36)
	b.add_theme_font_size_override("font_size",11)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b

func open_activity() -> void:
	AudioService.play("open")
	visible = true
	_reset_inputs()
	if connection != null and connection.connected():
		_send({"type":"enter"})
		_message.text = "Hai máy mở Tank • Khách bấm Sẵn sàng • Chủ bấm Bắt đầu"
	_sync_modes()

func close_activity() -> void:
	if _duo and _running:
		_send({"type":"leave", "id":_accepted})
	_send({"type":"exit"})
	_peer_in_tank = false
	_guest_ready = false
	_running = false
	_duo = false
	_accepted = ""
	visible = false
	_claim.visible = false
	_reset_inputs()
	if _confirm != null:
		_confirm.hide()
		_ranking.hide()

func _sync_modes() -> void:
	_single.disabled = _running
	_start.disabled = _running
	_start.text = "2 người"
	if connection != null and connection.connected():
		_start.text = "Bắt đầu đôi" if connection.is_host else "Sẵn sàng"
	_pause.disabled = not _running

func _duo_start() -> void:
	if connection == null or not connection.connected():
		_message.text = "Mở Kết nối 2 người trong Giải trí trước, rồi cả hai mở Tank."
		return
	if not connection.is_host:
		_guest_ready = true
		_send({"type":"ready"})
		_message.text = "Đã sẵn sàng • Đợi chủ phòng bắt đầu"
	elif not _peer_in_tank:
		_message.text = "Đợi máy khách mở Tank và bấm Sẵn sàng."
	else:
		_begin(true)

func _begin(two_players: bool) -> void:
	_duo = two_players
	_slot = 0
	_paused = false
	_settled_id = ""
	session = TankSession.new()
	session.start(two_players)
	_accepted = session.match_id
	_running = true
	_remote_age = 0
	_state = session.snapshot()
	_claim.visible = false
	if _duo:
		_peer_in_tank = false
		_send({"type":"start","state":_state})
	_sync_modes()
	_render()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_controls.set_enabled(_running and not _paused and not _confirm.visible and not _ranking.visible)
	if not _running:
		return
	if _duo:
		_remote_age += delta
		if _remote_age > 4.0:
			_abort("Trận đã dừng: không nhận được dữ liệu máy còn lại. Không tính thưởng.")
			return
	_send_clock += delta
	var blocked := _paused or _confirm.visible or _ranking.visible
	if _slot == 0:
		session.set_input(0,-1 if blocked else _direction,_fire and not blocked)
		if not blocked:
			session.tick(delta)
		_state = session.snapshot()
		if _duo and _send_clock >= 0.1:
			_send_clock = 0
			_send({"type":"state","state":_state, "paused":blocked})
	else:
		if _send_clock >= 0.05:
			_send_clock = 0
			_send({"type":"input","id":_accepted,"dir":-1 if blocked else _direction,"fire":_fire and not blocked})
	_render()
	if str(_state.get("status","")) == "lost":
		_running = false
		_reset_inputs()
		if _duo and _slot == 0:
			_send({"type":"end","state":_state})
		_claim.visible = true
		_sync_modes()
		_single.disabled = true
		_start.disabled = true
		_message.text = "Kết thúc • Bấm Nhận thưởng (điểm riêng / 1.000)"
		match_finished.emit(&"lose")
		_settle()

func _send(payload: Dictionary) -> void:
	if connection != null:
		connection.send_message("tank-v1",payload)

func _on_message(channel: String, data: Dictionary) -> void:
	if channel != "tank-v1" or not is_visible_in_tree():
		return
	var kind := str(data.get("type",""))
	if kind == "enter":
		_send({"type":"hello"})
	elif kind == "ready" and connection.is_host and not _running:
		_peer_in_tank = true
		_message.text = "Máy khách đã sẵn sàng • Bấm Bắt đầu đôi"
	elif kind == "exit":
		_peer_in_tank = false
		if _duo and _running:
			_abort("Người kia đã rời Tank. Ván dừng, không nhận thưởng.")
	elif kind == "start" and not connection.is_host and _guest_ready and not _running and not _claim.visible:
		if not _valid_state(data.get("state")):
			return
		_guest_ready = false
		_duo = true
		_slot = 1
		_state = data.state
		_accepted = str(_state.match_id)
		_settled_id = ""
		_remote_age = 0
		_running = true
		_paused = false
		_sync_modes()
		_render()
	elif kind == "input" and _running and _duo and connection.is_host and str(data.get("id")) == _accepted:
		_remote_age = 0
		session.set_input(1,int(data.get("dir",-1)),data.get("fire",false) == true)
	elif kind in ["state","end"] and _running and _duo and not connection.is_host:
		if _valid_state(data.get("state")) and str(data.state.match_id) == _accepted:
			_remote_age = 0
			_state = data.state
			_paused = bool(data.get("paused",false))
	elif kind == "leave" and _duo and str(data.get("id")) == _accepted:
		_abort("Người kia đã rời ván. Không nhận thưởng.")

func _valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("duo") != true or not value.get("tiles") is Array or value.tiles.size() != 256:
		return false
	if not value.get("players") is Array or value.players.size() != 2 or int(value.get("map_index",-1)) not in range(20):
		return false
	for key in ["enemies", "bullets", "pickups", "effects"]:
		if not value.get(key) is Array:
			return false
	for key in ["match_id", "status", "wave", "remaining", "fort", "frozen", "team_score"]:
		if not value.has(key):
			return false
	return str(value.status) in ["playing", "lost"]

func _connection_changed() -> void:
	if _duo and _running and not connection.connected():
		_abort("Mất kết nối • Ván dừng, không nhận thưởng. Kết nối lại để chơi ván mới.")
	_sync_modes()

func _abort(text: String) -> void:
	_running = false
	_peer_in_tank = false
	_guest_ready = false
	_claim.visible = false
	_reset_inputs()
	_message.text = text
	_sync_modes()

func _render() -> void:
	if _state.is_empty():
		return
	_board.show_state(_state)
	var stats := ""
	for i in _state.players.size():
		var p: Dictionary = _state.players[i]
		stats += "P%d: %d♥ %dđ  " % [i+1,int(p.lives),int(p.score)]
	_info.text = "Màn %d • %s\n%s • Địch %d" % [int(_state.wave),str(_maps[int(_state.map_index)].name),stats,int(_state.remaining)+_state.enemies.size()]
	_info.text += " • Căn cứ %d HP" % int(_state.get("base_hp",1))
	_pause.text = "Tiếp" if _paused else "Dừng"
	if _running:
		_message.text = "Đang tạm dừng" if _paused else "Bảo vệ ★ • + súng / S khiên / F đóng băng / B bom / H căn cứ"

func _settle() -> void:
	if game_api == null or str(_state.get("status","")) != "lost" or _accepted == _settled_id:
		return
	var result := game_api.settle_tank(_state,_slot)
	_message.text = str(result.get("message",""))
	if bool(result.get("ok",false)):
		_settled_id = _accepted
		_claim.visible = false
		_sync_modes()
		reward_received.emit()

func _toggle_pause() -> void:
	if _duo and _slot != 0:
		_message.text = "Chủ phòng điều khiển tạm dừng trận đôi."
		return
	_paused = not _paused
	_reset_inputs()

func _reset_inputs() -> void:
	_held.clear()
	_direction = -1
	_fire = false
	if _controls != null:
		_controls.release_all()

func _press(action: String) -> void:
	if action == "fire":
		_fire = true
	else:
		_held.erase(action)
		_held.append(action)
		_direction = ["up","right","down","left"].find(action)

func _release(action: String) -> void:
	if action == "fire":
		_fire = false
	else:
		_held.erase(action)
		_direction = -1 if _held.is_empty() else ["up","right","down","left"].find(_held.back())

func _back() -> void:
	_reset_inputs()
	if _running or _claim.visible:
		_confirm.popup_centered(Vector2i(280,0))
	else:
		_leave()

func _leave() -> void:
	close_activity()
	back_requested.emit()

func _show_ranking() -> void:
	_reset_inputs()
	var records := game_api.tank_records(_duo) if game_api != null else {}
	var text := "Chơi đôi" if _duo else "Chơi đơn"
	text += " • Top 1: %d\n" % int(records.get("best_score",5000))
	for entry in records.get("entries",[]):
		text += "%d điểm • Màn %d\n" % [int(entry.score),int(entry.wave)]
	_ranking.dialog_text = text + "\nMọi chế độ: chung 1 rương và tối đa 10 mảnh/ngày."
	_ranking.popup_centered(Vector2i(280,0))

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or event.is_echo():
		return
	var key := event as InputEventKey
	var actions := {KEY_UP:"up",KEY_RIGHT:"right",KEY_DOWN:"down",KEY_LEFT:"left",KEY_SPACE:"fire"}
	if actions.has(key.keycode) and _running and not _paused:
		if key.pressed:
			_press(actions[key.keycode])
		else:
			_release(actions[key.keycode])
		get_viewport().set_input_as_handled()
