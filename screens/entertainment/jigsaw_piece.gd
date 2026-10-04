class_name JigsawPiece
extends Control


var session: JigsawSession
var texture: Texture2D
var index := -1
var selected := false
var rotation_steps := 0


func _draw() -> void:
	if session == null or texture == null or index < 0:
		return

	var cell := texture.get_size() / Vector2(session.grid())
	var ratio := cell.x / maxf(1.0, cell.y)
	var unit := minf(
		size.x / maxf(0.2, ratio * 1.45),
		size.y / 1.45
	)
	var extent := Vector2(ratio, 1.0) * unit
	var shape := session.polygon(index)
	var centered := PackedVector2Array()

	for point in shape:
		centered.append(
			(point - Vector2(0.5, 0.5)) * extent
		)

	draw_set_transform(
		size * 0.5,
		float(posmod(rotation_steps, 4)) * PI * 0.5,
		Vector2.ONE
	)
	draw_colored_polygon(
		centered,
		Color.WHITE,
		session.uv(index),
		texture
	)

	if not centered.is_empty():
		var outline := centered.duplicate()
		outline.append(outline[0])
		draw_polyline(
			outline,
			Color("ffd683") if selected else Color("b8a3de"),
			2.2 if selected else 1.0,
			true
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
