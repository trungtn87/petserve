class_name BreakoutActivityUI
extends Control

signal back_requested
signal reward_received
signal match_finished(result: StringName)
var palette: Dictionary = {}
var game_api: InfantGameFacade
var _state: Dictionary = {}
var _progress: Dictionary = {}
var _board: BreakoutBoard
var _info: Label
var _message: Label
var _maps: OptionButton
var _pause: Button
var _play: Button
var _next: Button
var _claim: Button
var _confirm: ConfirmationDialog
var _help: AcceptDialog
var _paused := false
var _running := false
var _target_x := 150.0
var _launch := false
var _clock := 0.0
var _requested_level := 1
var _announced := ""
var _save_error := ""

func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	var background := ColorRect.new()
	background.color = ArcadeTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 6)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(_button("‹", func() -> void: back_requested.emit()))
	var title := _label("PHÁ GẠCH", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_pause = _button("Dừng", _toggle_pause)
	top.add_child(_pause)
	top.add_child(_button("?", _show_help))
	_maps = OptionButton.new()
	_maps.custom_minimum_size.y = 38
	_maps.add_theme_font_size_override("font_size", 13)
	_maps.item_selected.connect(_select_map)
	_maps.get_popup().about_to_popup.connect(func() -> void: _set_paused(true))
	root.add_child(_maps)
	_info = _label("", 12)
	root.add_child(_info)
	_board = BreakoutBoard.new()
	_board.palette = palette
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size.y = 200
	_board.paddle_moved.connect(func(x: float) -> void: _target_x = x)
	_board.launch_requested.connect(func() -> void: _launch = not _paused)
	root.add_child(_board)
	var actions := HBoxContainer.new()
	actions.custom_minimum_size.y = 42
	root.add_child(actions)
	_play = _button("PHÓNG BÓNG", _play_pressed)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_play)
	_claim = _button("NHẬN THƯỞNG", _settle)
	_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_claim)
	_next = _button("MÀN TIẾP", _next_map)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_next)
	_message = _label("Kéo thanh đỡ • Chạm để phóng bóng", 11)
	root.add_child(_message)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Đổi màn chơi?"
	_confirm.dialog_text = "Màn đang chơi sẽ bắt đầu lại. Tiến độ mở màn vẫn giữ."
	_confirm.ok_button_text = "Đổi màn"
	_confirm.cancel_button_text = "Chơi tiếp"
	_confirm.confirmed.connect(func() -> void: _start(_requested_level))
	_confirm.canceled.connect(func() -> void: _sync_maps())
	add_child(_confirm)
	_help = AcceptDialog.new()
	_help.title = "Đỡ bóng phá gạch"
	_help.ok_button_text = "Đã hiểu"
	_help.dialog_text = "Kéo ngón tay trong sân để di chuyển thanh đỡ.\nChạm sân hoặc bấm Phóng bóng để bắt đầu.\nBóng rơi: mất một mạng. Mỗi màn có 3 mạng.\n\nPhá hết gạch màu để mở màn tiếp.\nSố trên gạch là số lần cần đánh trúng.\nGạch xám là thép, không cần phá.\n\nVật phẩm rơi:\nW: thanh đỡ rộng trong 12 giây.\nS: bóng chậm trong 10 giây.\n+: thêm một mạng, tối đa 5 mạng.\n\n30 màn khó dần, có thể chơi lại màn đã mở.\nVượt màn: 1 rương/game/ngày. Chơi thêm 1 mảnh/lần, tối đa 10 mảnh/ngày.\nThoát giữ màn dở. Bấm Tiếp tục khi quay lại."
	add_child(_help)

func open_activity() -> void:
	AudioService.play("open")
	visible = true
	_running = true
	_clock = 0
	_launch = false
	_apply(game_api.open_breakout())
	_target_x = float(_state.get("paddle_x", 150))
	_set_paused(_state.get("status", "ready") == "playing")

func close_activity() -> void:
	if _running and game_api != null:
		_apply(game_api.checkpoint_breakout())
	_running = false
	_launch = false
	_board.release_input()
	_confirm.hide()
	_help.hide()
	visible = false

