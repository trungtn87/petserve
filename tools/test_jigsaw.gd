extends Node

var checks := 0
var failures := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	AtomicJson.erase(JigsawSession.SAVE_PATH)

	for level in 3:
		var session := JigsawSession.new()
		session.start("user://pet_renders/test.png", level)

		check(
			session.count() == [50, 100, 200][level],
			"exact upgraded count"
		)
		check(
			session.reward_chests() == level + 1,
			"reward scales 1 2 3 chests"
		)
		check(
			session.grid().x * session.grid().y == session.count(),
			"grid"
		)
		check(
			session.rotations.size() == session.count(),
			"rotation state for every piece"
		)

		var order := session.remaining()
		check(order.size() == session.count(), "tray contains all loose pieces")
		check(
			not session.place(-1)
			and not session.place(session.count()),
			"invalid indices"
		)

		var sample := order[0]
		var before_rotation := session.rotation_steps(sample)
		for _turn in 4:
			check(session.rotate_piece(sample), "piece rotates")
		check(
			session.rotation_steps(sample) == before_rotation,
			"four rotations return to original orientation"
		)

		var total_area := 0.0
		for index in session.count():
			var shape := session.polygon(index)
			check(
				not Geometry2D.triangulate_polygon(shape).is_empty(),
				"polygon can render"
			)
			check(
				shape.size() == session.uv(index).size(),
				"texture UV count"
			)
			for point in session.uv(index):
				check(
					point.x >= 0
					and point.x <= 1
					and point.y >= 0
					and point.y <= 1,
					"UV within image"
				)
			var area := 0.0
			for p in shape.size():
				area += (
					shape[p].cross(
						shape[(p + 1) % shape.size()]
					)
					* .5
				)
			total_area += area

		check(
			absf(total_area - session.count()) < .001,
			"tabs conserve total picture area"
		)
		check(
			session.place(order[0])
			and not session.place(order[0]),
			"single placement"
		)

		var loaded := JigsawSession.new()
		check(
			loaded.restore(
				JSON.parse_string(
					JSON.stringify(session.snapshot())
				)
			),
			"JSON resume"
		)
		check(
			loaded.remaining() == session.remaining()
			and loaded.polygon(3) == session.polygon(3)
			and loaded.rotations == session.rotations,
			"resume same tray tabs and rotations"
		)

		var corrupt := session.snapshot()
		corrupt.placed = [0, 0]
		check(
			not loaded.restore(corrupt),
			"reject duplicate progress"
		)

		for index in session.count():
			session.place(index)
		check(
			session.complete(),
			"completion requires all pieces"
		)

	var fixture := Image.create(
		160,
		220,
		false,
		Image.FORMAT_RGBA8
	)
	fixture.fill(Color.CORAL)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(
			"user://pet_renders"
		)
	)
	fixture.save_png("user://pet_renders/test.png")

	var ui := JigsawActivityUI.new()
	ui.current_image_path = "user://pet_renders/test.png"
	ui.size = Vector2(360, 640)
	add_child(ui)
	ui.open_activity()
	await get_tree().process_frame
	await get_tree().process_frame

	check(
		ui._texture != null
		and ui._session.count() == 50,
		"UI starts directly from current pet at 50 pieces"
	)
	check(
		ui._tray.get_child_count() == 50,
		"all loose pieces available in waiting tray"
	)
	check(
		ui._board.size.x > 0
		and ui._board.size.y > 0,
		"board has valid portrait size"
	)

	var initial_zoom := ui._zoom_factor
	var first_touch := InputEventScreenTouch.new()
	first_touch.index = 0
	first_touch.pressed = true
	first_touch.position = Vector2(100, 220)
	ui._input(first_touch)

	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.pressed = true
	second_touch.position = Vector2(160, 220)
	ui._input(second_touch)

	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(220, 220)
	ui._input(pinch_drag)
	check(
		ui._zoom_factor > initial_zoom,
		"two finger pinch zooms board"
	)

	first_touch.pressed = false
	ui._input(first_touch)
	second_touch.pressed = false
	ui._input(second_touch)

	var loose_index := int(ui._session.remaining()[0])
	ui._selected = loose_index
	ui._board.selected = loose_index
	ui._session.rotations[loose_index] = 0
	var wrong_position := (
		ui._board.global_position
		+ ui._board.size
		- Vector2.ONE
	)
	ui._board.try_drop(wrong_position)
	check(
		ui._session.placed.is_empty(),
		"wrong slot rejected"
	)

	var piece := ui._tray.get_child(0) as JigsawPiece
	ui._prepare_piece_press(
		piece.index,
		piece.global_position + piece.size * .5
	)
	ui._handle_piece_motion(
		ui._press_position + Vector2(20, 0)
	)
	check(
		ui._dragging and ui._ghost.visible,
		"drag begins after movement threshold"
	)
	ui._finish_drag(Vector2.ZERO)
	check(
		not ui._dragging
		and not ui._ghost.visible,
		"off-board drop returns piece to tray"
	)

	loose_index = int(ui._session.remaining()[0])
	ui._selected = loose_index
	var old_rotation := ui._session.rotation_steps(loose_index)
	ui._rotate_selected()
	check(
		ui._session.rotation_steps(loose_index)
			== posmod(old_rotation + 1, 4),
		"rotate control advances 90 degrees"
	)

	loose_index = int(ui._session.remaining()[0])
	ui._selected = loose_index
	ui._session.rotations[loose_index] = 0
	var before := ui._session.snapshot()
	AtomicJson.blocked = true
	ui._place(loose_index)
	check(
		ui._session.placed.is_empty(),
		"failed autosave rolls back placement"
	)
	ui._restart()
	check(
		ui._session.snapshot() == before,
		"failed new game retains original session"
	)
	AtomicJson.blocked = false

	for level in 3:
		ui._pending_level = level
		ui._restart()
		await get_tree().process_frame
		check(
			ui._session.count() == [50, 100, 200][level],
			"UI mode count %d" % level
		)
		check(
			ui._session.reward_chests() == level + 1,
			"UI reward tier %d" % level
		)
		check(
			ui._tray.get_child_count() == ui._session.count(),
			"waiting tray mode %d" % level
		)

	var hub := EntertainmentHubUI.new()
	hub.size = Vector2(360, 640)
	hub.pet_image_path = ui.current_image_path
	add_child(hub)
	hub.open_hub(0, 4, true)
	hub._open_jigsaw()
	await get_tree().process_frame
	check(
		hub._jigsaw_activity.visible
		and not hub._hub_screen.visible,
		"hub opens jigsaw"
	)
	hub._show_hub_screen()
	check(
		not hub._jigsaw_activity.visible
		and hub._hub_screen.visible,
		"hub returns from jigsaw"
	)
	hub.close_hub()
	check(not hub.visible, "hub closes")

	ui.close_activity()
	check(
		not ui.visible
		and not ui._ghost.visible,
		"close activity"
	)

	print(
		"JIGSAW: %d checks, %d failures"
		% [checks, failures]
	)
	get_tree().quit(0 if failures == 0 else 1)
