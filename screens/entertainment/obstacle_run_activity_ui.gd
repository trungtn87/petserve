class_name ObstacleRunActivityUI
extends Control


signal back_requested
signal reward_requested(score: int, match_id: String)
signal match_finished(result: StringName)


var palette: Dictionary = {}
var game_api: InfantGameFacade

var _game: ObstacleRunGame
var _board: ObstacleRunBoard
var _status_label: Label
var _message_label: Label
var _reward_label: Label
var _reward_button: Button
var _control_label: Label
var _ranking: AcceptDialog
var _match_rewarded: bool = false
var _claim_pending: bool = false
var _last_result: StringName = &""


func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(
		self
	)
	set_process(
		false
	)
	_build_ui()


func open_activity() -> void:
	AudioService.play(
		"open"
	)

	if _game == null:
		_game = ObstacleRunGame.new()
	else:
		_game.reset()

	_board.set_game(
		_game
	)
	_last_result = &""
	_match_rewarded = false
	_claim_pending = false
	_reward_button.disabled = false
	_reward_button.visible = false
	_message_label.text = (
		"Ăn vật có viền xanh để lấy điểm. "
		+ "Tránh đá, lon và độc có viền đỏ. "
		+ "Game không giới hạn thời gian."
	)
	visible = true
	set_process(
		true
	)
	_sync()


func close_activity() -> void:
	visible = false
	set_process(
		false
	)


func set_reward_status(
	_claimed: int,
	_maximum: int,
	_enabled: bool
) -> void:
	# Giữ API tương thích với hub cũ. Game mới thưởng độc lập theo điểm.
	_sync_reward()


func show_reward_message(
	message: String,
	rewarded: bool = false
) -> void:
	_message_label.text = message
	_claim_pending = false

	if rewarded:
		_match_rewarded = true
		_reward_button.visible = false
	else:
		_reward_button.disabled = false
		_sync_reward()


func _process(
	delta: float
) -> void:
	if _game == null:
		return

	var axis := Input.get_axis(
		"ui_left",
		"ui_right"
	)
	_game.set_move_axis(
		axis
	)
	_game.tick(
		delta
	)
	_sync()

	if (
		_game.result()
		== ObstacleRunGame.RESULT_LOSE
		and _last_result == &""
	):
		_finish_match()


func _move_to(
	world_x: float
) -> void:
	if (
		not is_visible_in_tree()
		or _game == null
	):
		return

	_game.request_move(
		world_x
	)

	if (
		_game.result()
		== ObstacleRunGame.RESULT_PLAYING
	):
		_message_label.text = (
			"Kéo trái/phải để ăn đồ tốt • tránh vật viền đỏ."
		)

	_sync()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_theme_constant_override(
		"separation",
		7
	)
	add_child(
		root
	)

	var top := HBoxContainer.new()
	top.add_theme_constant_override(
		"separation",
		5
	)
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
		func() -> void:
			back_requested.emit()
	)
	top.add_child(
		back
	)

	var title := Label.new()
	title.text = "ĂN VẬT RƠI"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(
		"font_size",
		14
	)
	top.add_child(
		title
	)

	var ranking := Button.new()
	ranking.text = "BXH"
	ranking.custom_minimum_size = Vector2(
		52,
		42
	)
	ranking.focus_mode = Control.FOCUS_NONE
	ranking.pressed.connect(
		_show_ranking
	)
	top.add_child(
		ranking
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
		12
	)
	root.add_child(
		_status_label
	)

	_board = ObstacleRunBoard.new()
	_board.palette = palette
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.move_requested.connect(
		_move_to
	)
	root.add_child(
		_board
	)

	_control_label = Label.new()
	_control_label.text = "KÉO PET  ←   →  ĂN ĐỒ XANH • TRÁNH ĐỒ ĐỎ"
	_control_label.custom_minimum_size.y = 34
	_control_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_control_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_control_label.add_theme_font_size_override(
		"font_size",
		11
	)
	root.add_child(
		_control_label
	)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.add_theme_font_size_override(
		"font_size",
		10
	)
	_reward_label.text = (
		"Thưởng theo điểm: mỗi 500 điểm = 1 mảnh rương "
		+ "• tối đa 10 mảnh/ván • Top 1 mới +1 rương"
	)
	root.add_child(
		_reward_label
	)

	_reward_button = Button.new()
	_reward_button.text = "NHẬN THƯỞNG"
	_reward_button.custom_minimum_size.y = 42
	_reward_button.focus_mode = Control.FOCUS_NONE
	_reward_button.visible = false
	_reward_button.pressed.connect(
		_request_reward
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

	_ranking = AcceptDialog.new()
	_ranking.title = "Bảng xếp hạng Ăn vật rơi"
	_ranking.ok_button_text = "Đóng"
	add_child(
		_ranking
	)

	_sync_reward()


func _sync() -> void:
	if _game == null:
		return

	_status_label.text = (
		"♥ %d    Ăn %d    Điểm %d"
		% [
			_game.lives(),
			_game.eaten(),
			_game.score(),
		]
	)

	_board.queue_redraw()
	_sync_reward()


func _finish_match() -> void:
	_last_result = _game.result()
	match_finished.emit(
		_last_result
	)
	_message_label.text = (
		"Hết mạng • Ăn %d vật • %d điểm. Đang chốt thưởng..."
		% [
			_game.eaten(),
			_game.score(),
		]
	)
	_request_reward()


func _sync_reward() -> void:
	if (
		_reward_button == null
		or _game == null
	):
		return

	_reward_button.visible = (
		_game.result()
		== ObstacleRunGame.RESULT_LOSE
		and not _match_rewarded
		and not _claim_pending
	)


func _request_reward() -> void:
	if (
		_game == null
		or _game.result()
		!= ObstacleRunGame.RESULT_LOSE
		or _match_rewarded
		or _claim_pending
	):
		return

	_claim_pending = true
	_reward_button.disabled = true
	_reward_button.visible = false
	reward_requested.emit(
		_game.score(),
		_game.match_id()
	)


func _show_ranking() -> void:
	if _ranking == null:
		return

	var records: Dictionary = {}

	if game_api != null:
		records = game_api.obstacle_records()

	var text := "Top 10 trên thiết bị\n\n"
	var entries_value: Variant = records.get(
		"entries",
		[]
	)
	var entries: Array = []

	if typeof(
		entries_value
	) == TYPE_ARRAY:
		entries = entries_value as Array

	if entries.is_empty():
		text += "Chưa có ván hoàn thành."
	else:
		for index in entries.size():
			var entry: Dictionary = entries[index]
			var date := Time.get_datetime_string_from_unix_time(
				int(
					entry.get(
						"at_unix",
						0
					)
				)
			).substr(
				0,
				10
			)
			text += (
				"%d. %d điểm • Ăn %d\n    %s\n"
				% [
					index + 1,
					int(
						entry.get(
							"score",
							0
						)
					),
					int(
						entry.get(
							"eaten",
							0
						)
					),
					date,
				]
			)

	text += (
		"\nTop 1 mới được thưởng thêm 1 rương."
	)
	_ranking.dialog_text = text
	_ranking.popup_centered(
		Vector2i(
			300,
			0
		)
	)
