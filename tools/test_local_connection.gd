extends Node

var failures := 0
var checks := 0
var host: LocalConnectionService
var guest: LocalConnectionService
var received: Array = []

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _ready() -> void:
	call_deferred("run")

func wait_for(predicate: Callable, seconds: float = 3.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return bool(predicate.call())

func run() -> void:
	host = LocalConnectionService.new()
	guest = LocalConnectionService.new()
	add_child(host)
	add_child(guest)
	host.set_player_name("Máy chủ")
	guest.set_player_name("Máy khách")
	check(host.host_wifi() == OK, "host can open real ENet room")
	# Use a unicast discovery query to test the actual reply socket independent of LAN broadcast support.
	var probe := PacketPeerUDP.new()
	probe.bind(0)
	probe.set_dest_address("127.0.0.1", LocalConnectionService.DISCOVERY_PORT)
	probe.put_packet(LocalConnectionService.PROTOCOL.to_utf8_buffer())
	check(await wait_for(func(): return probe.get_available_packet_count() > 0), "discover waiting room")
	if probe.get_available_packet_count() > 0:
		var room: Variant = JSON.parse_string(probe.get_packet().get_string_from_utf8())
		check(room is Dictionary and room.get("name") == "Máy chủ", "discovery advertises correct name")
	probe.close()
	check(guest.join_wifi("not-an-ip") == ERR_INVALID_PARAMETER and not guest.active(), "invalid address does not start connection")
	check(guest.join_wifi("127.0.0.1") == OK, "guest starts real client")
	check(await wait_for(func(): return host.connected() and guest.connected()), "both ends complete protocol handshake")
	check(host.remote_name == "Máy khách" and guest.remote_name == "Máy chủ", "exchange Vietnamese names")
	if not host.connected() or not guest.connected():
		finish()
		return
	guest.set_ready(true)
	check(await wait_for(func(): return host.ready_remote), "ready signal reaches host")
	host.set_ready(true)
	check(await wait_for(func(): return guest.ready_remote), "ready signal reaches guest")
	guest.message_received.connect(func(channel: String, payload: Dictionary): received.append([channel, payload]))
	check(host.send_message("test", {"move": "left", "tick": 12}), "send game packet")
	check(await wait_for(func(): return received.size() == 1), "game packet reaches guest")
	check(received[0][0] == "test" and received[0][1].get("move") == "left", "game packet remains intact")
	check(not host.send_message("test", {"big": "x".repeat(20000)}), "oversized outgoing packet rejected")
	var third := LocalConnectionService.new()
	add_child(third)
	third.join_wifi("127.0.0.1")
	await get_tree().create_timer(0.3).timeout
	check(not third.connected() and host.remote_name == "Máy khách", "third device cannot replace second player")
	third.disconnect_session()
	third.queue_free()
	var panel := LocalConnectionPanel.new()
	panel.service = host
	add_child(panel)
	await get_tree().process_frame
	check(panel._ready_button.visible and panel._mode.disabled, "connected UI exposes ready and locks transport")
	panel.queue_free()
	await get_tree().process_frame
	check(host.connected() and guest.connected(), "closing UI preserves session")
	await get_tree().create_timer(1.2).timeout
	check(host.connected() and guest.connected(), "heartbeat preserves session")
	guest.disconnect_session()
	check(await wait_for(func(): return not host.connected()), "disconnect propagates to other endpoint")
	check(not host.ready_local and not host.ready_remote and host.remote_name.is_empty(), "disconnect clears readiness and peer identity")
	check(host.host_wifi() == OK, "host can reopen room without stale sockets")
	guest.join_wifi("127.0.0.1")
	check(await wait_for(func(): return host.connected() and guest.connected()), "reconnect succeeds")
	guest.set_process(false)
	host._elapsed = LocalConnectionService.TIMEOUT + 0.1
	await get_tree().process_frame
	check(not host.connected(), "silent peer triggers timeout")
	guest.set_process(true)
	guest.disconnect_session()
	host.disconnect_session()
	check(host.host_wifi() == OK, "room reopens after timeout")
	guest.join_wifi("127.0.0.1")
	check(await wait_for(func(): return host.connected() and guest.connected()), "third connection succeeds")
	host.disconnect_session()
	guest.disconnect_session()
	# Incompatible protocol must never become a playable session.
	host.state = "waiting"
	host.is_host = true
	host._receive(JSON.stringify({"type": "hello", "protocol": "wrong-version", "name": "X"}))
	check(not host.connected() and host.status_text.contains("phiên bản"), "incompatible protocol rejected")
	check(not host.bluetooth_available(), "desktop cleanly reports absent Android transport")
	host.host_bluetooth()
	check(not host.active() and host.status_text.contains("Android"), "missing Bluetooth plugin fails visibly")
	finish()

func finish() -> void:
	host.disconnect_session()
	guest.disconnect_session()
	print("LOCAL CONNECTION checks=", checks, " failures=", failures)
	get_tree().quit(1 if failures else 0)
