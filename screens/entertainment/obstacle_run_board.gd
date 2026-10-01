class_name ObstacleRunBoard
extends Control

signal move_requested(world_x: float)

var palette: Dictionary = {}
var game: ObstacleRunGame

func _ready() -> void:
	custom_minimum_size = Vector2(0, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	gui_input.connect(_on_gui_input)

func set_game(value: ObstacleRunGame) -> void:
	game = value
	queue_redraw()

func _draw() -> void:
	if game == null:
		return

	var accent: Color = palette.get("accent", Color("7cdae9"))
	var panel: Color = palette.get("panel", Color("102534"))
	var ink: Color = palette.get("text", Color.WHITE)
	draw_style_box(
		PetHomeTheme.panel_style(panel, Color(accent, 0.35)),
		Rect2(Vector2.ZERO, size)
	)

	var scale_factor := minf(
		size.x / ObstacleRunGame.WORLD_SIZE.x,
		size.y / ObstacleRunGame.WORLD_SIZE.y
	)
	var origin := (
		size - ObstacleRunGame.WORLD_SIZE * scale_factor
	) * 0.5
	draw_set_transform(
		origin,
		0.0,
		Vector2.ONE * scale_factor
	)

	for lane_x in ObstacleRunGame.LANE_CENTERS:
		draw_line(
			Vector2(float(lane_x), 0),
			Vector2(float(lane_x), ObstacleRunGame.WORLD_SIZE.y),
			Color(accent, 0.045),
			1.0
		)

	for index in range(8):
		var y := fposmod(
			float(index) * 67.0 + game.elapsed() * 78.0,
			500.0
		) - 50.0
		var x := 22.0 + float((index * 47) % 276)
		draw_line(
			Vector2(x, y),
			Vector2(x, y + 18.0),
			Color(accent, 0.16),
			2.0,
			true
		)

	draw_rect(
		Rect2(0, ObstacleRunGame.PLAYER_Y + 40.0, 320, 18),
		Color(accent, 0.06)
	)

	for obstacle in game.obstacles():
		if bool(obstacle["resolved"]):
			continue
		_draw_falling_item(obstacle, accent, panel, ink)

	var pet := game.player_rect()
	var center := pet.get_center()
	var body_color := accent
	if game.is_invulnerable() and int(game.elapsed() * 12.0) % 2 == 0:
		body_color.a = 0.35

	_draw_ellipse_shadow(
		Vector2(center.x, pet.end.y + 4.0),
		Vector2(19.0, 5.0),
		Color(0, 0, 0, 0.22)
	)

	var body := StyleBoxFlat.new()
	body.bg_color = body_color
	body.set_corner_radius_all(11)
	draw_style_box(body, pet)
	draw_colored_polygon(PackedVector2Array([
		pet.position + Vector2(2, 7),
		pet.position + Vector2(4, -8),
		pet.position + Vector2(13, 3),
	]), body_color)
	draw_colored_polygon(PackedVector2Array([
		pet.position + Vector2(20, 3),
		pet.position + Vector2(30, -8),
		pet.position + Vector2(32, 7),
	]), body_color)
	draw_circle(center + Vector2(4, -4), 3.0, panel)
	draw_circle(center + Vector2(11, -4), 2.6, panel)
	draw_circle(center + Vector2(10, 4), 1.8, ink)

	var sway := sin(game.elapsed() * 18.0) * 2.2
	draw_line(
		pet.position + Vector2(8, 30),
		pet.position + Vector2(7 + sway, 37),
		body_color,
		5.0,
		true
	)
	draw_line(
		pet.position + Vector2(26, 30),
		pet.position + Vector2(27 - sway, 37),
		body_color,
		5.0,
		true
	)

	draw_set_transform(Vector2.ZERO)

func _draw_falling_item(
	obstacle: Dictionary,
	accent: Color,
	panel: Color,
	ink: Color
) -> void:
	var rect := game.obstacle_rect(obstacle)
	var kind := StringName(obstacle.get("kind", &"rock"))
	var center := rect.get_center()

	if kind == &"crate":
		var crate := StyleBoxFlat.new()
		crate.bg_color = Color("d69c62")
		crate.border_color = Color("ffe0a6")
		crate.set_border_width_all(2)
		crate.set_corner_radius_all(5)
		draw_style_box(crate, rect)
		draw_line(
			rect.position + Vector2(5, 5),
			rect.end - Vector2(5, 5),
			Color("8c5b39"),
			3.0,
			true
		)
		draw_line(
			Vector2(rect.end.x - 5, rect.position.y + 5),
			Vector2(rect.position.x + 5, rect.end.y - 5),
			Color("8c5b39"),
			3.0,
			true
		)
	elif kind == &"orb":
		draw_circle(
			center,
			minf(rect.size.x, rect.size.y) * 0.5,
			Color("cf6ef2")
		)
		draw_arc(
			center,
			minf(rect.size.x, rect.size.y) * 0.34,
			0.0,
			TAU,
			20,
			Color(accent, 0.9),
			2.0,
			true
		)
		draw_circle(
			center - Vector2(4, 5),
			3.0,
			Color(ink, 0.72)
		)
	else:
		draw_circle(
			center,
			minf(rect.size.x, rect.size.y) * 0.5,
			Color("ef8f70")
		)
		draw_circle(
			center - Vector2(5, 5),
			4.0,
			Color("ffc3a2")
		)
		draw_arc(
			center,
			minf(rect.size.x, rect.size.y) * 0.48,
			0.2,
			4.2,
			12,
			Color(panel, 0.24),
			2.0,
			true
		)

func _draw_ellipse_shadow(
	center: Vector2,
	radius: Vector2,
	color: Color
) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(
			center + Vector2(
				cos(angle) * radius.x,
				sin(angle) * radius.y
			)
		)
	draw_colored_polygon(points, color)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		move_requested.emit(_world_x(event.position.x))
		accept_event()
	elif event is InputEventScreenDrag:
		move_requested.emit(_world_x(event.position.x))
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			move_requested.emit(_world_x(event.position.x))
			accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		move_requested.emit(_world_x(event.position.x))
		accept_event()

func _world_x(local_x: float) -> float:
	var scale_factor := minf(
		size.x / ObstacleRunGame.WORLD_SIZE.x,
		size.y / ObstacleRunGame.WORLD_SIZE.y
	)
	if scale_factor <= 0.0:
		return ObstacleRunGame.WORLD_SIZE.x * 0.5
	var origin_x := (
		size.x - ObstacleRunGame.WORLD_SIZE.x * scale_factor
	) * 0.5
	return clampf(
		(local_x - origin_x) / scale_factor,
		0.0,
		ObstacleRunGame.WORLD_SIZE.x
	)
