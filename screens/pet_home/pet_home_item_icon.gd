class_name PetHomeItemIcon
extends Control


var _item: Dictionary = {}
var _palette: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(
		56,
		56
	)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(
	item: Dictionary,
	palette: Dictionary
) -> void:
	_item = item.duplicate(true)
	_palette = palette.duplicate(true)
	queue_redraw()


func _draw() -> void:
	var side := minf(
		size.x,
		size.y
	)

	if side <= 2.0:
		return

	var center := size * 0.5
	var radius := side * 0.43
	var rarity := String(
		_item.get(
			"rarity",
			"common"
		)
	)
	var border := _rarity_color(
		rarity
	)
	var accent: Color = _palette.get(
		"accent",
		Color("#72DDF7")
	)
	var panel: Color = _palette.get(
		"panel",
		Color("#102638")
	)
	var fill := panel.lightened(
		0.09
	)
	fill.a = 0.96

	draw_circle(
		center,
		radius,
		fill
	)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		40,
		border,
		2.2,
		true
	)

	var item_type := StringName(
		_item.get(
			"item_type",
			""
		)
	)

	match item_type:
		ItemGenerator.TYPE_FOOD:
			_draw_food(
				center,
				radius,
				accent,
				border
			)
		ItemGenerator.TYPE_GROWTH:
			_draw_growth(
				center,
				radius,
				accent,
				border
			)
		ItemGenerator.TYPE_GENE:
			_draw_gene(
				center,
				radius,
				accent,
				border
			)
		ItemGenerator.TYPE_FUTURE_FRAGMENT:
			_draw_fragment(
				center,
				radius,
				accent,
				border
			)
		_:
			_draw_unknown(
				center,
				radius,
				accent,
				border
			)

	if not Array(
		_item.get(
			"defects",
			[]
		)
	).is_empty():
		_draw_crack(
			center,
			radius,
			Color(
				1.0,
				0.45,
				0.45,
				0.92
			)
		)


func _draw_food(
	center: Vector2,
	radius: float,
	accent: Color,
	border: Color
) -> void:
	var seed_value := absi(
		int(
			_item.get(
				"generated_seed",
				0
			)
		)
	)
	var variant := float(
		seed_value % 997
	) / 997.0
	var food_color := accent.lerp(
		border,
		0.35
	)
	var bowl_color := border.darkened(
		0.34
	)

	var bowl := PackedVector2Array([
		center + Vector2(-radius * 0.58, radius * 0.12),
		center + Vector2(radius * 0.58, radius * 0.12),
		center + Vector2(radius * 0.36, radius * 0.55),
		center + Vector2(-radius * 0.36, radius * 0.55),
	])
	draw_colored_polygon(
		bowl,
		bowl_color
	)
	draw_line(
		center + Vector2(-radius * 0.62, radius * 0.10),
		center + Vector2(radius * 0.62, radius * 0.10),
		border,
		2.0,
		true
	)

	for index in range(3):
		var x := (
			float(index - 1)
			* radius
			* 0.34
		)
		var y := (
			-radius * 0.12
			- radius
			* 0.08
			* sin(
				variant * TAU
				+ float(index)
			)
		)
		draw_circle(
			center + Vector2(x, y),
			radius * (
				0.15
				+ 0.015 * float(index)
			),
			food_color.lightened(
				0.05 * float(index)
			)
		)

	if Array(
		_item.get(
			"properties",
			[]
		)
	).has(
		"fresh"
	):
		draw_line(
			center + Vector2(
				radius * 0.18,
				-radius * 0.35
			),
			center + Vector2(
				radius * 0.38,
				-radius * 0.56
			),
			Color(0.56, 1.0, 0.68, 0.95),
			2.2,
			true
		)


