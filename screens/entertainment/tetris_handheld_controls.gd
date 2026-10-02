class_name TetrisHandheldControls
extends Control

signal action_pressed(action: String)
signal action_released(action: String)

const PAD_SIZE := 38.0
const ROTATE_SIZE := 80.0
var enabled := true
var _touches: Dictionary = {}
var _mouse_action := ""

func _ready() -> void:
	custom_minimum_size = Vector2(250, 114)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		release_all()
	queue_redraw()

func release_all() -> void:
	var previous := _touches.values()
	_touches.clear()
	if not _mouse_action.is_empty():
		previous.append(_mouse_action)
		_mouse_action = ""
	for action in previous:
		action_released.emit(str(action))
	queue_redraw()

func _rects() -> Dictionary:
	return {
		"drop": Rect2(46, 0, PAD_SIZE, PAD_SIZE),
		"left": Rect2(8, 38, PAD_SIZE, PAD_SIZE),
		"right": Rect2(84, 38, PAD_SIZE, PAD_SIZE),
		"down": Rect2(46, 76, PAD_SIZE, PAD_SIZE),
		"rotate": Rect2(size.x - ROTATE_SIZE - 10, 14, ROTATE_SIZE, ROTATE_SIZE),
	}

func _hit(point: Vector2) -> String:
	var rects := _rects()
	for action in rects:
		var rect: Rect2 = rects[action]
		if rect.has_point(point):
			if action == "rotate" and point.distance_to(rect.get_center()) > ROTATE_SIZE * 0.5:
				continue
			return str(action)
	return ""

func _pressed(action: String) -> bool:
	return _touches.values().has(action) or _mouse_action == action

func _release_touch(index: int) -> void:
	if not _touches.has(index):
		return
	var action := str(_touches[index])
	_touches.erase(index)
	if not _pressed(action):
		action_released.emit(action)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		release_all()
		return
	# Screen touches are tracked by finger ID, allowing movement + rotation
	# together. Ignore emulated mouse events to avoid double actions on Android.
	var local_point := Vector2.ZERO
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		local_point = get_global_transform_with_canvas().affine_inverse() * event.position
	elif event is InputEventMouse:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		local_point = get_global_transform_with_canvas().affine_inverse() * event.position
	else:
		return
	if event is InputEventScreenTouch:
		if event.pressed and enabled:
			var action := _hit(local_point)
			if action.is_empty():
				return
			_touches[event.index] = action
			action_pressed.emit(action)
			queue_redraw()
		elif _touches.has(event.index):
			_release_touch(event.index)
		else:
			return
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		if _hit(local_point) != str(_touches[event.index]):
			_release_touch(event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and enabled:
			_mouse_action = _hit(local_point)
			if _mouse_action.is_empty():
				return
			action_pressed.emit(_mouse_action)
			queue_redraw()
		elif not _mouse_action.is_empty():
			var previous := _mouse_action
			_mouse_action = ""
			if not _pressed(previous):
				action_released.emit(previous)
			queue_redraw()
		else:
			return
	elif event is InputEventMouseMotion and not _mouse_action.is_empty():
		if _hit(local_point) != _mouse_action:
			var previous := _mouse_action
			_mouse_action = ""
			action_released.emit(previous)
			queue_redraw()
	else:
		return
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("282433")
	shell.border_color = Color("544b65")
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(18)
	draw_style_box(shell, Rect2(Vector2.ZERO, size))
	# The center joins four separate touch regions into a familiar D-pad cross.
	var center := Rect2(46, 38, PAD_SIZE, PAD_SIZE)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color("14121b")
	key_style.set_corner_radius_all(5)
	draw_style_box(key_style, center)
	draw_circle(center.get_center(), 5, Color("36303f"))
	var rects := _rects()
	for action in rects:
		var rect: Rect2 = rects[action]
		var pushed := _pressed(str(action))
		var color := Color("ae84e8") if pushed else Color("403749")
		if not enabled:
			color = Color("302c37")
		var offset := Vector2(0, 2) if pushed else Vector2.ZERO
		if action == "rotate":
			draw_circle(rect.get_center() + Vector2(0,4), ROTATE_SIZE * 0.5, Color("15111e"))
			draw_circle(rect.get_center() + offset, ROTATE_SIZE * 0.5, color)
			draw_arc(rect.get_center() + offset, ROTATE_SIZE * 0.5 - 2, 0, TAU, 64, Color("a68bbd"), 1.5, true)
			_text("↻", Rect2(rect.position + offset, rect.size), 39)
		else:
			var shadow := StyleBoxFlat.new()
			shadow.bg_color = Color("100e16")
			shadow.set_corner_radius_all(7)
			draw_style_box(shadow, Rect2(rect.position + Vector2(0,3), rect.size))
			var key := StyleBoxFlat.new()
			key.bg_color = color
			key.border_color = Color("746480")
			key.set_border_width_all(1)
			key.set_corner_radius_all(7)
			draw_style_box(key, Rect2(rect.position + offset, rect.size))
			var arrows := {"drop":"▲", "left":"◀", "right":"▶", "down":"▼"}
			_text(arrows[action], Rect2(rect.position + offset, rect.size), 21)
	_text("XOAY", Rect2(size.x - 100, 94, 100, 18), 12)
	_text("↑ Thả ngay", Rect2(132, 40, maxf(0, size.x - 232), 40), 9)

func _text(value: String, rect: Rect2, font_size: int) -> void:
	if rect.size.x < 20:
		return
	var font := get_theme_default_font()
	var extent := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := rect.get_center() + Vector2(-extent.x * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, origin, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("eee4fb") if enabled else Color("81788c"))
