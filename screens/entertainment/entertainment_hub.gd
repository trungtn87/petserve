class_name EntertainmentHubUI
extends Control


const CaroActivityScript = preload(
	"res://screens/entertainment/caro_activity_ui.gd"
)
const ObstacleRunActivityScript = preload(
	"res://screens/entertainment/obstacle_run_activity_ui.gd"
)
const ArcadeGameIconScript = preload(
	"res://screens/entertainment/arcade_game_icon.gd"
)


signal closed
signal breakout_reward_received
signal sudoku_reward_received
signal tetris_reward_received
signal energy_2048_reward_received
signal caro_win_reward_requested(match_id: String)
signal obstacle_reward_requested(score: int, match_id: String)
signal match_finished(result: StringName)


var palette: Dictionary = {}
var pet_image_path := ""
var _jigsaw_activity: JigsawActivityUI
var energy_2048_api: InfantGameFacade
var _energy_2048_activity: Energy2048ActivityUI
var _breakout_activity: BreakoutActivityUI
var _sudoku_activity: SudokuActivityUI
var _tetris_activity: TetrisActivityUI
var _tank_activity: TankActivityUI
var _ball_sort_activity: BallSortActivityUI

var _is_open: bool = false
var _stage_index: int = 1

var _caro_reward_claimed: int = 0
var _caro_reward_max: int = 4
var _caro_reward_enabled: bool = true

var _stage2_reward_claimed: int = 0
var _stage2_reward_max: int = 4
var _stage2_reward_enabled: bool = false

var _hub_screen: Control
var _caro_activity
var _obstacle_activity
var _obstacle_card: Button
var _reward_label: Label


func _ready() -> void:
	palette = ArcadeTheme.palette()
	ArcadeTheme.polish.call_deferred(self)
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func open_hub(
	caro_claimed: int,
	caro_max: int,
	caro_enabled: bool,
	stage_index: int = 1,
	stage2_claimed: int = 0,
	stage2_max: int = 4,
	stage2_enabled: bool = false
) -> void:
	# The hub can be opened after inventory or the side drawer, both of which
	# may have moved themselves to the front. Re-front the hub every time.
	show()
	move_to_front()
	AudioService.play("open")
	_caro_reward_claimed = caro_claimed
	_caro_reward_max = maxi(
		0,
		caro_max
	)
	_caro_reward_enabled = caro_enabled
	_stage_index = maxi(
		1,
		stage_index
	)
	_stage2_reward_claimed = stage2_claimed
	_stage2_reward_max = maxi(
		0,
		stage2_max
	)
	_stage2_reward_enabled = stage2_enabled
	_sync_reward_state()
	_show_hub_screen()
	visible = true
	_is_open = true


func close_hub() -> void:
	var was_open := _is_open
	if was_open:
		AudioService.play("close")
	if _breakout_activity != null:
		_breakout_activity.close_activity()

	if _jigsaw_activity != null:
		_jigsaw_activity.close_activity()
	if _sudoku_activity != null:
		_sudoku_activity.close_activity()
	if _tank_activity != null:
		_tank_activity.close_activity()
	if _tetris_activity != null:
		_tetris_activity.close_activity()
	if _ball_sort_activity != null:
		_ball_sort_activity.close_activity()

	if _caro_activity != null:
		_caro_activity.close_activity()

	if _obstacle_activity != null:
		_obstacle_activity.close_activity()


	if _energy_2048_activity != null:
		_energy_2048_activity.close_activity()

	visible = false
	_is_open = false
	if was_open:
		closed.emit()


func is_open() -> bool:
	return _is_open


func set_reward_status(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool
) -> void:
	_caro_reward_claimed = reward_claimed
	_caro_reward_max = maxi(
		0,
		reward_max
	)
	_caro_reward_enabled = reward_enabled
	_sync_reward_state()


func set_stage2_reward_status(
	reward_claimed: int,
	reward_max: int,
	reward_enabled: bool,
	stage_index: int
) -> void:
	_stage2_reward_claimed = reward_claimed
	_stage2_reward_max = maxi(
		0,
		reward_max
	)
	_stage2_reward_enabled = reward_enabled
	_stage_index = maxi(
		1,
		stage_index
	)
	_sync_reward_state()


func show_reward_message(
	message: String
) -> void:
	if _caro_activity != null:
		_caro_activity.show_reward_message(
			message
		)


func show_obstacle_reward_message(
	message: String,
	rewarded: bool = false
) -> void:
	if _obstacle_activity != null:
		_obstacle_activity.show_reward_message(
			message,
			rewarded
		)


