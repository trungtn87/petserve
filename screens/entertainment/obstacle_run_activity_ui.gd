class_name ObstacleRunActivityUI
extends Control

signal back_requested
signal reward_requested(score: int, match_id: String)
signal match_finished(result: StringName)

var palette: Dictionary = {}
var _game: ObstacleRunGame
var _board: ObstacleRunBoard
var _status_label: Label
var _message_label: Label
var _reward_label: Label
var _reward_button: Button
var _jump_button: Button
var _progress: ProgressBar
var _reward_claimed: int = 0
var _reward_max: int = 4
var _reward_enabled: bool = false
var _match_rewarded: bool = false
var _claim_pending: bool = false
var _last_result: StringName = &""

func _ready() -> void:
	set_process(false)
	_build_ui()

func open_activity() -> void:
	if _game == null:
		_game = ObstacleRunGame.new()
	else:
		_game.reset()
	_board.set_game(_game)
	_last_result = &""
	_match_rewarded = false
	_claim_pending = false
	_reward_button.disabled = false
	_message_label.text = "Chạm để bắt đầu. Nhảy qua đá, trụ đủ 40 giây để thắng."
	visible = true
	set_process(true)
	_sync()

func close_activity() -> void:
	visible = false
	set_process(false)

func set_reward_status(claimed: int, maximum: int, enabled: bool) -> void:
	if _claim_pending and claimed > _reward_claimed:
		_match_rewarded = true
	_reward_claimed = clampi(claimed, 0, maxi(0, maximum))
	_reward_max = maxi(0, maximum)
	_reward_enabled = enabled
	_sync_reward()

func show_reward_message(message: String) -> void:
	_message_label.text = message
	# PetHome refreshes the persisted count immediately after this callback.
	# Keep the pending flag until that refresh so a successful claim hides the button.
	_reward_button.disabled = false

func _process(delta: float) -> void:
	if _game == null:
		return
	_game.tick(delta)
	_sync()
	if _game.result() in [ObstacleRunGame.RESULT_WIN, ObstacleRunGame.RESULT_LOSE] and _last_result == &"":
		_finish_match()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _game == null:
		return
	if event is InputEventKey and not event.echo and (
		event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_up")
	):
		_jump()
		get_viewport().set_input_as_handled()

func _jump() -> void:
	if not is_visible_in_tree() or _game == null:
		return
	_game.request_jump()
	if _game.result() == ObstacleRunGame.RESULT_PLAYING:
		_message_label.text = "Chạm màn chơi hoặc nút NHẢY • Space / ↑ trên máy tính."
	_sync()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "‹"
	back.custom_minimum_size = Vector2(44, 42)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "VƯỢT CHƯỚNG NGẠI"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	top.add_child(title)
	var restart := Button.new()
	restart.text = "↻"
	restart.custom_minimum_size = Vector2(44, 42)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(open_activity)
	top.add_child(restart)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_status_label)
	_progress = ProgressBar.new()
	_progress.max_value = ObstacleRunGame.ROUND_SECONDS
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 8
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_progress)
	_board = ObstacleRunBoard.new()
	_board.palette = palette
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.jump_requested.connect(_jump)
	root.add_child(_board)
	_jump_button = Button.new()
	_jump_button.text = "CHẠM ĐỂ BẮT ĐẦU"
	_jump_button.custom_minimum_size.y = 60
	_jump_button.focus_mode = Control.FOCUS_NONE
	_jump_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_jump_button.pressed.connect(_jump)
	root.add_child(_jump_button)
	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.add_theme_font_size_override("font_size", 11)
	root.add_child(_reward_label)
	_reward_button = Button.new()
	_reward_button.text = "NHẬN RƯƠNG HOẠT ĐỘNG"
	_reward_button.custom_minimum_size.y = 42
	_reward_button.focus_mode = Control.FOCUS_NONE
	_reward_button.visible = false
	_reward_button.pressed.connect(_on_reward_pressed)
	root.add_child(_reward_button)
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 12)
	_message_label.add_theme_color_override("font_color", palette.get("muted", Color.WHITE))
	root.add_child(_message_label)
	_sync_reward()

func _sync() -> void:
	if _game == null:
		return
	_status_label.text = "♥ %d    %02ds    Điểm %d" % [_game.lives(), int(ceil(_game.time_left())), _game.score()]
	_progress.value = _game.elapsed()
	_jump_button.disabled = _game.result() in [ObstacleRunGame.RESULT_WIN, ObstacleRunGame.RESULT_LOSE]
	_jump_button.text = "CHẠM ĐỂ BẮT ĐẦU" if _game.result() == ObstacleRunGame.RESULT_READY else "NHẢY  ▲"
	_board.queue_redraw()
	_sync_reward()

func _finish_match() -> void:
	_last_result = _game.result()
	match_finished.emit(_last_result)
	if _last_result == ObstacleRunGame.RESULT_WIN:
		_message_label.text = "Về đích! Vượt %d chướng ngại • %d điểm." % [_game.passed(), _game.score()]
	else:
		_message_label.text = "Hết mạng. Chạm ↻ để chơi lại."
	_sync_reward()

func _sync_reward() -> void:
	if _reward_label == null:
		return

	if _reward_enabled:
		var remaining := maxi(
			0,
			_reward_max - _reward_claimed
		)
		_reward_label.text = (
			"Rương chung Vượt chướng ngại + Snake còn %d/%d"
			% [
				remaining,
				_reward_max,
			]
			if remaining > 0
			else "Rương chung Vượt chướng ngại + Snake còn 0/%d • vẫn chơi tự do"
				% _reward_max
		)
	else:
		_reward_label.text = "Chơi tự do • rương hoạt động chỉ có ở Stage 2."

	_reward_button.visible = (
		_game != null and _game.result() == ObstacleRunGame.RESULT_WIN
		and _reward_enabled and _reward_claimed < _reward_max and not _match_rewarded
	)


func _on_reward_pressed() -> void:
	if _game == null or _game.result() != ObstacleRunGame.RESULT_WIN:
		return
	if not _reward_enabled or _reward_claimed >= _reward_max or _match_rewarded or _reward_button.disabled:
		return
	_claim_pending = true
	_reward_button.disabled = true
	reward_requested.emit(_game.score(), _game.match_id())
