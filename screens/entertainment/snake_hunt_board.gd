class_name SnakeHuntBoard
extends Control


signal direction_requested(direction: Vector2i)


var palette: Dictionary = {}
var game: SnakeHuntGame

var _touch_start := Vector2.ZERO
var _tracking_touch: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 320)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func set_game(value: SnakeHuntGame) -> void:
	game = value
	queue_redraw()


func _draw() -> void:
	if game == null:
		return

	var cell_size := minf(
		size.x / float(SnakeHuntGame.GRID_WIDTH),
		size.y / float(SnakeHuntGame.GRID_HEIGHT)
	)
	var board_size := Vector2(
		cell_size * SnakeHuntGame.GRID_WIDTH,
		cell_size * SnakeHuntGame.GRID_HEIGHT
	)
	var origin := (size - board_size) * 0.5
	var panel_color: Color = palette.get(
		"panel",
		Color("171229")
	)
	panel_color.a = 0.96
	var accent: Color = palette.get(
		"accent",
		Color("a98af4")
	)
	var text_color: Color = palette.get(
		"text",
		Color.WHITE
	)

	draw_rect(
		Rect2(origin, board_size),
		panel_color,
		true
	)

	var border := accent
	border.a = 0.65
	draw_rect(
		Rect2(origin, board_size),
		border,
		false,
		maxf(1.0, cell_size * 0.08)
	)

	var food_center := _cell_center(
		game.food_position(),
		origin,
		cell_size
	)
	var food_color := (
		Color(1.0, 0.84, 0.24, 1.0)
		if game.is_gold_food()
		else text_color
	)
	draw_circle(
		food_center,
		cell_size * (
			0.30
			if game.is_gold_food()
			else 0.22
		),
		food_color
	)

	var cells := game.snake_cells()

	for index in range(cells.size() - 1, -1, -1):
		var center := _cell_center(
			cells[index],
			origin,
			cell_size
		)
		var ratio := 1.0 - (
			float(index)
			/ maxf(
				1.0,
				float(cells.size())
			)
		)
		var segment_color := accent
		segment_color.a = 0.48 + ratio * 0.50
		var radius := cell_size * (
			0.34
			if index == 0
			else 0.29
		)
		draw_circle(
			center,
			radius,
			segment_color
		)

		if index == 0:
			var eye_offset := Vector2(
				cell_size * 0.10,
				-cell_size * 0.07
			)
			draw_circle(
				center + eye_offset,
				maxf(
					1.3,
					cell_size * 0.055
				),
				text_color
			)


func _cell_center(
	pos: Vector2i,
	origin: Vector2,
	cell_size: float
) -> Vector2:
	return (
		origin
		+ Vector2(
			pos.x + 0.5,
			pos.y + 0.5
		) * cell_size
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed:
			_touch_start = touch.position
			_tracking_touch = true
		else:
			_finish_swipe(
				touch.position
			)

	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton

		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse.pressed:
			_touch_start = mouse.position
			_tracking_touch = true
		else:
			_finish_swipe(
				mouse.position
			)


func _finish_swipe(end_position: Vector2) -> void:
	if not _tracking_touch:
		return

	_tracking_touch = false
	var delta := end_position - _touch_start

	if delta.length() < 24.0:
		return

	if absf(delta.x) > absf(delta.y):
		direction_requested.emit(
			Vector2i.RIGHT
			if delta.x > 0.0
			else Vector2i.LEFT
		)
	else:
		direction_requested.emit(
			Vector2i.DOWN
			if delta.y > 0.0
			else Vector2i.UP
		)
