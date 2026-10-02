extends Node
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	AtomicJson.write("user://settings_v1.json", {"sound": false, "future_option": 42})
	AudioService.reload_settings()
	check(AudioServer.is_bus_mute(0), "legacy master preference respected")
	check(AudioService.set_setting("music", false), "music preference saves")
	AudioService.set_setting("sound", true)
	AudioService.set_setting("effects_volume", 0.3)
	AudioService.reload_settings()
	check(not AudioServer.is_bus_mute(0), "master enabled")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "music independently disabled")
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("UI")), "effects remain enabled")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI"))), 0.3), "volume restored")
	check(AudioService.settings.get("future_option") == 42, "unrelated settings preserved")
	AtomicJson.blocked = true
	check(not AudioService.set_setting("effects", false), "write failure reported")
	check(bool(AudioService.settings.get("effects", true)), "failed write does not change active settings")
	AtomicJson.blocked = false
	AudioService.set_setting("music", true)
	check(AudioService._music.stream.loop, "gapless loop enabled")
	AudioService._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(AudioService._music.stream_paused, "background pauses music")
	AudioService._notification(NOTIFICATION_APPLICATION_RESUMED)
	check(not AudioService._music.stream_paused, "foreground resumes music")
	var button := Button.new()
	add_child(button)
	await get_tree().process_frame
	check(button.pressed.is_connected(AudioService.play.bind("click")), "dynamic buttons get audio")
	var facade := InfantGameFacade.new()
	check(facade.setup(381, 1, &"dark"), "game facade ready")
	var hub := EntertainmentHubUI.new()
	hub.energy_2048_api = facade
	add_child(hub)
	hub.open_hub(0, 1, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var games := [hub._caro_activity, hub._obstacle_activity, hub._energy_2048_activity, hub._breakout_activity, hub._jigsaw_activity, hub._sudoku_activity, hub._tetris_activity, hub._tank_activity]
	for game in games:
		check(game.theme != null, game.get_class() + " arcade theme assigned")
		check(game.palette.accent == ArcadeTheme.ACCENT, "common accessible accent")
		if "game_api" in game:
			game.game_api = facade
		hub._hide_activities()
		game.open_activity()
		await get_tree().process_frame
		await get_tree().process_frame
		check(game.is_visible_in_tree(), "game opens after theme upgrade")
		game.close_activity()
	hub.close_hub()
	hub.queue_free()
	button.queue_free()
	print("Arcade audio/theme: %d checks, %d failures" % [checks, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
