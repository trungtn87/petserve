class_name MazeHuntBoard
extends Control


signal direction_requested(direction: Vector2i)


var palette: Dictionary = {}
var game: MazeHuntGame

var _touch_start := Vector2.ZERO
var _tracking_touch: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 310)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func set_game(value: MazeHuntGame) -> void:
	game = value
	queue_redraw()


func _draw() -> void:
	if game == null:
		return

	var cell_size := minf(
		size.x / float(game.width()),
		size.y / float(game.height())
	)
	var board_size := Vector2(
		cell_size * game.width(),
		cell_size * game.height()
	)
	var origin := (size - board_size) * 0.5
	var panel_color: Color = palette.get(
		"panel",
		Color("171229")
	)
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
		Color(panel_color, 0.96),
		true
	)

	for y in range(game.height()):
		for x in range(game.width()):
			var pos := Vector2i(x, y)
			var rect := Rect2(
				origin + Vector2(x, y) * cell_size,
				Vector2.ONE * cell_size
			)

			if game.is_wall(pos):
				var wall_color := accent
				wall_color.a = 0.56
				draw_rect(
					rect.grow(-cell_size * 0.10),
					wall_color,
					true
				)
				continue

			var center := rect.get_center()

			if game.has_power_orb(pos):
				draw_circle(
					center,
					maxf(3.5, cell_size * 0.22),
					text_color
				)
			elif game.has_orb(pos):
				var orb_color := text_color
				orb_color.a = 0.72
				draw_circle(
					center,
					maxf(1.6, cell_size * 0.08),
					orb_color
				)

	var pet_center := _cell_center(
		game.player_position(),
		origin,
		cell_size
	)
	var pet_color := accent

	if game.power_left() > 0.0:
		draw_circle(
			pet_center,
			cell_size * 0.46,
			Color(accent, 0.22)
		)

	draw_circle(
		pet_center,
		cell_size * 0.33,
		pet_color
	)
	draw_circle(
		pet_center + Vector2(cell_size * 0.10, -cell_size * 0.07),
		maxf(1.3, cell_size * 0.055),
		text_color
	)

	var enemies := game.enemy_positions()

	for index in range(enemies.size()):
		var enemy_center := _cell_center(
			enemies[index],
			origin,
			cell_size
		)
		var enemy_color := Color(
			0.95,
			0.34 + 0.18 * float(index),
			0.62,
			1.0
		)

		if game.power_left() > 0.0:
			enemy_color = Color(
				0.40,
				0.72,
				1.0,
				0.92
			)

		draw_circle(
			enemy_center,
			cell_size * 0.31,
			enemy_color
		)
		draw_circle(
			enemy_center + Vector2(-cell_size * 0.09, -cell_size * 0.05),
			maxf(1.2, cell_size * 0.05),
			text_color
		)
		draw_circle(
			enemy_center + Vector2(cell_size * 0.09, -cell_size * 0.05),
			maxf(1.2, cell_size * 0.05),
			text_color
		)


func _cell_center(
	pos: Vector2i,
	origin: Vector2,
	cell_size: float
) -> Vector2:
	return (
		origin
		+ Vector2(pos.x + 0.5, pos.y + 0.5) * cell_size
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch

		if touch.pressed:
			_touch_start = touch.position
			_tracking_touch = true
		else:
			_finish_swipe(touch.position)

	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton

		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse.pressed:
			_touch_start = mouse.position
			_tracking_touch = true
		else:
			_finish_swipe(mouse.position)


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
