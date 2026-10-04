class_name ObstacleRunBoard
extends Control


signal move_requested(world_x: float)


var palette: Dictionary = {}
var game: ObstacleRunGame


func _ready() -> void:
	custom_minimum_size = Vector2(
		0,
		300
	)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	gui_input.connect(
		_on_gui_input
	)


func set_game(
	value: ObstacleRunGame
) -> void:
	game = value
	queue_redraw()


func _draw() -> void:
	if game == null:
		return

	var accent: Color = palette.get(
		"accent",
		Color("7cdae9")
	)
	var panel: Color = palette.get(
		"panel",
		Color("102534")
	)
	var ink: Color = palette.get(
		"text",
		Color.WHITE
	)

	draw_style_box(
		PetHomeTheme.panel_style(
			panel,
			Color(
				accent,
				0.35
			)
		),
		Rect2(
			Vector2.ZERO,
			size
		)
	)

	var scale_factor := minf(
		size.x
		/ ObstacleRunGame.WORLD_SIZE.x,
		size.y
		/ ObstacleRunGame.WORLD_SIZE.y
	)
	var origin := (
		size
		- ObstacleRunGame.WORLD_SIZE
		* scale_factor
	) * 0.5

	draw_set_transform(
		origin,
		0.0,
		Vector2.ONE
		* scale_factor
	)

	for lane_x in ObstacleRunGame.LANE_CENTERS:
		draw_line(
			Vector2(
				float(
					lane_x
				),
				0
			),
			Vector2(
				float(
					lane_x
				),
				ObstacleRunGame.WORLD_SIZE.y
			),
			Color(
				accent,
				0.045
			),
			1.0
		)

	for index in range(
		8
	):
		var y := fposmod(
			float(
				index
			) * 67.0
			+ game.elapsed()
			* 78.0,
			500.0
		) - 50.0
		var x := (
			22.0
			+ float(
				(index * 47)
				% 276
			)
		)
		draw_line(
			Vector2(
				x,
				y
			),
			Vector2(
				x,
				y + 18.0
			),
			Color(
				accent,
				0.12
			),
			2.0,
			true
		)

	draw_rect(
		Rect2(
			0,
			ObstacleRunGame.PLAYER_Y
			+ 40.0,
			320,
			18
		),
		Color(
			accent,
			0.06
		)
	)

	for item in game.obstacles():
		if bool(
			item.get(
				"resolved",
				false
			)
		):
			continue
		_draw_falling_item(
			item,
			accent,
			panel,
			ink
		)

	var pet := game.player_rect()
	var center := pet.get_center()
	var body_color := accent

	if (
		game.is_invulnerable()
		and int(
			game.elapsed()
			* 12.0
		) % 2 == 0
	):
		body_color.a = 0.35

	_draw_ellipse_shadow(
		Vector2(
			center.x,
			pet.end.y + 4.0
		),
		Vector2(
			19.0,
			5.0
		),
		Color(
			0,
			0,
			0,
			0.22
		)
	)

	var body := StyleBoxFlat.new()
	body.bg_color = body_color
	body.set_corner_radius_all(
		11
	)
	draw_style_box(
		body,
		pet
	)

	# Tai
	draw_colored_polygon(
		PackedVector2Array([
			pet.position
			+ Vector2(
				2,
				7
			),
			pet.position
			+ Vector2(
				4,
				-8
			),
			pet.position
			+ Vector2(
				13,
				3
			),
		]),
		body_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			pet.position
			+ Vector2(
				20,
				3
			),
			pet.position
			+ Vector2(
				30,
				-8
			),
			pet.position
			+ Vector2(
				32,
				7
			),
		]),
		body_color
	)

	# Mắt + miệng mở để thể hiện đang ăn.
	draw_circle(
		center
		+ Vector2(
			-5,
			-4
		),
		2.5,
		panel
	)
	draw_circle(
		center
		+ Vector2(
			5,
			-4
		),
		2.5,
		panel
	)
	draw_arc(
		center
		+ Vector2(
			0,
			5
		),
		5.0,
		0.15,
		PI - 0.15,
		16,
		ink,
		1.8,
		true
	)

	var sway := sin(
		game.elapsed()
		* 18.0
	) * 2.2
	draw_line(
		pet.position
		+ Vector2(
			8,
			30
		),
		pet.position
		+ Vector2(
			7 + sway,
			37
		),
		body_color,
		5.0,
		true
	)
	draw_line(
		pet.position
		+ Vector2(
			26,
			30
		),
		pet.position
		+ Vector2(
			27 - sway,
			37
		),
		body_color,
		5.0,
		true
	)

	draw_set_transform(
		Vector2.ZERO
	)


