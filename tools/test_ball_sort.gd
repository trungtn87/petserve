extends SceneTree


func _init() -> void:
	var levels := [1, 10, 30, 61, 140]

	for level in levels:
		var game := BallSortGame.new()
		game.start_level(level)
		_check(not game.is_solved(), "Màn %d không được bắt đầu ở trạng thái đã giải." % level)
		_check(game.tubes().size() == int(game.config().get("tube_count", 0)), "Sai số ống ở màn %d." % level)
		var solution := game.debug_generated_solution()
		_check(not solution.is_empty(), "Màn %d phải có lời giải sinh sẵn." % level)
		_check(game.solution_steps() == solution.size(), "Sai số bước lời giải ở màn %d." % level)
		_check(game.move_limit() > solution.size(), "Giới hạn bước phải lớn hơn lời giải bảo đảm ở màn %d." % level)
		var previous_remaining := game.moves_remaining()

		for move in solution:
			var source := int(move.get("from", -1))
			var destination := int(move.get("to", -1))
			_check(game.can_move(source, destination), "Lời giải có bước kéo-thả không hợp lệ ở màn %d." % level)
			var move_result := game.move_ball(source, destination)
			_check(bool(move_result.get("moved", false)), "Không kéo-thả được tinh thể lời giải ở màn %d." % level)
			_check(game.moves_remaining() == previous_remaining - 1, "Nước đi hợp lệ phải trừ đúng 1 bước ở màn %d." % level)
			previous_remaining = game.moves_remaining()

		_check(game.is_solved(), "Lời giải sinh ra không giải được màn %d." % level)
		_check(game.result() == BallSortGame.RESULT_WON, "Giải đúng phải thắng ở màn %d." % level)

	var early := BallSortGame.config_for_level(1)
	var mid := BallSortGame.config_for_level(31)
	var late := BallSortGame.config_for_level(61)
	var endless := BallSortGame.config_for_level(140)
	_check(int(early.get("color_count", 0)) == 3, "Màn đầu phải có 3 màu.")
	_check(int(mid.get("color_count", 0)) == 6, "Màn 31 phải có 6 màu.")
	_check(int(late.get("empty_tubes", 0)) == 1, "Từ màn 61 phải giảm còn 1 ống trống.")
	_check(int(endless.get("color_count", 0)) >= 8, "Màn cao phải tăng số màu.")
	_check(String(BallSortGame.config_for_level(30).get("rank", "")) == "EXPERT", "Mỗi 30 màn phải có Expert.")
	_check(String(BallSortGame.config_for_level(20).get("rank", "")) == "HARD", "Mỗi 10 màn phải có Hard.")

	var invalid_game := BallSortGame.new()
	invalid_game.start_level(1)
	var remaining_before_invalid := invalid_game.moves_remaining()
	var invalid_result := invalid_game.move_ball(0, 0)
	_check(not bool(invalid_result.get("moved", false)), "Nước đi không hợp lệ không được di chuyển tinh thể.")
	_check(invalid_game.moves_remaining() == remaining_before_invalid, "Nước đi không hợp lệ không được trừ bước.")

	var undo_game := BallSortGame.new()
	undo_game.start_level(1)
	var undo_solution := undo_game.debug_generated_solution()
	var first_undo_move: Dictionary = undo_solution[0]
	var remaining_before_move := undo_game.moves_remaining()
	undo_game.move_ball(int(first_undo_move.from), int(first_undo_move.to))
	_check(undo_game.moves_remaining() == remaining_before_move - 1, "Nước đi trước hoàn tác phải trừ 1 bước.")
	undo_game.undo()
	_check(undo_game.moves_remaining() == remaining_before_move, "Hoàn tác phải trả lại bước vừa đi.")

	var loss_game := BallSortGame.new()
	loss_game.start_level(1)
	var loss_solution := loss_game.debug_generated_solution()
	_check(loss_solution.size() > 1, "Màn test thua cần lời giải dài hơn 1 bước.")
	loss_game._move_limit = 1
	var first_loss_move: Dictionary = loss_solution[0]
	var loss_result := loss_game.move_ball(int(first_loss_move.from), int(first_loss_move.to))
	_check(bool(loss_result.get("failed", false)), "Hết bước khi chưa giải xong phải trả trạng thái thất bại.")
	_check(loss_game.result() == BallSortGame.RESULT_LOST, "Hết bước phải chuyển game sang RESULT_LOST.")
	_check(loss_game.moves_remaining() == 0, "Thất bại phải còn 0 bước.")

	var ui := BallSortActivityUI.new()
	ui.size = Vector2(360, 640)
	get_root().add_child(ui)
	ui.open_activity()
	var ui_solution := ui._game.debug_generated_solution()
	for move in ui_solution:
		ui._on_tube_drop_requested(
			int(move.get("from", -1)),
			int(move.get("to", -1))
		)
	await process_frame
	_check(ui._level == 2, "Hoàn thành phải tự chuyển sang màn tiếp theo.")
	ui.queue_free()

	print("PASS: Ball Sort drag-drop, move countdown, fail/retry, auto-next, generator and guaranteed solution")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
