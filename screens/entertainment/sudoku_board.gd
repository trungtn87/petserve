class_name SudokuBoard
extends Control

signal cell_selected(index: int)
var state: Dictionary = {}
var selected := -1
var palette: Dictionary = {}

func _ready() -> void:
	resized.connect(queue_redraw)

func show_state(data: Dictionary, index: int) -> void:
	state = data
	selected = index
	queue_redraw()

func _rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2((size - Vector2.ONE * side) / 2, Vector2.ONE * side)

func _gui_input(event: InputEvent) -> void:
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	else:
		return
	var area := _rect()
	if area.has_point(point):
		var local := (point - area.position) / (area.size.x / 9.0)
		cell_selected.emit(int(local.y) * 9 + int(local.x))
		accept_event()

func _draw() -> void:
	if state.is_empty():
		return
	var area := _rect()
	var cell := area.size.x / 9.0
	var font := ThemeDB.fallback_font
	var font_size := maxi(12, int(cell * 0.64))
	var accent: Color = palette.get("accent", Color("79d8cb"))
	for index in 81:
		var box := Rect2(area.position + Vector2(index % 9, index / 9) * cell, Vector2.ONE * cell)
		var value: int = state.board[index]
		var bg := Color("172637")
		if selected >= 0 and SudokuRules.peers(index, selected):
			bg = Color("253c50")
		if selected >= 0 and value > 0 and value == int(state.board[selected]):
			bg = Color("325965")
		if index == selected:
			bg = accent.darkened(0.45)
		draw_rect(box, bg)
		if value > 0:
			var color := Color.WHITE if int(state.puzzle[index]) > 0 else Color("79d8cb")
			if SudokuRules.conflicts(state.board, index):
				color = Color("ff7d87")
			var text := str(value)
			var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, box.position + Vector2((cell - extent.x) / 2, (cell - font.get_height(font_size)) / 2 + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		else:
			var small := maxi(7, int(cell * 0.25))
			for number in 9:
				if int(state.notes[index]) & (1 << number):
					var pos := box.position + Vector2(number % 3, number / 3) * cell / 3.0
					draw_string(font, pos + Vector2(cell / 12.0, font.get_ascent(small)), str(number + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color("afc1d3"))
	for line in 10:
		var color := accent if line % 3 == 0 else Color("3b536b")
		var width := 2.0 if line % 3 == 0 else 1.0
		draw_line(area.position + Vector2(line * cell, 0), area.position + Vector2(line * cell, area.size.y), color, width)
		draw_line(area.position + Vector2(0, line * cell), area.position + Vector2(area.size.x, line * cell), color, width)