func _draw_falling_item(
	item: Dictionary,
	accent: Color,
	panel: Color,
	ink: Color
) -> void:
	var rect := game.obstacle_rect(
		item
	)
	var kind := StringName(
		item.get(
			"kind",
			&"berry"
		)
	)
	var center := rect.get_center()
	var edible := bool(
		item.get(
			"edible",
			false
		)
	)

	if edible:
		_draw_edible(
			kind,
			rect,
			center,
			accent,
			panel,
			ink
		)
	else:
		_draw_bad_item(
			kind,
			rect,
			center,
			accent,
			panel
		)


func _draw_edible(
	kind: StringName,
	rect: Rect2,
	center: Vector2,
	accent: Color,
	panel: Color,
	ink: Color
) -> void:
	match kind:
		ObstacleRunGame.KIND_FISH:
			var fish_color := Color(
				"77c9f4"
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(
						rect.position.x,
						center.y
					),
					Vector2(
						rect.position.x
						+ 9,
						rect.position.y
					),
					Vector2(
						rect.end.x
						- 8,
						center.y
					),
					Vector2(
						rect.position.x
						+ 9,
						rect.end.y
					),
				]),
				fish_color
			)
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(
						rect.end.x
						- 8,
						center.y
					),
					Vector2(
						rect.end.x,
						rect.position.y
						+ 3
					),
					Vector2(
						rect.end.x,
						rect.end.y
						- 3
					),
				]),
				fish_color.darkened(
					0.18
				)
			)
			draw_circle(
				Vector2(
					rect.position.x
					+ 8,
					center.y - 3
				),
				1.6,
				panel
			)
		ObstacleRunGame.KIND_MEAT:
			draw_circle(
				center,
				minf(
					rect.size.x,
					rect.size.y
				) * 0.43,
				Color(
					"e98484"
				)
			)
			draw_circle(
				center
				+ Vector2(
					5,
					-3
				),
				5.0,
				Color(
					"ffd3b8"
				)
			)
			draw_line(
				center
				+ Vector2(
					-7,
					7
				),
				center
				+ Vector2(
					-12,
					12
				),
				Color(
					"f7e7c5"
				),
				4.0,
				true
			)
		ObstacleRunGame.KIND_TREAT:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(
				"f1c45a"
			)
			box.border_color = Color(
				accent,
				0.8
			)
			box.set_border_width_all(
				2
			)
			box.set_corner_radius_all(
				8
			)
			draw_style_box(
				box,
				rect
			)
			draw_circle(
				center,
				5.0,
				Color(
					"fff1a8"
				)
			)
			draw_circle(
				center,
				2.0,
				panel
			)
		_:
			# Berry / fruit
			draw_circle(
				center,
				minf(
					rect.size.x,
					rect.size.y
				) * 0.43,
				Color(
					"ef6f9b"
				)
			)
			draw_circle(
				center
				+ Vector2(
					-4,
					-5
				),
				3.0,
				Color(
					"ffd1df"
				)
			)
			draw_line(
				center
				+ Vector2(
					1,
					-11
				),
				center
				+ Vector2(
					5,
					-16
				),
				Color(
					"79cf83"
				),
				3.0,
				true
			)

	# Viền xanh nhẹ = có thể ăn.
	draw_arc(
		center,
		minf(
			rect.size.x,
			rect.size.y
		) * 0.49,
		0.0,
		TAU,
		24,
		Color(
			"6ee7a2"
		),
		1.6,
		true
	)