func _process(delta: float) -> void:
	if not _running or not is_visible_in_tree() or _paused or _confirm.visible or _help.visible or game_api == null or _state.get("status", "") in ["won", "lost"]:
		return
	if Input.is_physical_key_pressed(KEY_LEFT):
		_target_x -= 230 * delta
	if Input.is_physical_key_pressed(KEY_RIGHT):
		_target_x += 230 * delta
	if Input.is_physical_key_pressed(KEY_SPACE) and _state.get("status", "") == "ready":
		_launch = true
	var previous := str(_state.get("status", ""))
	_apply(game_api.tick_breakout(delta, _target_x, _launch))
	_launch = false
	_target_x = float(_state.get("paddle_x", _target_x))
	_clock += delta
	if _clock >= 5 or previous != str(_state.get("status", "")):
		_clock = 0
		_apply(game_api.checkpoint_breakout())

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT] and _running and game_api != null:
		_set_paused(true)

func _apply(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		_state = result.get("state", _state)
		if result.has("progress"):
			_save_error = ""
			_progress = result.progress
			_sync_maps()
		_sync()
	if result.has("message"):
		_message.text = str(result.message)
		if not bool(result.get("ok", false)):
			_save_error = str(result.message)

func _sync_maps() -> void:
	_maps.clear()
	var unlocked := int(_progress.get("unlocked", 1))
	var cleared: Array = _progress.get("cleared", [])
	for level in BreakoutMaps.COUNT:
		_maps.add_item("Màn %02d • %s%s" % [level + 1, BreakoutMaps.NAMES[level % 6], " • Đã vượt" if cleared.has(level + 1) else ""])
		_maps.set_item_disabled(level, level + 1 > unlocked)
	_maps.select(int(_state.get("level", 1)) - 1)

func _sync() -> void:
	if _state.is_empty():
		return
	_board.show_state(_state)
	var status := str(_state.status)
	var remaining := 0
	for brick in _state.bricks:
		if int(brick.hp) > 0:
			remaining += 1
	_info.text = "Màn %d/30 • %d mạng • %d điểm • Còn %d gạch" % [int(_state.level), int(_state.lives), int(_state.score), remaining]
	_play.visible = status in ["ready", "lost"]
	_play.text = "CHƠI LẠI" if status == "lost" else "PHÓNG BÓNG"
	_claim.visible = status == "won" and not bool(_state.settled)
	_next.visible = status == "won" and bool(_state.settled) and int(_state.level) < BreakoutMaps.COUNT
	_pause.disabled = status in ["won", "lost"]
	if status == "won":
		_message.text = "Đã vượt đủ 30 màn! Có thể chọn màn để chơi lại." if int(_state.level) == BreakoutMaps.COUNT and bool(_state.settled) else "Vượt màn! Nhận thưởng rồi chơi màn tiếp."
	elif status == "lost":
		_message.text = "Hết mạng. Bấm Chơi lại để thử tiếp màn này."
	elif _paused:
		_message.text = "Đã tạm dừng • Bấm Tiếp tục để chơi."
	else:
		_message.text = "Kéo để đỡ bóng • W: rộng • S: chậm • +: thêm mạng"
	if not _save_error.is_empty():
		_message.text = _save_error
	if status in ["won", "lost"] and _announced != str(_state.match_id):
		_announced = str(_state.match_id)
		match_finished.emit(&"win" if status == "won" else &"lose")

func _set_paused(value: bool) -> void:
	_paused = value
	_launch = false
	_board.release_input()
	_pause.text = "Tiếp tục" if value else "Dừng"
	if value and game_api != null and _running:
		_apply(game_api.checkpoint_breakout())
	_sync()

func _toggle_pause() -> void:
	_set_paused(not _paused)

func _show_help() -> void:
	_set_paused(true)
	_help.popup_centered(Vector2i(300, 0))

func _play_pressed() -> void:
	if _state.get("status", "") == "lost":
		_start(int(_state.level))
	else:
		_set_paused(false)
		_launch = true

func _select_map(index: int) -> void:
	_requested_level = index + 1
	if _state.get("status", "") == "won" and not bool(_state.get("settled", false)):
		_message.text = "Nhận thưởng trước khi đổi màn."
		_sync_maps()
	elif _state.get("status", "") in ["ready", "playing"]:
		_set_paused(true)
		_confirm.popup_centered(Vector2i(280, 0))
	else:
		_start(_requested_level)

func _start(level: int) -> void:
	var result := game_api.start_breakout(level)
	_apply(result)
	if bool(result.get("ok", false)):
		_target_x = float(_state.paddle_x)
		_set_paused(false)

func _settle() -> void:
	var result := game_api.settle_breakout()
	_apply(result)
	if bool(result.get("ok", false)):
		reward_received.emit()

func _next_map() -> void:
	_start(int(_state.level) + 1)

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
