class_name PetHomeLogo
extends Control


var accent: Color = Color.WHITE
var panel: Color = Color(0.08, 0.08, 0.12, 0.88)


func configure(
	accent_color: Color,
	panel_color: Color
) -> void:
	accent = accent_color
	panel = panel_color
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(30, 30)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46

	var bg := panel
	bg.a = 0.92
	draw_circle(center, radius, bg)

	var ring := accent
	ring.a = 0.72
	draw_arc(
		center,
		radius - 1.5,
		0.0,
		TAU,
		32,
		ring,
		1.5,
		true
	)

	var paw := accent
	paw.a = 0.95

	draw_circle(
		center + Vector2(0, 4),
		radius * 0.28,
		paw
	)

	var toe_radius := radius * 0.105
	for offset in [
		Vector2(-6.2, -4.6),
		Vector2(-2.1, -7.5),
		Vector2(2.4, -7.5),
		Vector2(6.3, -4.5),
	]:
		draw_circle(
			center + offset,
			toe_radius,
			paw
		)
