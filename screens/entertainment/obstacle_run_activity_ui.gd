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
var _control_label: Label
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
	_message_label.text = "Chạm rồi kéo pet trái/phải để né các vật rơi. Sống sót đủ 40 giây."
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

func show_reward_message(
	message: String,
	rewarded: bool = false
) -> void:
	_message_label.text = message
	_claim_pending = false

	if rewarded:
		_match_rewarded = true

	_reward_button.disabled = false
	_sync_reward()

func _process(delta: float) -> void:
	if _game == null:
		return

	var axis := Input.get_axis("ui_left", "ui_right")
	_game.set_move_axis(axis)
	_game.tick(delta)
	_sync()

	if _game.result() in [ObstacleRunGame.RESULT_WIN, ObstacleRunGame.RESULT_LOSE] and _last_result == &"":
		_finish_match()

func _move_to(world_x: float) -> void:
	if not is_visible_in_tree() or _game == null:
		return
	_game.request_move(world_x)
	if _game.result() == ObstacleRunGame.RESULT_PLAYING:
		_message_label.text = "Kéo trái/phải để né • ← → trên máy tính."
	_sync()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 7)
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
	title.text = "NÉ VẬT RƠI"
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
	_status_label.add_theme_font_size_override("font_size", 12)
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
	_board.move_requested.connect(_move_to)
	root.add_child(_board)

	_control_label = Label.new()
	_control_label.text = "KÉO PET  ←   →  ĐỂ NÉ"
	_control_label.custom_minimum_size.y = 34
	_control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_control_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_control_label.add_theme_font_size_override("font_size", 12)
	root.add_child(_control_label)

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
	_message_label.add_theme_font_size_override("font_size", 11)
	_message_label.add_theme_color_override(
		"font_color",
		palette.get("muted", Color.WHITE)
	)
	root.add_child(_message_label)
	_sync_reward()

func _sync() -> void:
	if _game == null:
		return

	_status_label.text = "♥ %d    %02ds    Né %d    Điểm %d" % [
		_game.lives(),
		int(ceil(_game.time_left())),
		_game.passed(),
		_game.score(),
	]
	_progress.value = _game.elapsed()
	_board.queue_redraw()
	_sync_reward()

func _finish_match() -> void:
	_last_result = _game.result()
	match_finished.emit(_last_result)
	if _last_result == ObstacleRunGame.RESULT_WIN:
		_message_label.text = "Sống sót! Né %d vật rơi • %d điểm." % [
			_game.passed(),
			_game.score(),
		]
	else:
		_message_label.text = "Hết mạng. Chạm ↻ để chơi lại."
	_sync_reward()

func _sync_reward() -> void:
	if _reward_label == null:
		return

	var chest_available := (
		_reward_enabled
		and _reward_claimed < _reward_max
	)

	if chest_available:
		var remaining := maxi(0, _reward_max - _reward_claimed)
		_reward_label.text = (
			"Rương chung Né vật rơi + Snake còn %d/%d"
			% [remaining, _reward_max]
		)
	else:
		_reward_label.text = (
			"Hết/ngoài Stage thưởng rương • thắng = 1 mảnh"
		)

	_reward_button.text = (
		"NHẬN RƯƠNG HOẠT ĐỘNG"
		if chest_available
		else "NHẬN 1 MẢNH RƯƠNG"
	)
	_reward_button.visible = (
		_game != null
		and _game.result() == ObstacleRunGame.RESULT_WIN
		and not _match_rewarded
	)

func _on_reward_pressed() -> void:
	if _game == null or _game.result() != ObstacleRunGame.RESULT_WIN:
		return
	if _match_rewarded or _reward_button.disabled:
		return
	_claim_pending = true
	_reward_button.disabled = true
	reward_requested.emit(_game.score(), _game.match_id())
