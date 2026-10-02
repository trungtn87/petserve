class_name Energy2048Board
extends Control

signal move_requested(direction: Vector2i)

var palette: Dictionary = {}
var board: Array = []
var _motions: Array = []
var _merged: Array = []
var _elapsed := 1.0
var _touch_id := -1
var _mouse_down := false
var _start := Vector2.ZERO
const SLIDE_SECONDS := 0.14
const POP_SECONDS := 0.12

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	visibility_changed.connect(_reset_gesture)
	resized.connect(queue_redraw)

func show_board(state: Dictionary, motion: Dictionary = {}) -> void:
	board = state.get("board", []).duplicate()
	_motions = motion.get("motions", [])
	_merged = motion.get("merged", [])
	_elapsed = 0.0 if not _motions.is_empty() else 1.0
	set_process(_elapsed == 0.0)
	queue_redraw()

func busy() -> bool:
	return _elapsed < SLIDE_SECONDS + POP_SECONDS

func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if not busy():
		set_process(false)

func _rect() -> Rect2:
	var side := maxf(0.0, minf(size.x, size.y))
	return Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side)

func _tile_rect(index: int) -> Rect2:
	var area := _rect()
	var gap := 5.0
	var cell := (area.size.x - gap * 5.0) / 4.0
	return Rect2(area.position + Vector2(index % 4, index / 4) * (cell + gap) + Vector2.ONE * gap, Vector2.ONE * cell)

func _draw() -> void:
	if board.size() != 16 or _rect().size.x < 40.0:
		return
	var background := StyleBoxFlat.new()
	background.bg_color = palette.get("panel", Color("171229"))
	background.set_corner_radius_all(10)
	draw_style_box(background, _rect())
	for index in 16:
		_draw_tile(_tile_rect(index), 0)
	if _elapsed < SLIDE_SECONDS:
		var progress := smoothstep(0.0, 1.0, _elapsed / SLIDE_SECONDS)
		for motion in _motions:
			var from := _tile_rect(int(motion["from"]))
			var to := _tile_rect(int(motion["to"]))
			_draw_tile(Rect2(from.position.lerp(to.position, progress), to.size), int(motion.value))
	else:
		for index in 16:
			if int(board[index]) == 0:
				continue
			var tile := _tile_rect(index)
			if index in _merged and busy():
				var pop := sin((_elapsed - SLIDE_SECONDS) / POP_SECONDS * PI) * 0.07
				tile = tile.grow(tile.size.x * pop * 0.5)
			_draw_tile(tile, int(board[index]))

func _draw_tile(rect: Rect2, value: int) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(7)
	var accent: Color = palette.get("accent", Color("79d8cb"))
	var level := log(float(maxi(2, value))) / log(2.0)
	style.bg_color = ArcadeTheme.SURFACE if value == 0 else [Color("304b66"), Color("3b6280"), Color("336e79"), Color("397e76"), Color("568961"), Color("859557"), Color("d0ad65"), Color("e7b16f"), Color("dc9470"), Color("cd7f92"), Color("a994d5")][clampi(int(level) - 1, 0, 10)]
	if value >= 128:
		style.set_border_width_all(1)
		style.border_color = accent
	draw_style_box(style, rect)
	if value == 0:
		return
	var font := ThemeDB.fallback_font
	var font_size := clampi(int(rect.size.x * (0.32 if value >= 1024 else 0.40)), 12, 30)
	var text := str(value)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	draw_string(font, rect.position + Vector2((rect.size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("101923") if value >= 128 else ArcadeTheme.TEXT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and _rect().has_point(event.position):
			_touch_id = event.index
			_start = event.position
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			if not event.canceled:
				_swipe(event.position - _start)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Ignore synthetic mouse events produced from touchscreen input.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed and _rect().has_point(event.position):
			_mouse_down = true
			_start = event.position
		elif not event.pressed and _mouse_down:
			_mouse_down = false
			_swipe(event.position - _start)
		accept_event()

func _swipe(delta: Vector2) -> void:
	if busy() or delta.length() < 18.0:
		return
	if absf(delta.x) > absf(delta.y):
		move_requested.emit(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
	else:
		move_requested.emit(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)

func _reset_gesture() -> void:
	_touch_id = -1
	_mouse_down = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_gesture()