func _draw_bad_item(
	kind: StringName,
	rect: Rect2,
	center: Vector2,
	accent: Color,
	panel: Color
) -> void:
	match kind:
		ObstacleRunGame.KIND_CAN:
			var can := StyleBoxFlat.new()
			can.bg_color = Color(
				"9ba5ad"
			)
			can.border_color = Color(
				"dce4e8"
			)
			can.set_border_width_all(
				2
			)
			can.set_corner_radius_all(
				5
			)
			draw_style_box(
				can,
				rect
			)
			draw_line(
				Vector2(
					rect.position.x + 4,
					center.y
				),
				Vector2(
					rect.end.x - 4,
					center.y
				),
				Color(
					panel,
					0.5
				),
				2.0,
				true
			)
		ObstacleRunGame.KIND_POISON:
			draw_circle(
				center,
				minf(
					rect.size.x,
					rect.size.y
				) * 0.46,
				Color(
					"9d5bd2"
				)
			)
			draw_line(
				center
				+ Vector2(
					-7,
					-7
				),
				center
				+ Vector2(
					7,
					7
				),
				Color.WHITE,
				2.5,
				true
			)
			draw_line(
				center
				+ Vector2(
					7,
					-7
				),
				center
				+ Vector2(
					-7,
					7
				),
				Color.WHITE,
				2.5,
				true
			)
		_:
			draw_circle(
				center,
				minf(
					rect.size.x,
					rect.size.y
				) * 0.48,
				Color(
					"8e8580"
				)
			)
			draw_circle(
				center
				+ Vector2(
					-5,
					-4
				),
				3.3,
				Color(
					"b9afa8"
				)
			)
			draw_circle(
				center
				+ Vector2(
					6,
					5
				),
				2.7,
				Color(
					"6e6762"
				)
			)

	# Viền đỏ = không ăn được.
	draw_arc(
		center,
		minf(
			rect.size.x,
			rect.size.y
		) * 0.50,
		0.0,
		TAU,
		24,
		Color(
			"ff6b6b"
		),
		2.0,
		true
	)


func _draw_ellipse_shadow(
	center: Vector2,
	radius: Vector2,
	color: Color
) -> void:
	var points := PackedVector2Array()

	for index in range(
		20
	):
		var angle := (
			TAU
			* float(
				index
			)
			/ 20.0
		)
		points.append(
			center
			+ Vector2(
				cos(
					angle
				)
				* radius.x,
				sin(
					angle
				)
				* radius.y
			)
		)

	draw_colored_polygon(
		points,
		color
	)


func _on_gui_input(
	event: InputEvent
) -> void:
	if (
		event is InputEventScreenTouch
		and event.pressed
	):
		move_requested.emit(
			_world_x(
				event.position.x
			)
		)
		accept_event()
	elif event is InputEventScreenDrag:
		move_requested.emit(
			_world_x(
				event.position.x
			)
		)
		accept_event()
	elif (
		event is InputEventMouseButton
		and event.button_index
		== MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if (
			event.device
			!= InputEvent.DEVICE_ID_EMULATION
		):
			move_requested.emit(
				_world_x(
					event.position.x
				)
			)
			accept_event()
	elif (
		event is InputEventMouseMotion
		and (
			event.button_mask
			& MOUSE_BUTTON_MASK_LEFT
		) != 0
	):
		move_requested.emit(
			_world_x(
				event.position.x
			)
		)
		accept_event()


func _world_x(
	local_x: float
) -> float:
	var scale_factor := minf(
		size.x
		/ ObstacleRunGame.WORLD_SIZE.x,
		size.y
		/ ObstacleRunGame.WORLD_SIZE.y
	)

	if scale_factor <= 0.0:
		return (
			ObstacleRunGame.WORLD_SIZE.x
			* 0.5
		)

	var origin_x := (
		size.x
		- ObstacleRunGame.WORLD_SIZE.x
		* scale_factor
	) * 0.5

	return clampf(
		(
			local_x
			- origin_x
		)
		/ scale_factor,
		0.0,
		ObstacleRunGame.WORLD_SIZE.x
	)
