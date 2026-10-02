class_name LocalConnectionService
extends Node
## One persistent two-player session; transports carry the same JSON protocol.
signal status_changed
signal rooms_changed
signal message_received(channel: String, payload: Dictionary)

const PROTOCOL := "petverse-local-1"
const PORT := 28411
const DISCOVERY_PORT := 28412
const MAX_PACKET := 16384
const TIMEOUT := 8.0

var state := "idle"
var status_text := "Chưa kết nối"
var transport := "wifi"
var is_host := false
var local_name := "Người chơi"
var remote_name := ""
var ready_local := false
var ready_remote := false
var rooms: Dictionary = {}
var _peer: ENetMultiplayerPeer
var _peer_id := 0
var _discovery: PacketPeerUDP
var _scan: PacketPeerUDP
var _scan_time := 0.0
var _heartbeat := 0.0
var _elapsed := 0.0
var _wire_open := false
var _bluetooth: Object

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("PetVerseBluetooth"):
		_bluetooth = Engine.get_singleton("PetVerseBluetooth")

func connected() -> bool:
	return state == "connected"

func active() -> bool:
	return state in ["waiting", "connecting", "connected"]

func bluetooth_available() -> bool:
	return _bluetooth != null

func set_player_name(value: String) -> void:
	local_name = value.strip_edges().substr(0, 24)
	if local_name.is_empty():
		local_name = "Người chơi"

func host_wifi() -> Error:
	disconnect_session()
	transport = "wifi"
	is_host = true
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(PORT, 1)
	if error != OK:
		_fail("Không tạo được phòng Wi-Fi. Hãy thử lại.")
		return error
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	_discovery = PacketPeerUDP.new()
	if _discovery.bind(DISCOVERY_PORT) != OK:
		_discovery.close()
		_discovery = null # Joining by address still works.
	_set_status("waiting", "Đang chờ người thứ hai vào phòng")
	return OK

func join_wifi(address: String) -> Error:
	var clean := address.strip_edges()
	if not clean.is_valid_ip_address():
		_set_status(state, "Nhập địa chỉ IP của máy tạo phòng")
		return ERR_INVALID_PARAMETER
	disconnect_session()
	transport = "wifi"
	is_host = false
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(clean, PORT)
	if error != OK:
		_fail("Không kết nối được địa chỉ này")
		return error
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	_peer_id = 1
	_set_status("connecting", "Đang kết nối…")
	return OK

func host_bluetooth() -> void:
	_start_bluetooth(true, "")

func join_bluetooth(address: String) -> void:
	_start_bluetooth(false, address)

func _start_bluetooth(host: bool, address: String) -> void:
	disconnect_session()
	transport = "bluetooth"
	is_host = host
	if _bluetooth == null:
		_fail("Bluetooth chỉ có trên bản Android hỗ trợ kết nối")
		return
	var started: bool = _bluetooth.host_room() if host else _bluetooth.join_room(address)
	if not started:
		_set_status("idle", str(_bluetooth.last_error()))
		return
	_set_status("waiting" if host else "connecting", "Đang chờ qua Bluetooth" if host else "Đang kết nối Bluetooth…")

func bluetooth_devices() -> Array:
	if _bluetooth == null:
		return []
	var result: Variant = JSON.parse_string(_bluetooth.paired_devices())
	return result if result is Array else []

func request_bluetooth_access() -> void:
	if _bluetooth != null:
		_bluetooth.request_access()

func open_bluetooth_settings() -> void:
	if _bluetooth != null:
		_bluetooth.open_settings()

func wifi_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.is_valid_ip_address() and address != "0.0.0.0":
			result.append(address)
	return result

func scan_wifi() -> void:
	_stop_scan()
	rooms.clear()
	rooms_changed.emit()
	_scan = PacketPeerUDP.new()
	if _scan.bind(0) != OK:
		_stop_scan()
		_set_status(state, "Không tìm tự động được. Hãy nhập IP của phòng.")
		return
	_scan.set_broadcast_enabled(true)
	_scan.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_scan.put_packet(PROTOCOL.to_utf8_buffer())
	_scan_time = 3.0

func _process(delta: float) -> void:
	_poll_discovery(delta)
	if not active():
		return
	if transport == "wifi":
		_poll_wifi()
	else:
		_poll_bluetooth()
	if not active():
		return
	if state == "connecting" or _wire_open:
		_elapsed += delta
		if _elapsed > (TIMEOUT if connected() else 12.0):
			_fail("Mất kết nối" if connected() else "Không vào được phòng. Kiểm tra Wi-Fi/Bluetooth rồi thử lại.")
			return
	if connected():
		_heartbeat += delta
		if _heartbeat >= 1.0:
			_heartbeat = 0.0
			_send({"type": "ping"})

func _poll_wifi() -> void:
	if _peer == null:
		return
	_peer.poll()
	if _peer == null:
		return
	if not is_host:
		var connection_status := _peer.get_connection_status()
		if connection_status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_fail("Không kết nối được phòng hoặc chủ phòng đã thoát")
			return
		if connection_status == MultiplayerPeer.CONNECTION_CONNECTED and not _wire_open:
			_open_wire()
	for index in mini(64, _peer.get_available_packet_count()):
		var sender := _peer.get_packet_peer()
		var packet := _peer.get_packet()
		if sender == _peer_id:
			_receive(packet.get_string_from_utf8())
		if _peer == null:
			break

