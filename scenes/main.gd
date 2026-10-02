extends Control


var _app: GameApp


func _ready() -> void:
	if not BackupService.recovery_ok:
		return
	_app = GameApp.new()

	if not _app.start(self):
		push_error(
			"Main: GameApp không khởi động được."
		)


func _process(delta: float) -> void:
	if _app != null:
		_app.tick(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _app != null:
		var egg := _app.get_egg()
		if egg != null and egg.has_active_life():
			egg.save()
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return

	if _app != null:
		_app.shutdown()

	get_tree().quit()
