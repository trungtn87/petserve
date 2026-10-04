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

		for move in solution:
			var source := int(move.get("from", -1))
			var destination := int(move.get("to", -1))
			var select_result := game.tap_tube(source)
			_check(bool(select_result.get("ok", false)), "Không chọn được ống lời giải ở màn %d." % level)
			var move_result := game.tap_tube(destination)
			_check(bool(move_result.get("moved", false)), "Lời giải sinh ra có bước không hợp lệ ở màn %d." % level)

		_check(game.is_solved(), "Lời giải sinh ra không giải được màn %d." % level)

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

	print("PASS: Ball Sort generator, scaling and guaranteed solution")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