func _on_peer_connected(id: int) -> void:
	if is_host and _peer_id == 0:
		_peer_id = id
		_open_wire()

func _on_peer_disconnected(_id: int) -> void:
	_fail("Người chơi còn lại đã ngắt kết nối")

func _poll_bluetooth() -> void:
	var native_state: String = _bluetooth.connection_state()
	if native_state == "error":
		_fail(str(_bluetooth.last_error()))
		return
	if native_state == "connected" and not _wire_open:
		_open_wire()
	var packets: Variant = JSON.parse_string(_bluetooth.take_packets())
	if packets is Array:
		for packet in packets:
			if packet is String and active():
				_receive(packet)

func _open_wire() -> void:
	_wire_open = true
	_elapsed = 0.0
	if not is_host:
		_send({"type": "hello", "protocol": PROTOCOL, "name": local_name})

func _receive(text: String) -> void:
	if text.to_utf8_buffer().size() > MAX_PACKET:
		_fail("Dữ liệu kết nối không hợp lệ")
		return
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary:
		return
	var kind: String = str(value.get("type", ""))
	if not connected():
		if kind != ("hello" if is_host else "welcome"):
			return
		if str(value.get("protocol", "")) != PROTOCOL:
			_send({"type": "reject"})
			_fail("Hai máy dùng phiên bản kết nối khác nhau. Hãy cập nhật cùng bản.")
			return
		remote_name = str(value.get("name", "Người chơi")).strip_edges().substr(0, 24)
		if remote_name.is_empty():
			remote_name = "Người chơi"
		if is_host:
			_send({"type": "welcome", "protocol": PROTOCOL, "name": local_name})
		_elapsed = 0.0
		_set_status("connected", "Đã kết nối với " + remote_name)
		return
	_elapsed = 0.0
	match kind:
		"ping":
			_send({"type": "pong"})
		"pong":
			pass
		"ready":
			ready_remote = value.get("value", false) == true
			status_changed.emit()
		"bye":
			_fail("Người chơi còn lại đã ngắt kết nối")
		"data":
			if value.get("payload") is Dictionary:
				message_received.emit(str(value.get("channel", "")).substr(0, 48), value.payload)

func send_message(channel: String, payload: Dictionary) -> bool:
	if not connected() or channel.is_empty() or channel.length() > 48:
		return false
	return _send({"type": "data", "channel": channel, "payload": payload})

func set_ready(value: bool) -> void:
	if connected() and _send({"type": "ready", "value": value}):
		ready_local = value
		status_changed.emit()

func _send(value: Dictionary) -> bool:
	var text := JSON.stringify(value)
	var bytes := text.to_utf8_buffer()
	if bytes.size() > MAX_PACKET:
		return false
	if transport == "bluetooth":
		return _bluetooth != null and _bluetooth.send_packet(text)
	if _peer == null or _peer_id == 0:
		return false
	_peer.set_target_peer(_peer_id)
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	return _peer.put_packet(bytes) == OK

func disconnect_session(notify_peer: bool = true) -> void:
	if connected() and notify_peer:
		_send({"type": "bye"})
	if _peer != null:
		_peer.close()
		_peer = null
	if _bluetooth != null:
		_bluetooth.close_room()
	if _discovery != null:
		_discovery.close()
		_discovery = null
	_stop_scan()
	_peer_id = 0
	_wire_open = false
	_elapsed = 0.0
	_heartbeat = 0.0
	remote_name = ""
	ready_local = false
	ready_remote = false
	_set_status("idle", "Chưa kết nối")

func _fail(message: String) -> void:
	disconnect_session(false)
	_set_status("idle", message)

func _set_status(value: String, message: String) -> void:
	state = value
	status_text = message
	status_changed.emit()

func _poll_discovery(delta: float) -> void:
	if _discovery != null:
		for index in mini(16, _discovery.get_available_packet_count()):
			var query := _discovery.get_packet().get_string_from_utf8()
			var address := _discovery.get_packet_ip()
			var port := _discovery.get_packet_port()
			if query == PROTOCOL and state == "waiting" and not _wire_open:
				_discovery.set_dest_address(address, port)
				_discovery.put_packet(JSON.stringify({"protocol": PROTOCOL, "name": local_name}).to_utf8_buffer())
	if _scan == null:
		return
	for index in mini(16, _scan.get_available_packet_count()):
		var packet := _scan.get_packet()
		var address := _scan.get_packet_ip()
		if packet.size() > 512:
			continue
		var reply: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if reply is Dictionary and reply.get("protocol") == PROTOCOL:
			rooms[address] = str(reply.get("name", "Phòng chơi")).substr(0, 24)
			rooms_changed.emit()
	_scan_time -= delta
	if _scan_time <= 0:
		_stop_scan()
		rooms_changed.emit()

func _stop_scan() -> void:
	if _scan != null:
		_scan.close()
		_scan = null

func _exit_tree() -> void:
	disconnect_session()
