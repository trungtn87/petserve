extends Node
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _ready() -> void:
	call_deferred("run")
func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return predicate.call()
func run() -> void:
	var game := TicTacToeGame.new()
	check(game.board().size() == 225, "15x15")
	check(not game.play(-1,1) and not game.play(225,1) and not game.play(0,2), "bounds and turn")
	for indices in [[0,1,2,3,4],[0,15,30,45,60],[0,16,32,48,64],[14,28,42,56,70]]:
		game.reset()
		for i in 5:
			check(game.play(indices[i],1),"legal black")
			if i < 4:
				check(game.result() == &"playing", "four not winning")
				check(game.play(210+i,2),"legal white")
		check(game.result() == &"player" and game.winning_cells.size() == 5,"direction win")
		check(not game.play(100,2), "no moves after victory")
	game.reset()
	for index in [13,14,15,16,17]:
		game.play(index,1)
		game.play(150+game.moves,2)
	check(game.result() == &"playing", "no wrap between rows")
	game.reset()
	for i in 4:
		game.play(i,1)
		game.play(150+i*2,2)
	game.play(100,1)
	check(game.pet_move() == 4,"AI blocks five")
	game.reset()
	for i in 4:
		game.play(100+i*2,1)
		game.play(i,2)
	game.play(150,1)
	check(game.pet_move() == 4 and game.result() == &"pet", "AI takes victory")
	game.reset()
	game._board[0] = 1
	game._board[1] = 1
	game._board[2] = 1
	game._board[4] = 1
	game._board[5] = 1
	game.moves = 5
	check(game.play(3,1) and game.winning_cells.size() == 6, "overline wins freestyle")
	game.reset()
	var black: Array[int] = []
	var white: Array[int] = []
	for y in 15:
		for x in 15:
			if (x+2*y) % 4 < 2:
				black.append(y*15+x)
			else:
				white.append(y*15+x)
	for i in 225:
		var list := black if game.turn == 1 else white
		check(game.play(list.pop_back(),game.turn), "draw legal move")
	check(game.result() == &"draw", "full board draw")
	var host := LocalConnectionService.new()
	var guest := LocalConnectionService.new()
	add_child(host)
	add_child(guest)
	host.host_wifi()
	guest.join_wifi("127.0.0.1")
	check(await wait_for(func():return host.connected() and guest.connected()), "real wifi connected")
	var a := CaroActivityUI.new()
	var b := CaroActivityUI.new()
	a.connection = host
	b.connection = guest
	add_child(a)
	add_child(b)
	a.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	a.size = Vector2(280,450)
	b.size = Vector2(280,450)
	a.open_activity()
	b.open_activity()
	await get_tree().process_frame
	await get_tree().process_frame
	check(a._place.get_global_rect().end.y <= a.get_global_rect().end.y + 1, "phone controls fit")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(135,135)
	a._board._gui_input(touch)
	check(a._board.selected == 112 and a._game.moves == 0, "touch selects without placing")
	a._toggle_zoom()
	check(a._board.custom_minimum_size.x == 450, "zoom board")
	a._toggle_zoom()
	var rewards := [0]
	a.reward_requested.connect(func(_id: String): rewards[0] += 1)
	b.reward_requested.connect(func(_id: String): rewards[0] += 1)
	a._change_mode(2)
	b._change_mode(2)
	check(await wait_for(func():return a._remote_ready), "guest ready")
	a._start_new_round()
	check(await wait_for(func():return b._network_active), "start reaches guest")
	check(a._round_id == b._round_id, "same round")
	check(not b._can_place(), "guest cannot move first")
	for i in 5:
		a._select_cell(i)
		a._place_selected()
		check(await wait_for(func():return b._game.moves == a._game.moves), "host move replay")
		if i < 4:
			b._select_cell(210+i)
			b._place_selected()
			check(await wait_for(func():return a._game.moves == i*2+2 and b._game.moves == a._game.moves), "guest host authority")
	check(a._finished and b._finished and a._game.board() == b._game.board(), "synchronized victory")
	check(rewards[0] == 2, "both multiplayer players may claim daily rewards")
	b._start_new_round()
	check(await wait_for(func():return a._remote_ready), "rematch ready")
	a._start_new_round()
	check(await wait_for(func():return b._game.moves == 0), "rematch resets")
	var before := a._game.moves
	guest.send_message("gomoku-v1", {"type":"move", "id":"old", "seq":0,"index":5})
	await get_tree().create_timer(0.05).timeout
	check(a._game.moves == before,"stale round ignored")
	b.close_activity()
	check(await wait_for(func():return not a._network_active), "leave stops match")
	check(host.connected() and guest.connected(), "leaving preserves shared connection")
	b.open_activity()
	check(await wait_for(func():return a._remote_ready),"return ready")
	a._start_new_round()
	check(await wait_for(func():return b._network_active),"restart after leaving")
	guest.disconnect_session()
	check(await wait_for(func():return not a._network_active),"disconnect stops match")
	a._change_mode(1)
	check(a._can_place(), "shared device black")
	a._select_cell(0)
	a._place_selected()
	check(a._game.turn == 2 and a._can_place(),"shared device white")
	a._select_cell(15)
	a._place_selected()
	check(a._game.turn == 1,"shared device alternating")
	a._change_mode(0)
	a._select_cell(112)
	a._place_selected()
	a.close_activity()
	await get_tree().create_timer(0.4).timeout
	check(a._game.moves == 1,"close cancels AI timer")
	host.disconnect_session()
	print("GOMOKU: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
