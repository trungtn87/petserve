class_name PetHomeMenuDecor
extends Control


var accent: Color = Color.WHITE
var secondary: Color = Color(0.75, 0.62, 1.0, 1.0)


func configure(
	accent_color: Color,
	secondary_color: Color
) -> void:
	accent = accent_color
	secondary = secondary_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var width := size.x

	for index in range(5):
		var x := 24.0 + float(index) * maxf(22.0, (width - 48.0) / 4.0)
		var length := 16.0 + float((index * 13) % 24)
		var line_color := accent
		line_color.a = 0.34

		draw_line(
			Vector2(x, 0),
			Vector2(x, length),
			line_color,
			1.0,
			true
		)

		var star_center := Vector2(
			x,
			length + 4.0
		)

		if index == 1:
			_draw_crescent(
				star_center,
				7.0
			)
		else:
			_draw_star(
				star_center,
				4.0 + float(index % 2) * 1.5
			)

	var haze := secondary
	haze.a = 0.07
	draw_circle(
		Vector2(width * 0.82, size.y * 0.72),
		58.0,
		haze
	)


func _draw_star(
	center: Vector2,
	radius: float
) -> void:
	var points := PackedVector2Array()

	for index in range(8):
		var angle := -PI * 0.5 + float(index) * PI / 4.0
		var r := radius if index % 2 == 0 else radius * 0.35

		points.append(
			center + Vector2(
				cos(angle),
				sin(angle)
			) * r
		)

	draw_colored_polygon(
		points,
		accent
	)


func _draw_crescent(
	center: Vector2,
	radius: float
) -> void:
	var moon := secondary
	moon.a = 0.92

	draw_circle(
		center,
		radius,
		moon
	)
	draw_circle(
		center + Vector2(3.5, -2.0),
		radius * 0.88,
		Color(0.09, 0.06, 0.16, 1.0)
	)