func _build_ui() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	scrim.color = Color(
		0.015,
		0.01,
		0.03,
		0.94
	)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(
		scrim
	)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_top = 0.06
	panel.anchor_right = 0.95
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override(
		"panel",
		_style(
			Color(
				0.07,
				0.045,
				0.13,
				0.99
			),
			Color(
				0.55,
				0.42,
				0.80,
				0.96
			)
		)
	)
	add_child(
		panel
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		16
	)
	margin.add_theme_constant_override(
		"margin_top",
		14
	)
	margin.add_theme_constant_override(
		"margin_right",
		16
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		14
	)
	panel.add_child(
		margin
	)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(
		root
	)

	var header := HBoxContainer.new()
	root.add_child(
		header
	)

	var title := Label.new()
	title.text = "GIẢI TRÍ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(
		"font_size",
		19
	)
	header.add_child(
		title
	)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(
		44,
		44
	)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(
		close_hub
	)
	header.add_child(
		close
	)

	var body := Control.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(
		body
	)

	_build_hub_screen(
		body
	)
	_build_caro_activity(
		body
	)
	_build_obstacle_activity(
		body
	)
	_build_energy_2048_activity(body)
	_build_breakout_activity()

	_build_jigsaw_activity(body)
	_build_sudoku_activity(body)
	_build_tetris_activity(body)
	_build_tank_activity(body)
	_build_ball_sort_activity(body)


func _build_hub_screen(
	parent: Control
) -> void:
	_hub_screen = Control.new()
	parent.add_child(
		_hub_screen
	)
	_hub_screen.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var root := VBoxContainer.new()
	_hub_screen.add_child(
		root
	)
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.add_theme_constant_override(
		"separation",
		10
	)

	var intro := Label.new()
	intro.text = "Chọn một hoạt động để chơi cùng pet."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override(
		"font_size",
		12
	)
	intro.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		intro
	)

	var game_label := Label.new()
	game_label.text = "TRÒ CHƠI"
	game_label.add_theme_font_size_override(
		"font_size",
		11
	)
	game_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		game_label
	)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(
		"h_separation",
		6
	)
	grid.add_theme_constant_override(
		"v_separation",
		6
	)
	root.add_child(grid)

	grid.add_child(
		_activity_card(
			"Caro",
			"15×15",
			true,
			_open_caro,
			&"caro"
		)
	)

	_obstacle_card = _activity_card(
		"Đồ rơi",
		"Vô hạn • BXH",
		true,
		_open_obstacle,
		&"obstacle"
	)
	grid.add_child(
		_obstacle_card
	)


	grid.add_child(
		_activity_card(
			"2048",
			"Ghép số",
			true,
			_open_energy_2048,
			&"2048"
		)
	)

	grid.add_child(_activity_card("Phá gạch", "30 màn", true, _open_breakout, &"breakout"))

	grid.add_child(_activity_card("Ghép hình", "50 • 100 • 200", true, _open_jigsaw, &"jigsaw"))

	grid.add_child(_activity_card("Sudoku", "9×9", true, _open_sudoku, &"sudoku"))

	grid.add_child(_activity_card("Tetris", "Vô hạn • BXH", true, _open_tetris, &"tetris"))

	grid.add_child(_activity_card("Xe tăng", "20 map", true, _open_tank, &"tank"))

	grid.add_child(_activity_card("Tinh thể", "Map vô hạn", true, _open_ball_sort, &"crystal"))

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_label.add_theme_font_size_override(
		"font_size",
		11
	)
	_reward_label.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	root.add_child(
		_reward_label
	)


func _build_caro_activity(
	parent: Control
) -> void:
	_caro_activity = CaroActivityScript.new()
	_caro_activity.palette = palette
	parent.add_child(
		_caro_activity
	)
	_caro_activity.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_caro_activity.visible = false
	_caro_activity.reward_requested.connect(
		_on_caro_reward_requested
	)
	_caro_activity.back_requested.connect(
		_show_hub_screen
	)
	_caro_activity.match_finished.connect(
		_on_match_finished
	)


func _build_obstacle_activity(
	parent: Control
) -> void:
	_obstacle_activity = ObstacleRunActivityScript.new()
	_obstacle_activity.palette = palette
	parent.add_child(
		_obstacle_activity
	)
	_obstacle_activity.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_obstacle_activity.visible = false
	_obstacle_activity.reward_requested.connect(
		_on_obstacle_reward_requested
	)
	_obstacle_activity.back_requested.connect(
		_show_hub_screen
	)
	_obstacle_activity.match_finished.connect(
		_on_match_finished
	)


