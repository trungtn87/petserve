class_name ArcadeGameIcon
extends Control


var _kind: StringName = &"game"
var _accent: Color = Color.WHITE
var _muted: Color = Color(0.72, 0.68, 0.82)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)


func configure(
	kind: StringName,
	accent: Color,
	muted: Color
) -> void:
	_kind = kind
	_accent = accent
	_muted = muted
	queue_redraw()


func _draw() -> void:
	match _kind:
		&"caro":
			_draw_grid_icon(true)
		&"obstacle":
			_draw_obstacle()
		&"2048":
			_draw_2048()
		&"breakout":
			_draw_breakout()
		&"jigsaw":
			_draw_jigsaw()
		&"sudoku":
			_draw_grid_icon(false)
		&"tetris":
			_draw_tetris()
		&"tank":
			_draw_tank()
		&"crystal":
			_draw_crystal()
		_:
			draw_circle(_p(0.5, 0.5), _u(0.22), _accent, false, _u(0.07), true)


func _draw_grid_icon(with_marks: bool) -> void:
	var left := _p(0.18, 0.18)
	var right := _p(0.82, 0.82)
	draw_rect(
		Rect2(left, right - left),
		_accent,
		false,
		_u(0.055),
		true
	)
	for ratio in [0.39, 0.61]:
		draw_line(
			_p(ratio, 0.18),
			_p(ratio, 0.82),
			_muted,
			_u(0.045),
			true
		)
		draw_line(
			_p(0.18, ratio),
			_p(0.82, ratio),
			_muted,
			_u(0.045),
			true
		)

	if not with_marks:
		return

	draw_circle(
		_p(0.285, 0.285),
		_u(0.055),
		_accent,
		false,
		_u(0.045),
		true
	)
	draw_line(
		_p(0.52, 0.48),
		_p(0.69, 0.65),
		_accent,
		_u(0.05),
		true
	)
	draw_line(
		_p(0.69, 0.48),
		_p(0.52, 0.65),
		_accent,
		_u(0.05),
		true
	)


func _draw_obstacle() -> void:
	draw_circle(
		_p(0.50, 0.25),
		_u(0.105),
		_accent,
		true
	)
	draw_line(
		_p(0.47, 0.13),
		_p(0.55, 0.08),
		_muted,
		_u(0.045),
		true
	)
	var basket := PackedVector2Array([
		_p(0.24, 0.56),
		_p(0.76, 0.56),
		_p(0.68, 0.82),
		_p(0.32, 0.82),
		_p(0.24, 0.56),
	])
	draw_polyline(
		basket,
		_accent,
		_u(0.06),
		true
	)
	draw_line(
		_p(0.35, 0.66),
		_p(0.65, 0.66),
		_muted,
		_u(0.04),
		true
	)


func _draw_2048() -> void:
	var tile_size := Vector2(
		size.x * 0.23,
		size.y * 0.23
	)
	for center in [
		_p(0.34, 0.34),
		_p(0.66, 0.34),
		_p(0.34, 0.66),
		_p(0.66, 0.66),
	]:
		draw_rect(
			Rect2(
				center - tile_size * 0.5,
				tile_size
			),
			_accent,
			false,
			_u(0.05),
			true
		)
	draw_circle(
		_p(0.66, 0.66),
		_u(0.055),
		_muted,
		true
	)


func _draw_breakout() -> void:
	for row in range(2):
		for col in range(3):
			var pos := _p(
				0.20 + float(col) * 0.22,
				0.18 + float(row) * 0.17
			)
			draw_rect(
				Rect2(
					pos,
					Vector2(
						size.x * 0.17,
						size.y * 0.10
					)
				),
				_accent if (row + col) % 2 == 0 else _muted,
				true
			)
	draw_circle(
		_p(0.55, 0.58),
		_u(0.055),
		_accent,
		true
	)
	draw_line(
		_p(0.31, 0.80),
		_p(0.69, 0.80),
		_accent,
		_u(0.09),
		true
	)


func _draw_jigsaw() -> void:
	var cell := Vector2(
		size.x * 0.23,
		size.y * 0.23
	)
	for center in [
		_p(0.38, 0.38),
		_p(0.62, 0.38),
		_p(0.38, 0.62),
		_p(0.62, 0.62),
	]:
		draw_rect(
			Rect2(center - cell * 0.5, cell),
			_accent,
			false,
			_u(0.05),
			true
		)
	draw_circle(
		_p(0.50, 0.38),
		_u(0.055),
		Color(
			_accent.r,
			_accent.g,
			_accent.b,
			0.30
		),
		true
	)
	draw_circle(
		_p(0.62, 0.50),
		_u(0.055),
		_muted,
		false,
		_u(0.035),
		true
	)


func _draw_tetris() -> void:
	var block := Vector2(
		size.x * 0.18,
		size.y * 0.18
	)
	for cell in [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(1, 2),
	]:
		var pos := _p(0.30, 0.22) + Vector2(
			cell.x * block.x,
			cell.y * block.y
		)
		draw_rect(
			Rect2(pos, block * 0.90),
			_accent if int(cell.y) % 2 == 0 else _muted,
			true
		)


func _draw_tank() -> void:
	draw_line(
		_p(0.28, 0.77),
		_p(0.72, 0.77),
		_muted,
		_u(0.10),
		true
	)
	draw_rect(
		Rect2(
			_p(0.27, 0.53),
			Vector2(
				size.x * 0.46,
				size.y * 0.19
			)
		),
		_accent,
		false,
		_u(0.055),
		true
	)
	draw_circle(
		_p(0.49, 0.49),
		_u(0.105),
		_accent,
		false,
		_u(0.055),
		true
	)
	draw_line(
		_p(0.56, 0.45),
		_p(0.79, 0.34),
		_accent,
		_u(0.055),
		true
	)


func _draw_crystal() -> void:
	var gem := PackedVector2Array([
		_p(0.50, 0.12),
		_p(0.73, 0.34),
		_p(0.63, 0.73),
		_p(0.50, 0.88),
		_p(0.37, 0.73),
		_p(0.27, 0.34),
		_p(0.50, 0.12),
	])
	draw_polyline(
		gem,
		_accent,
		_u(0.06),
		true
	)
	draw_line(
		_p(0.27, 0.34),
		_p(0.73, 0.34),
		_muted,
		_u(0.04),
		true
	)
	draw_line(
		_p(0.50, 0.12),
		_p(0.50, 0.88),
		_muted,
		_u(0.04),
		true
	)


func _p(
	x: float,
	y: float
) -> Vector2:
	return Vector2(
		size.x * x,
		size.y * y
	)


func _u(ratio: float) -> float:
	return maxf(
		1.0,
		minf(
			size.x,
			size.y
		) * ratio
	)
