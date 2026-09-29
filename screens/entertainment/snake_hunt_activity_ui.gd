class_name SnakeHuntActivityUI
extends Control


const SnakeHuntGameScript = preload(
	"res://gameplay/entertainment/snake_hunt_game.gd"
)
const SnakeHuntBoardScript = preload(
	"res://screens/entertainment/snake_hunt_board.gd"
)


signal back_requested
signal reward_requested(score: int)
signal match_finished(result: StringName)


var palette: Dictionary = {}

var _game: SnakeHuntGame
var _board: SnakeHuntBoard
var _status_label: Label
var _message_label: Label
var _reward_label: Label
var _reward_button: Button

var _shared_reward_claimed: int = 0
var _shared_reward_max: int = 4
var _reward_enabled: bool = false
var _last_result: StringName = &""


func _ready() -> void:
	set_process(false)
	_build_ui()


func open_activity() -> void:
	if _game == null:
		_game = SnakeHuntGameScript.new()
	else:
		_game.reset()

	_board.set_game(
		_game
	)
	_last_result = &""
	_message_label.text = (
		"Vuốt để đổi hướng. "
		+ "Ăn đủ 10 mồi, tránh tường và chính đuôi."
	)
	_reward_button.visible = false
	visible = true
	set_process(true)
	_sync()


func close_activity() -> void:
	visible = false
	set_process(false)


func set_reward_status(
	claimed: int,
	maximum: int,
	enabled: bool
) -> void:
	_shared_reward_claimed = clampi(
		claimed,
		0,
		maxi(
			0,
			maximum
		)
	)
	_shared_reward_max = maxi(
		0,
		maximum
	)
	_reward_enabled = enabled
	_update_reward_label()

	if (
		_game != null
		and _game.result()
			== SnakeHuntGame.RESULT_WIN
	):
		_reward_button.visible = (
			_reward_enabled
			and _shared_reward_claimed
				< _shared_reward_max
		)


func show_reward_message(message: String) -> void:
	_message_label.text = message
	_reward_button.disabled = false
	_update_reward_label()


func _process(delta: float) -> void:
	if _game == null:
		return

	if _game.result() == SnakeHuntGame.RESULT_PLAYING:
		_game.tick(
			delta
		)

	_sync()

	if (
		_game.result()
			!= SnakeHuntGame.RESULT_PLAYING
		and _last_result == &""
	):
		_finish_match()


func _input(event: InputEvent) -> void:
	if not visible or _game == null:
		return

	if event.is_action_pressed("ui_left"):
		_game.request_direction(
			Vector2i.LEFT
		)
	elif event.is_action_pressed("ui_right"):
		_game.request_direction(
			Vector2i.RIGHT
		)
	elif event.is_action_pressed("ui_up"):
		_game.request_direction(
			Vector2i.UP
		)
	elif event.is_action_pressed("ui_down"):
		_game.request_direction(
			Vector2i.DOWN
		)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_theme_constant_override(
		"separation",
		8
	)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(
		top
	)

	var back := Button.new()
	back.text = "‹"
	back.custom_minimum_size = Vector2(
		44,
		42
	)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(
		_on_back_pressed
	)
	top.add_child(
		back
	)

	var title := Label.new()
	title.text = "SNAKE HUNT"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(
		"font_size",
		17
	)
	top.add_child(
		title
	)

	var restart := Button.new()
	restart.text = "↻"
	restart.custom_minimum_size = Vector2(
		44,
		42
	)
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(
		open_activity
	)
	top.add_child(
		restart
	)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		_status_label
	)

	_board = SnakeHuntBoardScript.new()
	_board.palette = palette
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.direction_requested.connect(
		_on_direction_requested
	)
	root.add_child(
		_board
	)

	var controls := GridContainer.new()
	controls.columns = 3
	controls.custom_minimum_size.y = 112
	root.add_child(
		controls
	)

	controls.add_child(
		_blank_control()
	)
	controls.add_child(
		_direction_button(
			"▲",
			Vector2i.UP
		)
	)
	controls.add_child(
		_blank_control()
	)
	controls.add_child(
		_direction_button(
			"◀",
			Vector2i.LEFT
		)
	)
	controls.add_child(
		_direction_button(
			"▼",
			Vector2i.DOWN
		)
	)
	controls.add_child(
		_direction_button(
			"▶",
			Vector2i.RIGHT
		)
	)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override(
		"font_size",
		10
	)
	root.add_child(
		_reward_label
	)

	_reward_button = Button.new()
	_reward_button.text = "NHẬN RƯƠNG HOẠT ĐỘNG"
	_reward_button.visible = false
	_reward_button.custom_minimum_size.y = 42
	_reward_button.focus_mode = Control.FOCUS_NONE
	_reward_button.pressed.connect(
		_on_reward_pressed
	)
	root.add_child(
		_reward_button
	)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override(
		"font_size",
		10
	)
	_message_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		_message_label
	)

	_update_reward_label()


func _on_back_pressed() -> void:
	back_requested.emit()


func _direction_button(
	text_value: String,
	direction: Vector2i
) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(
		0,
		50
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(
		func() -> void:
			if _game != null:
				_game.request_direction(
					direction
				)
	)
	return button


func _blank_control() -> Control:
	var blank := Control.new()
	blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return blank


func _on_direction_requested(
	direction: Vector2i
) -> void:
	if _game != null:
		_game.request_direction(
			direction
		)


func _sync() -> void:
	if _game == null:
		return

	_status_label.text = (
		"Điểm %d   Mồi %d/%d   %02ds"
		% [
			_game.score(),
			_game.food_eaten(),
			_game.target_food(),
			int(
				ceil(
					_game.time_left()
				)
			),
		]
	)
	_board.queue_redraw()


func _finish_match() -> void:
	_last_result = _game.result()
	match_finished.emit(
		_last_result
	)

	if _last_result == SnakeHuntGame.RESULT_WIN:
		var tier := _game.reward_tier()
		_message_label.text = (
			"Hoàn thành Snake Hunt • %d điểm • Rương Tier %d"
			% [
				_game.score(),
				tier,
			]
		)
		_reward_button.visible = (
			_reward_enabled
			and _shared_reward_claimed
				< _shared_reward_max
		)
	else:
		_message_label.text = (
			"Rắn va chạm hoặc hết giờ. "
			+ "Chạm ↻ để thử lại."
		)
		_reward_button.visible = false


func _on_reward_pressed() -> void:
	if (
		not _reward_enabled
		or _shared_reward_claimed
			>= _shared_reward_max
		or _game == null
		or _game.result()
			!= SnakeHuntGame.RESULT_WIN
	):
		return

	_reward_button.disabled = true
	reward_requested.emit(
		_game.score()
	)


func _update_reward_label() -> void:
	if _reward_label == null:
		return

	if not _reward_enabled:
		_reward_label.text = (
			"Snake Hunt mở từ Stage 2 • "
			+ "rương thưởng dùng chung quota Stage 2."
		)
		return

	_reward_label.text = (
		"Rương Hoạt động Stage 2 %d/%d"
		% [
			_shared_reward_claimed,
			_shared_reward_max,
		]
	)