func _activity_card(
	title_text: String,
	subtitle_text: String,
	enabled: bool,
	callback: Callable,
	icon_kind: StringName
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(
		0,
		72
	)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not enabled
	button.add_theme_stylebox_override(
		"normal",
		_style(
			Color(
				0.11,
				0.07,
				0.18,
				0.97
			),
			Color(
				0.55,
				0.42,
				0.80,
				0.82
			)
		)
	)

	if callback.is_valid():
		button.pressed.connect(
			callback
		)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(
		"separation",
		2
	)
	button.add_child(
		content
	)

	var icon = ArcadeGameIconScript.new()
	icon.custom_minimum_size = Vector2(
		28,
		28
	)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.configure(
		icon_kind,
		palette.get(
			"accent",
			Color.WHITE
		),
		palette.get(
			"muted",
			Color(0.72, 0.68, 0.82)
		)
	)
	content.add_child(
		icon
	)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 20
	title.add_theme_font_size_override(
		"font_size",
		10
	)
	content.add_child(
		title
	)

	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(
		"font_size",
		7
	)
	subtitle.add_theme_color_override(
		"font_color",
		palette.get(
			"muted",
			Color.WHITE
		)
	)
	content.add_child(
		subtitle
	)
	button.set_meta(
		"subtitle_label",
		subtitle
	)

	return button


func _open_caro() -> void:
	_hide_activities()

	if _hub_screen != null:
		_hub_screen.visible = false

	if _caro_activity != null:
		_caro_activity.set_reward_status(
			_caro_reward_claimed,
			_caro_reward_max,
			_caro_reward_enabled
		)
		_caro_activity.open_activity()


func _open_obstacle() -> void:
	_hide_activities()

	if _hub_screen != null:
		_hub_screen.visible = false

	if _obstacle_activity != null:
		_obstacle_activity.game_api = energy_2048_api
		_obstacle_activity.set_reward_status(
			_stage2_reward_claimed,
			_stage2_reward_max,
			_stage2_reward_enabled
		)
		_obstacle_activity.open_activity()


func _show_hub_screen() -> void:
	if _is_open and _hub_screen != null and not _hub_screen.visible:
		AudioService.play("close")
	_hide_activities()

	if _hub_screen != null:
		_hub_screen.visible = true

	_sync_reward_state()


func _hide_activities() -> void:
	if _breakout_activity != null:
		_breakout_activity.close_activity()

	if _jigsaw_activity != null:
		_jigsaw_activity.close_activity()
	if _sudoku_activity != null:
		_sudoku_activity.close_activity()
	if _tank_activity != null:
		_tank_activity.close_activity()
	if _tetris_activity != null:
		_tetris_activity.close_activity()
	if _ball_sort_activity != null:
		_ball_sort_activity.close_activity()

	if _energy_2048_activity != null:
		_energy_2048_activity.close_activity()

	if _caro_activity != null:
		_caro_activity.close_activity()

	if _obstacle_activity != null:
		_obstacle_activity.close_activity()



func _sync_reward_state() -> void:
	if _caro_activity != null:
		_caro_activity.set_reward_status(
			_caro_reward_claimed,
			_caro_reward_max,
			_caro_reward_enabled
		)

	for activity in [
		_obstacle_activity,
	]:
		if activity != null:
			activity.set_reward_status(
				_stage2_reward_claimed,
				_stage2_reward_max,
				_stage2_reward_enabled
			)

	_update_stage2_card_subtitles()
	_update_hub_reward_label()


func _update_stage2_card_subtitles() -> void:
	_set_card_subtitle(
		_obstacle_card,
		"500 điểm = 1 mảnh • Top 1 mới +1 rương"
	)


func _set_card_subtitle(
	card: Button,
	text: String
) -> void:
	if card == null:
		return

	var label = card.get_meta(
		"subtitle_label",
		null
	) as Label

	if label != null:
		label.text = text


func _update_hub_reward_label() -> void:
	if _reward_label == null:
		return

	_reward_label.text = (
		"Phần lớn mini game dùng thưởng hằng ngày.\n"
		+ "Ăn vật rơi: thưởng riêng theo điểm, Top 1 mới +1 rương."
	)


func _on_caro_reward_requested(match_id: String) -> void:
	caro_win_reward_requested.emit(match_id)


func _on_obstacle_reward_requested(
	score: int,
	match_id: String
) -> void:
	obstacle_reward_requested.emit(
		score,
		match_id
	)


func _on_match_finished(
	result: StringName
) -> void:
	match_finished.emit(
		result
	)


func _style(
	bg: Color,
	border: Color
) -> StyleBoxFlat:
	return PetHomeTheme.panel_style(
		Color(
			palette.get(
				"panel",
				ArcadeTheme.BG
			),
			bg.a
		),
		palette.get(
			"accent",
			ArcadeTheme.ACCENT
		)
	)


func _build_energy_2048_activity(parent: Control) -> void:
	_energy_2048_activity = Energy2048ActivityUI.new()
	_energy_2048_activity.palette = palette
	parent.add_child(_energy_2048_activity)
	_energy_2048_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_energy_2048_activity.visible = false
	_energy_2048_activity.back_requested.connect(_show_hub_screen)
	_energy_2048_activity.reward_received.connect(func() -> void: energy_2048_reward_received.emit())
	_energy_2048_activity.match_finished.connect(_on_match_finished)


func _open_energy_2048() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_energy_2048_activity.game_api = energy_2048_api
	_energy_2048_activity.open_activity()


func _build_tetris_activity(parent: Control) -> void:
	_tetris_activity = TetrisActivityUI.new()
	_tetris_activity.palette = palette
	parent.add_child(_tetris_activity)
	_tetris_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tetris_activity.visible = false
	_tetris_activity.back_requested.connect(_show_hub_screen)
	_tetris_activity.reward_received.connect(func() -> void: tetris_reward_received.emit())
	_tetris_activity.match_finished.connect(_on_match_finished)

func _open_tetris() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_tetris_activity.game_api = energy_2048_api
	_tetris_activity.open_activity()


func _open_connection() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Kết nối 2 người"
	dialog.ok_button_text = "Đóng"
	dialog.dialog_hide_on_ok = true
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var panel := LocalConnectionPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(300, 430))


