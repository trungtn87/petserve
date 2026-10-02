class_name JigsawBoard
extends Control

signal drop_requested(index: int)
var session: JigsawSession
var texture: Texture2D
var show_reference := false
var selected := -1
var _press_position := Vector2.ZERO

func cell_size() -> Vector2:
	return size / Vector2(session.grid())

func try_drop(global_position: Vector2) -> void:
	if session == null or selected < 0:
		return
	var local := get_global_transform().affine_inverse() * global_position
	if not Rect2(Vector2.ZERO, size).has_point(local):
		return
	var cell := cell_size()
	var target := Vector2(selected % session.grid().x, selected / session.grid().x) * cell
	# Snap within the target cell, with a small allowance for finger placement.
	if local.distance_to(target + cell * .5) <= minf(cell.x, cell.y) * .65:
		drop_requested.emit(selected)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
		elif event.position.distance_to(_press_position) < 8:
			try_drop(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press_position = event.position
		elif event.position.distance_to(_press_position) < 8:
			try_drop(get_global_transform() * event.position)

func _draw() -> void:
	if session == null or texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("182636"))
	if show_reference:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, .35))
	var cell := cell_size()
	for index in session.count():
		var polygon := session.polygon(index)
		var offset := Vector2(index % session.grid().x, index / session.grid().x) * cell
		for point in polygon.size():
			polygon[point] = polygon[point] * cell + offset
		if session.placed.has(index):
			draw_colored_polygon(polygon, Color.WHITE, session.uv(index), texture)
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(1, 1, 1, .16), .7, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("79d8cb"), false, 1.5)
