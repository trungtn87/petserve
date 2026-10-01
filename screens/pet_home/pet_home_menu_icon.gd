class_name PetHomeMenuIcon
extends Control


var action_id: StringName = &""
var accent: Color = Color.WHITE
var secondary: Color = Color(0.75, 0.62, 1.0, 1.0)


func configure(
	id: StringName,
	accent_color: Color,
	secondary_color: Color
) -> void:
	action_id = id
	accent = accent_color
	secondary = secondary_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(42, 42)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var halo := accent
	halo.a = 0.12
	draw_circle(
		center,
		minf(size.x, size.y) * 0.46,
		halo
	)

	match action_id:
		&"pet_info":
			_draw_pet(center)
		&"chest":
			_draw_chest(center)
		&"entertainment":
			_draw_game(center)
		&"evolution":
			_draw_crystal(center)
		&"settings":
			_draw_gear(center)
		_:
			draw_circle(center, 7.0, accent)


func _draw_pet(center: Vector2) -> void:
	var c := accent
	var s := secondary
	draw_circle(
		center + Vector2(-5, -2),
		4.3,
		c
	)
	draw_circle(
		center + Vector2(5, -2),
		4.3,
		c
	)
	draw_circle(
		center + Vector2(0, 5),
		7.0,
		s
	)
	draw_circle(
		center + Vector2(-7, -9),
		2.8,
		s
	)
	draw_circle(
		center + Vector2(0, -11),
		2.8,
		s
	)
	draw_circle(
		center + Vector2(7, -9),
		2.8,
		s
	)


func _draw_chest(center: Vector2) -> void:
	var body := Rect2(
		center + Vector2(-12, -3),
		Vector2(24, 15)
	)
	draw_style_box(
		_box(
			secondary,
			accent,
			5
		),
		body
	)
	draw_arc(
		center + Vector2(0, -3),
		10.0,
		PI,
		TAU,
		20,
		accent,
		3.0,
		true
	)
	draw_line(
		center + Vector2(0, -2),
		center + Vector2(0, 12),
		accent,
		2.0,
		true
	)
	draw_circle(
		center + Vector2(0, 5),
		2.2,
		Color("#FFF0A8")
	)


func _draw_game(center: Vector2) -> void:
	var outline := PackedVector2Array([
		center + Vector2(-13, 5),
		center + Vector2(-9, -7),
		center + Vector2(-3, -10),
		center + Vector2(3, -10),
		center + Vector2(9, -7),
		center + Vector2(13, 5),
		center + Vector2(8, 10),
		center + Vector2(3, 5),
		center + Vector2(-3, 5),
		center + Vector2(-8, 10),
	])
	draw_colored_polygon(
		outline,
		Color(
			secondary.r,
			secondary.g,
			secondary.b,
			0.75
		)
	)
	for index in range(outline.size()):
		draw_line(
			outline[index],
			outline[(index + 1) % outline.size()],
			accent,
			1.4,
			true
		)
	draw_line(
		center + Vector2(-7, 0),
		center + Vector2(-1, 0),
		accent,
		2.0,
		true
	)
	draw_line(
		center + Vector2(-4, -3),
		center + Vector2(-4, 3),
		accent,
		2.0,
		true
	)
	draw_circle(
		center + Vector2(6, -1),
		2.2,
		accent
	)
	draw_circle(
		center + Vector2(9, 3),
		2.0,
		accent
	)


func _draw_crystal(center: Vector2) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -14),
		center + Vector2(10, -3),
		center + Vector2(6, 12),
		center + Vector2(0, 16),
		center + Vector2(-7, 11),
		center + Vector2(-10, -3),
	])
	draw_colored_polygon(
		points,
		Color(
			secondary.r,
			secondary.g,
			secondary.b,
			0.78
		)
	)
	for index in range(points.size()):
		draw_line(
			points[index],
			points[(index + 1) % points.size()],
			accent,
			1.5,
			true
		)
	draw_line(
		center + Vector2(0, -14),
		center + Vector2(0, 16),
		accent,
		1.0,
		true
	)
	draw_line(
		center + Vector2(-10, -3),
		center + Vector2(10, -3),
		accent,
		1.0,
		true
	)


func _draw_gear(center: Vector2) -> void:
	for index in range(8):
		var angle := float(index) / 8.0 * TAU
		var direction := Vector2(
			cos(angle),
			sin(angle)
		)
		draw_line(
			center + direction * 9.0,
			center + direction * 14.0,
			accent,
			4.0,
			true
		)

	draw_circle(
		center,
		10.0,
		secondary
	)
	draw_circle(
		center,
		4.2,
		Color(0.10, 0.08, 0.18, 1.0)
	)
	draw_arc(
		center,
		10.0,
		0.0,
		TAU,
		28,
		accent,
		1.8,
		true
	)


func _box(
	bg: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
