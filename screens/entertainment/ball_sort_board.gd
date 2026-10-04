class_name BallSortBoard
extends Control


signal tube_pressed(index: int)


var palette: Dictionary = {}
var _game: BallSortGame
var _tube_rects: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 430)


func set_game(game: BallSortGame) -> void:
	_game = game
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	_tube_rects.clear()
	if _game == null:
		return

	var tubes := _game.tubes()
	if tubes.is_empty():
		return

	var count := tubes.size()
	var columns := 4 if count <= 8 else 5
	if size.x < 390.0:
		columns = 4
	columns = mini(columns, count)
	var rows := int(ceil(float(count) / float(columns)))
	var gap_x := 10.0
	var gap_y := 16.0
	var available_width := maxf(120.0, size.x - gap_x * float(columns - 1) - 8.0)
	var tube_width := minf(72.0, available_width / float(columns))
	var available_height := maxf(180.0, size.y - gap_y * float(rows - 1) - 8.0)
	var tube_height := minf(176.0, available_height / float(rows))
	tube_height = maxf(116.0, tube_height)
	var total_width := tube_width * columns + gap_x * float(columns - 1)
	var total_height := tube_height * rows + gap_y * float(rows - 1)
	var start_x := (size.x - total_width) * 0.5
	var start_y := maxf(2.0, (size.y - total_height) * 0.5)

	for index in range(count):
		var row := int(index / columns)
		var column := index % columns
		var rect := Rect2(
			Vector2(
				start_x + float(column) * (tube_width + gap_x),
				start_y + float(row) * (tube_height + gap_y)
			),
			Vector2(tube_width, tube_height)
		)
		_tube_rects.append(rect)
		_draw_tube(rect, tubes[index] as Array, index == _game.selected_index())


func _draw_tube(rect: Rect2, tube: Array, selected: bool) -> void:
	var panel := StyleBoxFlat.new()
	var panel_color: Color = palette.get("panel", Color("171229"))
	panel_color.a = 0.72
	panel.bg_color = panel_color
	var border: Color = (
		palette.get("accent", Color("a98af4"))
		if selected
		else palette.get("muted", Color("8f86a5"))
	)
	border.a = 0.95 if selected else 0.62
	panel.border_color = border
	panel.set_border_width_all(4 if selected else 2)
	var radius := int(minf(rect.size.x, rect.size.y) * 0.18)
	panel.corner_radius_top_left = radius
	panel.corner_radius_top_right = radius
	panel.corner_radius_bottom_left = radius
	panel.corner_radius_bottom_right = radius
	draw_style_box(panel, rect)

	var padding := 8.0
	var usable_width := rect.size.x - padding * 2.0
	var usable_height := rect.size.y - padding * 2.0
	var ball_radius := minf(
		usable_width * 0.40,
		usable_height / float(BallSortGame.CAPACITY * 2 + 1)
	)
	var step := ball_radius * 2.0 + 3.0
	var center_x := rect.position.x + rect.size.x * 0.5
	var bottom_y := rect.end.y - padding - ball_radius

	for slot in range(tube.size()):
		var color_index := int(tube[slot])
		var center := Vector2(
			center_x,
			bottom_y - float(slot) * step
		)
		draw_circle(center, ball_radius, _ball_color(color_index))
		draw_circle(
			center - Vector2(ball_radius * 0.28, ball_radius * 0.28),
			maxf(2.0, ball_radius * 0.16),
			Color(1, 1, 1, 0.72)
		)


func _gui_input(event: InputEvent) -> void:
	if _game == null:
		return

	var position := Vector2(-1, -1)
	var pressed := false

	if event is InputEventScreenTouch:
		pressed = event.pressed
		position = event.position
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		position = event.position

	if not pressed:
		return

	for index in range(_tube_rects.size()):
		if _tube_rects[index].has_point(position):
			tube_pressed.emit(index)
			accept_event()
			return


func _ball_color(index: int) -> Color:
	var colors := [
		Color("ff5d73"),
		Color("4f9cff"),
		Color("39d98a"),
		Color("ffd447"),
		Color("bb6cff"),
		Color("ff9f43"),
		Color("35d7e8"),
		Color("ff6fd8"),
		Color("e8edf5"),
		Color("7fd35b"),
	]
	return colors[posmod(index, colors.size())]
