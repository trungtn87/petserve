class_name ObstacleRunBoard
extends Control

signal jump_requested

var palette: Dictionary = {}
var game: ObstacleRunGame

func _ready() -> void:
	custom_minimum_size = Vector2(0, 180)
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
	draw_style_box(PetHomeTheme.panel_style(panel, Color(accent, 0.35)), Rect2(Vector2.ZERO, size))
	var scale_factor := minf(size.x / 320.0, size.y / 260.0)
	var origin := (size - ObstacleRunGame.WORLD_SIZE * scale_factor) * 0.5
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	# Quiet scenery keeps the obstacles and pet easy to distinguish.
	draw_circle(Vector2(261, 50), 19, Color(accent, 0.18))
	for index in range(5):
		var x := fposmod(float(index) * 84.0 - game.elapsed() * 10.0, 420.0) - 40.0
		draw_circle(Vector2(x, 210), 45.0 + float(index % 2) * 18.0, Color(accent, 0.07))
	draw_rect(Rect2(0, 210, 320, 50), Color(accent, 0.09))
	draw_line(Vector2(0, 210), Vector2(320, 210), Color(accent, 0.8), 2.0, true)
	for index in range(9):
		var x := fposmod(float(index) * 45.0 - game.elapsed() * 90.0, 405.0) - 40.0
		draw_line(Vector2(x, 224), Vector2(x + 16, 224), Color(accent, 0.25), 2.0)

	for obstacle in game.obstacles():
		if bool(obstacle["resolved"]):
			continue
		var rect := game.obstacle_rect(obstacle)
		var rock := StyleBoxFlat.new()
		rock.bg_color = Color("efae70")
		rock.set_corner_radius_all(5)
		draw_style_box(rock, rect)
		draw_line(rect.position + Vector2(5, 6), rect.position + Vector2(rect.size.x - 5, 6), Color("ffe1af"), 3.0, true)

	var pet := game.player_rect()
	var center := pet.get_center()
	var body_color := accent
	if game.is_invulnerable() and int(game.elapsed() * 12.0) % 2 == 0:
		body_color.a = 0.40
	draw_arc(Vector2(pet.position.x - 3, pet.end.y - 11), 9, 0.8, 4.7, 12, body_color, 5.0, true)
	var body := StyleBoxFlat.new()
	body.bg_color = body_color
	body.set_corner_radius_all(10)
	draw_style_box(body, pet)
	draw_colored_polygon(PackedVector2Array([
		pet.position + Vector2(2, 7), pet.position + Vector2(3, -8), pet.position + Vector2(13, 3)
	]), body_color)
	draw_colored_polygon(PackedVector2Array([
		pet.position + Vector2(18, 3), pet.position + Vector2(28, -8), pet.position + Vector2(29, 7)
	]), body_color)
	draw_circle(center + Vector2(4, -4), 3.0, panel)
	draw_circle(center + Vector2(11, -4), 2.4, panel)
	draw_circle(center + Vector2(10, 3), 1.8, ink)
	var stride := sin(game.elapsed() * 22.0) * 3.0 if game.is_grounded() else 0.0
	draw_line(pet.position + Vector2(7, 27), pet.position + Vector2(7 + stride, 34), body_color, 5.0, true)
	draw_line(pet.position + Vector2(23, 27), pet.position + Vector2(23 - stride, 34), body_color, 5.0, true)
	draw_set_transform(Vector2.ZERO)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		jump_requested.emit()
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Touch is handled above; do not queue a second jump from emulated mouse input.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			jump_requested.emit()
		accept_event()
