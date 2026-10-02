extends SceneTree

func _init() -> void:
	var failures := 0
	for level in range(1, 31):
		var session := BreakoutSession.new()
		session.start(level)
		var elapsed := 0.0
		var frames := 0
		while session.status != "won" and frames < 24000:
			if session.status == "lost":
				break
			if session.status == "ready":
				session.launch()
			var offset := sin(elapsed * 0.7 + level) * session.paddle_width() * 0.25
			session.set_paddle(session.ball.x + offset)
			session.tick(1.0 / 30.0)
			elapsed += 1.0 / 30.0
			frames += 1
		print("map=", level, " status=", session.status, " seconds=", int(elapsed), " remaining=", session.remaining())
		if session.status != "won":
			failures += 1
	print("PLAYTHROUGH failures=", failures)
	quit(1 if failures else 0)
