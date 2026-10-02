class_name BreakoutBoard
extends Control

signal paddle_moved(x: float)
signal launch_requested
var state: Dictionary = {}
var palette: Dictionary = {}
var _touch := -1
var _mouse_drag := false

func _ready() -> void:
	resized.connect(queue_redraw)

func show_state(data: Dictionary) -> void:
	state = data
	queue_redraw()

func _area() -> Rect2:
	var scale_value := minf(size.x / BreakoutMaps.WIDTH, size.y / BreakoutMaps.HEIGHT)
	var extent := Vector2(BreakoutMaps.WIDTH, BreakoutMaps.HEIGHT) * scale_value
	return Rect2((size - extent) / 2, extent)

func release_input() -> void:
	_touch = -1
	_mouse_drag = false

func _move(point: Vector2) -> void:
	var area := _area()
	paddle_moved.emit((point.x - area.position.x) * BreakoutMaps.WIDTH / maxf(1, area.size.x))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_move(event.position)
			launch_requested.emit()
		elif event.index == _touch and not event.pressed:
			_touch = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_drag = event.pressed
		if event.pressed:
			_move(event.position)
			launch_requested.emit()
		accept_event()
	elif event is InputEventMouseMotion and _mouse_drag:
		_move(event.position)
		accept_event()

func _draw() -> void:
	var area := _area()
	var scale_value := area.size.x / BreakoutMaps.WIDTH
	draw_rect(area, Color("16151e"))
	draw_rect(area, Color("665880"), false, 1.5)
	if state.is_empty():
		return
	for brick in state.bricks:
		var hp := int(brick.hp)
		if hp == 0:
			continue
		var color: Color = {1: Color("6994ed"), 2: Color("efb54e"), 3: Color("eb7178"), -1: Color("818591")}[hp]
		var rect := Rect2(area.position + Vector2(float(brick.x), float(brick.y)) * scale_value, Vector2(float(brick.w), float(brick.h)) * scale_value)
		draw_rect(rect, color.darkened(0.25))
		draw_rect(rect.grow(-2 * scale_value), color)
		if hp > 1:
			var font := ThemeDB.fallback_font
			var font_size := maxi(8, int(11 * scale_value))
			draw_string(font, rect.position + Vector2(18, 14) * scale_value, str(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("292331"))
		elif hp == -1:
			draw_line(rect.position + Vector2(5, 5) * scale_value, rect.end - Vector2(5, 5) * scale_value, Color("c4c7d0"), 2)
	var width := float(state.paddle_width)
	var paddle := Rect2(area.position + Vector2(float(state.paddle_x) - width / 2, BreakoutSession.PADDLE_Y) * scale_value, Vector2(width, 8) * scale_value)
	draw_style_box(PetHomeTheme.panel_style(Color("ede7ff"), Color("cbb2ff")), paddle)
	draw_circle(area.position + Vector2(float(state.ball[0]), float(state.ball[1])) * scale_value, BreakoutSession.RADIUS * scale_value, Color("fff7df"))
	for drop in state.drops:
		var center := area.position + Vector2(float(drop.x), float(drop.y)) * scale_value
		var color: Color = {"wide": Color("81e2ad"), "slow": Color("87bbff"), "life": Color("ff899f")}[str(drop.kind)]
		draw_circle(center, 8 * scale_value, color)
		var label: String = {"wide": "W", "slow": "S", "life": "+"}[str(drop.kind)]
		draw_string(ThemeDB.fallback_font, center + Vector2(-4, 4) * scale_value, label, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(8, int(11 * scale_value)), Color("20192f"))
