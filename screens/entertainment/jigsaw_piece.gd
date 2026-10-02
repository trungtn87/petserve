class_name JigsawPiece
extends Control

var session: JigsawSession
var texture: Texture2D
var index := -1
var selected := false

func _draw() -> void:
	if session == null or texture == null or index < 0:
		return
	var cell := texture.get_size() / Vector2(session.grid())
	var ratio := cell.x / cell.y
	var unit := minf(size.x / (ratio * 1.5), size.y / 1.5)
	var extent := Vector2(ratio, 1) * unit
	var offset := (size - extent) / 2.0
	var shape := session.polygon(index)
	for i in shape.size():
		shape[i] = shape[i] * extent + offset
	draw_colored_polygon(shape, Color.WHITE, session.uv(index), texture)
	shape.append(shape[0])
	draw_polyline(shape, Color("ffd683") if selected else Color("b8a3de"), 2.0 if selected else 1.0, true)
