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
		&"inventory":
			_draw_inventory(center)
		&"crystallization":
			_draw_crystal(center)
		&"gene":
			_draw_gene(center)
		&"gene_evolution":
			_draw_gene_evolution(center)
		&"food":
			_draw_food(center)
		&"chest":
			_draw_chest(center)
		&"entertainment":
			_draw_game(center)
		&"menu":
			_draw_menu_grid(center)
		&"evolution":
			_draw_evolution(center)
		&"achievement":
			_draw_achievement(center)
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


func _draw_inventory(center: Vector2) -> void:
	var bag := Rect2(
		center + Vector2(-10, -7),
		Vector2(20, 18)
	)
	draw_style_box(
		_box(
			secondary,
			accent,
			5
		),
		bag
	)
	draw_arc(
		center + Vector2(0, -7),
		7.0,
		PI,
		TAU,
		20,
		accent,
		2.0,
		true
	)
	draw_circle(
		center + Vector2(0, 2),
		2.2,
		Color("#FFF0A8")
	)


func _draw_gene(center: Vector2) -> void:
	for step in range(7):
		var t := float(step) / 6.0
		var y := lerpf(-12.0, 12.0, t)
		var x := sin(t * TAU) * 6.0
		var left := center + Vector2(x, y)
		var right := center + Vector2(-x, y)
		draw_circle(left, 1.7, accent)
		draw_circle(right, 1.7, secondary)
		draw_line(left, right, Color("#FFF0A8"), 1.0, true)


func _draw_gene_evolution(center: Vector2) -> void:
	_draw_gene(center + Vector2(-4, 0))
	var arrow_center := center + Vector2(9, 0)
	draw_line(
		arrow_center + Vector2(-3, -5),
		arrow_center + Vector2(2, 0),
		accent,
		1.8,
		true
	)
	draw_line(
		arrow_center + Vector2(2, 0),
		arrow_center + Vector2(-3, 5),
		accent,
		1.8,
		true
	)


func _draw_evolution(center: Vector2) -> void:
	_draw_pet(center + Vector2(-3, 1))
	draw_line(
		center + Vector2(9, 8),
		center + Vector2(9, -8),
		accent,
		2.0,
		true
	)
	draw_line(
		center + Vector2(9, -8),
		center + Vector2(5, -3),
		accent,
		2.0,
		true
	)
	draw_line(
		center + Vector2(9, -8),
		center + Vector2(13, -3),
		accent,
		2.0,
		true
	)


func _draw_food(center: Vector2) -> void:
	var bowl := PackedVector2Array([
		center + Vector2(-12, 1),
		center + Vector2(12, 1),
		center + Vector2(9, 10),
		center + Vector2(-9, 10),
	])
	draw_colored_polygon(
		bowl,
		Color(
			secondary.r,
			secondary.g,
			secondary.b,
			0.82
		)
	)
	for index in range(bowl.size()):
		draw_line(
			bowl[index],
			bowl[(index + 1) % bowl.size()],
			accent,
			1.6,
			true
		)
	draw_arc(
		center + Vector2(0, 1),
		12.0,
		PI,
		TAU,
		24,
		accent,
		2.0,
		true
	)
	draw_circle(
		center + Vector2(-5, -4),
		3.2,
		accent
	)
	draw_circle(
		center + Vector2(1, -6),
		3.8,
		secondary
	)
	draw_circle(
		center + Vector2(6, -3),
		3.0,
		accent
	)


func _draw_menu_grid(center: Vector2) -> void:
	var cell_size := Vector2(8, 8)
	var offsets := [
		Vector2(-10, -10),
		Vector2(2, -10),
		Vector2(-10, 2),
		Vector2(2, 2),
	]
	for offset in offsets:
		var rect := Rect2(
			center + offset,
			cell_size
		)
		draw_style_box(
			_box(
				secondary,
				accent,
				2
			),
			rect
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


func _draw_achievement(center: Vector2) -> void:
	var ribbon := secondary
	var medal := accent
	var left := PackedVector2Array([
		center + Vector2(-8, 3),
		center + Vector2(-2, 3),
		center + Vector2(-5, 14),
	])
	var right := PackedVector2Array([
		center + Vector2(2, 3),
		center + Vector2(8, 3),
		center + Vector2(5, 14),
	])
	draw_colored_polygon(left, ribbon)
	draw_colored_polygon(right, ribbon)
	draw_circle(center + Vector2(0, -4), 10.0, medal)
	draw_arc(
		center + Vector2(0, -4),
		10.0,
		0.0,
		TAU,
		28,
		secondary,
		2.0,
		true
	)
	var star := PackedVector2Array()
	for index in range(10):
		var radius := 5.0 if index % 2 == 0 else 2.2
		var angle := -PI * 0.5 + float(index) / 10.0 * TAU
		star.append(
			center
			+ Vector2(0, -4)
			+ Vector2(cos(angle), sin(angle)) * radius
		)
	draw_colored_polygon(
		star,
		Color(1.0, 0.94, 0.66, 0.95)
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