func _build_tank_activity(parent: Control) -> void:
	_tank_activity = TankActivityUI.new()
	add_child(_tank_activity)
	_tank_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tank_activity.visible = false
	_tank_activity.back_requested.connect(_show_hub_screen)
	_tank_activity.reward_received.connect(func() -> void: tetris_reward_received.emit())
	_tank_activity.match_finished.connect(_on_match_finished)

func _open_tank() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_tank_activity.game_api = energy_2048_api
	_tank_activity.open_activity()


func _build_sudoku_activity(parent: Control) -> void:
	_sudoku_activity = SudokuActivityUI.new()
	_sudoku_activity.palette = palette
	parent.add_child(_sudoku_activity)
	_sudoku_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sudoku_activity.visible = false
	_sudoku_activity.back_requested.connect(_show_hub_screen)
	_sudoku_activity.reward_received.connect(func() -> void: sudoku_reward_received.emit())
	_sudoku_activity.match_finished.connect(_on_match_finished)

func _open_sudoku() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_sudoku_activity.game_api = energy_2048_api
	_sudoku_activity.open_activity()


func _build_breakout_activity() -> void:
	_breakout_activity = BreakoutActivityUI.new()
	_breakout_activity.palette = palette
	add_child(_breakout_activity)
	_breakout_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_breakout_activity.visible = false
	_breakout_activity.back_requested.connect(_show_hub_screen)
	_breakout_activity.reward_received.connect(func() -> void: breakout_reward_received.emit())
	_breakout_activity.match_finished.connect(_on_match_finished)

func _open_breakout() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_breakout_activity.game_api = energy_2048_api
	_breakout_activity.open_activity()

func _build_jigsaw_activity(parent: Control) -> void:
	_jigsaw_activity = JigsawActivityUI.new()
	_jigsaw_activity.palette = palette
	parent.add_child(_jigsaw_activity)
	_jigsaw_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_jigsaw_activity.visible = false
	_jigsaw_activity.back_requested.connect(_show_hub_screen)
	_jigsaw_activity.match_finished.connect(_on_match_finished)

func _open_jigsaw() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_jigsaw_activity.game_api = energy_2048_api
	_jigsaw_activity.current_image_path = pet_image_path
	_jigsaw_activity.open_activity()


func _build_ball_sort_activity(parent: Control) -> void:
	_ball_sort_activity = BallSortActivityUI.new()
	_ball_sort_activity.palette = palette
	parent.add_child(_ball_sort_activity)
	_ball_sort_activity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ball_sort_activity.visible = false
	_ball_sort_activity.back_requested.connect(_show_hub_screen)
	_ball_sort_activity.match_finished.connect(_on_match_finished)


func _open_ball_sort() -> void:
	_hide_activities()
	_hub_screen.visible = false
	_ball_sort_activity.game_api = energy_2048_api
	_ball_sort_activity.open_activity()
