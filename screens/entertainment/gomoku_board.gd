class_name GomokuBoard
extends Control
signal cell_selected(index: int)
var cells: Array[int] = []
var selected := -1
var last_move := -1
var winning: Array[int] = []
var enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var step := minf(size.x, size.y) / 15.0
	var pad := step * 0.5
	draw_rect(Rect2(Vector2.ZERO, Vector2.ONE * step * 15), Color("dcc392"))
	for i in 15:
		var pos := pad + i * step
		draw_line(Vector2(pad,pos), Vector2(pad + 14*step,pos), Color("78654b"))
		draw_line(Vector2(pos,pad), Vector2(pos,pad + 14*step), Color("78654b"))
	for y in [3,7,11]:
		for x in [3,7,11]:
			draw_circle(Vector2(pad+x*step,pad+y*step),2,Color("78654b"))
	for i in cells.size():
		var center := Vector2(pad + (i % 15)*step, pad + (i / 15)*step)
		if cells[i] != 0:
			draw_circle(center,step*0.41, Color("20232a") if cells[i] == 1 else Color("fafafa"))
			if winning.has(i):
				draw_arc(center,step*0.44,0,TAU,24,Color("26a454"),2)
			elif i == last_move:
				draw_circle(center,2,Color("ed6555"))
		elif i == selected:
			draw_arc(center,step*0.4,0,TAU,24,Color("d24b3e"),2)

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
	else:
		return
	var step := minf(size.x,size.y) / 15.0
	var x := int(point.x / step)
	var y := int(point.y / step)
	if x in range(15) and y in range(15):
		cell_selected.emit(y*15+x)
		accept_event()