func _draw_growth(
	center: Vector2,
	radius: float,
	accent: Color,
	border: Color
) -> void:
	var body_rect := Rect2(
		center + Vector2(
			-radius * 0.33,
			-radius * 0.34
		),
		Vector2(
			radius * 0.66,
			radius * 0.90
		)
	)
	var liquid_rect := Rect2(
		body_rect.position
		+ Vector2(
			radius * 0.07,
			radius * 0.43
		),
		Vector2(
			body_rect.size.x
			- radius * 0.14,
			body_rect.size.y
			- radius * 0.50
		)
	)

	draw_rect(
		body_rect,
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.18
		),
		true
	)
	draw_rect(
		liquid_rect,
		accent.lerp(
			border,
			0.32
		),
		true
	)
	draw_rect(
		body_rect,
		border,
		false,
		2.0
	)

	var cap_rect := Rect2(
		center + Vector2(
			-radius * 0.22,
			-radius * 0.54
		),
		Vector2(
			radius * 0.44,
			radius * 0.20
		)
	)
	draw_rect(
		cap_rect,
		border.darkened(
			0.20
		),
		true
	)

	for index in range(3):
		var bubble_radius := radius * (
			0.045
			+ 0.015 * float(index)
		)
		draw_circle(
			center + Vector2(
				(-0.13 + 0.13 * float(index))
				* radius,
				(0.17 - 0.12 * float(index))
				* radius
			),
			bubble_radius,
			Color(
				1.0,
				1.0,
				1.0,
				0.72
			)
		)


func _draw_gene(
	center: Vector2,
	radius: float,
	accent: Color,
	border: Color
) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 14

	for index in range(
		steps + 1
	):
		var t := float(index) / float(steps)
		var y := lerpf(
			-radius * 0.58,
			radius * 0.58,
			t
		)
		var wave := sin(
			t * TAU * 1.5
		) * radius * 0.23
		left.append(
			center + Vector2(
				-wave,
				y
			)
		)
		right.append(
			center + Vector2(
				wave,
				y
			)
		)

	draw_polyline(
		left,
		accent,
		2.2,
		true
	)
	draw_polyline(
		right,
		border,
		2.2,
		true
	)

	for index in range(
		0,
		steps + 1,
		3
	):
		draw_line(
			left[index],
			right[index],
			Color(
				1.0,
				1.0,
				1.0,
				0.76
			),
			1.5,
			true
		)


func _draw_fragment(
	center: Vector2,
	radius: float,
	accent: Color,
	border: Color
) -> void:
	var shard := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.64),
		center + Vector2(radius * 0.42, -radius * 0.08),
		center + Vector2(radius * 0.18, radius * 0.60),
		center + Vector2(-radius * 0.38, radius * 0.28),
		center + Vector2(-radius * 0.45, -radius * 0.14),
	])
	draw_colored_polygon(
		shard,
		accent.lerp(
			border,
			0.38
		)
	)

	var facet := PackedVector2Array([
		center + Vector2(0.0, -radius * 0.64),
		center + Vector2(radius * 0.10, radius * 0.18),
		center + Vector2(-radius * 0.38, radius * 0.28),
	])
	draw_colored_polygon(
		facet,
		Color(
			1.0,
			1.0,
			1.0,
			0.28
		)
	)

	draw_polyline(
		PackedVector2Array([
			shard[0],
			shard[1],
			shard[2],
			shard[3],
			shard[4],
			shard[0],
		]),
		border,
		2.0,
		true
	)


func _draw_unknown(
	center: Vector2,
	radius: float,
	accent: Color,
	border: Color
) -> void:
	var rect := Rect2(
		center
		- Vector2.ONE
		* radius
		* 0.42,
		Vector2.ONE
		* radius
		* 0.84
	)
	draw_rect(
		rect,
		accent.darkened(
			0.25
		),
		true
	)
	draw_rect(
		rect,
		border,
		false,
		2.0
	)


func _draw_crack(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	var points := PackedVector2Array([
		center + Vector2(
			-radius * 0.18,
			-radius * 0.42
		),
		center + Vector2(
			radius * 0.02,
			-radius * 0.15
		),
		center + Vector2(
			-radius * 0.07,
			radius * 0.04
		),
		center + Vector2(
			radius * 0.19,
			radius * 0.30
		),
	])
	draw_polyline(
		points,
		color,
		2.0,
		true
	)


func _rarity_color(
	rarity: String
) -> Color:
	match rarity:
		"uncommon":
			return Color(
				0.50,
				0.82,
				0.58
			)
		"rare":
			return Color(
				0.44,
				0.65,
				1.0
			)
		"epic":
			return Color(
				0.76,
				0.47,
				1.0
			)
		"legendary":
			return Color(
				1.0,
				0.72,
				0.28
			)
		_:
			return Color(
				0.68,
				0.68,
				0.74
			)
