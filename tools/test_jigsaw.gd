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
		check(session.count() == [20, 50, 100][level], "exact count")
		check(session.grid().x * session.grid().y == session.count(), "grid")
		var order := session.remaining()
		check(order.size() == session.count(), "tray count")
		check(not session.place(-1) and not session.place(session.count()), "invalid indices")
		var total_area := 0.0
		for index in session.count():
			var shape := session.polygon(index)
			check(not Geometry2D.triangulate_polygon(shape).is_empty(), "polygon can render")
			check(shape.size() == session.uv(index).size(), "texture UV count")
			for point in session.uv(index):
				check(point.x >= 0 and point.x <= 1 and point.y >= 0 and point.y <= 1, "UV within image")
			var area := 0.0
			for p in shape.size():
				area += shape[p].cross(shape[(p + 1) % shape.size()]) * .5
			total_area += area
		check(absf(total_area - session.count()) < .001, "tabs conserve total picture area")
		check(session.place(order[0]) and not session.place(order[0]), "single placement")
		var loaded := JigsawSession.new()
		check(loaded.restore(JSON.parse_string(JSON.stringify(session.snapshot()))), "JSON resume")
		check(loaded.remaining() == session.remaining() and loaded.polygon(3) == session.polygon(3), "resume same tray and tabs")
		var corrupt := session.snapshot()
		corrupt.placed = [0, 0]
		check(not loaded.restore(corrupt), "reject duplicate progress")
		for index in session.count():
			session.place(index)
		check(session.complete(), "completion requires all pieces")
	var fixture := Image.create(160, 100, false, Image.FORMAT_RGBA8)
	fixture.fill(Color.CORAL)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://pet_renders"))
	fixture.save_png("user://pet_renders/test.png")
	var ui := JigsawActivityUI.new()
	ui.current_image_path = "user://pet_renders/test.png"
	ui.size = Vector2(300, 470)
	add_child(ui)
	ui.open_activity()
	await get_tree().process_frame
	await get_tree().process_frame
	check(ui._texture != null and ui._session.count() == 20, "UI starts from cached pet")
	check(ui._board.size.x <= ui._scroll.size.x and ui._board.size.y <= ui._scroll.size.y, "fit board in portrait")
	ui._select(0)
	ui._board.try_drop(ui._board.global_position + ui._board.size - Vector2.ONE)
	check(ui._session.placed.is_empty(), "wrong slot rejected")
	var tab := ui._tray.get_child(0) as JigsawPiece
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = tab.size * .5
	ui._piece_input(press, tab.index, tab)
	check(ui._dragging and ui._ghost.visible, "touch drag begins")
	var release := InputEventScreenTouch.new()
	release.position = Vector2.ZERO
	ui._input(release)
	check(not ui._dragging and not ui._ghost.visible, "offboard release resets ghost")
	var before := ui._session.snapshot()
	AtomicJson.blocked = true
	ui._place(0)
	check(ui._session.placed.is_empty(), "failed autosave rolls back placement")
	ui._restart()
	check(ui._session.snapshot() == before, "failed new game retains original session")
	AtomicJson.blocked = false
	for level in 3:
		ui._level.select(level)
		ui._restart()
		await get_tree().process_frame
		for zoom in 3:
			ui._zoom.select(zoom)
			ui._resize_board()
			check(ui._board.size.x > 0 and ui._board.size.y > 0, "zoom has valid board")
		for index in ui._session.count():
			ui._select(index)
			var center := (Vector2(index % ui._session.grid().x, index / ui._session.grid().x) + Vector2.ONE * .5) * ui._board.cell_size()
			ui._board.try_drop(ui._board.get_global_transform() * center)
		check(ui._session.complete(), "UI solve mode %d" % level)
		var resumed := JigsawSession.new()
		check(resumed.restore(AtomicJson.read(JigsawSession.SAVE_PATH)) and resumed.complete(), "completed autosave")
	var hub := EntertainmentHubUI.new()
	hub.size = Vector2(360, 640)
	hub.pet_image_path = ui.current_image_path
	add_child(hub)
	hub.open_hub(0, 4, true)
	hub._open_jigsaw()
	await get_tree().process_frame
	check(hub._jigsaw_activity.visible and not hub._hub_screen.visible, "hub opens jigsaw")
	hub._show_hub_screen()
	check(not hub._jigsaw_activity.visible and hub._hub_screen.visible, "hub returns from jigsaw")
	hub.close_hub()
	check(not hub.visible, "hub closes")
	ui.close_activity()
	check(not ui.visible and not ui._ghost.visible, "close activity")
	print("JIGSAW: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
