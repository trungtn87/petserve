class_name LocalConnectionPanel
extends VBoxContainer

var service: LocalConnectionService
var _status: Label
var _details: Label
var _name: LineEdit
var _mode: OptionButton
var _address: LineEdit
var _rooms: VBoxContainer
var _ready_button: Button
var _host_button: Button
var _join_button: Button
var _scan_button: Button
var _access_button: Button
var _settings_button: Button
var _disconnect_button: Button
var _device_refresh := 0.0

func _ready() -> void:
	if service == null:
		service = get_node("/root/LocalConnection")
	add_theme_constant_override("separation", 8)
	_status = _label("")
	_name = LineEdit.new()
	_name.placeholder_text = "Tên người chơi"
	_name.max_length = 24
	_name.text = service.local_name
	_name.custom_minimum_size.y = 44
	add_child(_name)
	_mode = OptionButton.new()
	_mode.add_item("Wi-Fi")
	_mode.add_item("Bluetooth")
	_mode.selected = 1 if service.transport == "bluetooth" else 0
	_mode.custom_minimum_size.y = 44
	_mode.item_selected.connect(_on_mode_selected)
	add_child(_mode)
	_details = _label("")
	_host_button = _button("Tạo phòng", _host)
	_scan_button = _button("Tìm phòng", _search)
	_address = LineEdit.new()
	_address.placeholder_text = "IP máy tạo phòng, ví dụ 192.168.1.12"
	_address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_address.custom_minimum_size.y = 44
	_address.text_submitted.connect(func(_text: String): _join_address())
	add_child(_address)
	_join_button = _button("Vào phòng bằng IP", _join_address)
	_access_button = _button("Cho phép Bluetooth", service.request_bluetooth_access)
	_settings_button = _button("Mở cài đặt Bluetooth / Ghép đôi", service.open_bluetooth_settings)
	_rooms = VBoxContainer.new()
	add_child(_rooms)
	_ready_button = _button("Sẵn sàng", func(): service.set_ready(not service.ready_local))
	_disconnect_button = _button("Ngắt kết nối", service.disconnect_session)
	_label("Đóng bảng này vẫn giữ kết nối. Hai máy cần cài cùng phiên bản.")
	service.status_changed.connect(_refresh)
	service.rooms_changed.connect(_show_rooms)
	_refresh()
	_show_rooms()

func _process(delta: float) -> void:
	if _mode.selected == 1 and not service.active() and is_visible_in_tree():
		_device_refresh += delta
		if _device_refresh > 2.0:
			_device_refresh = 0.0
			_show_rooms()

func _on_mode_selected(_index: int) -> void:
	_refresh()
	_show_rooms()

func _host() -> void:
	service.set_player_name(_name.text)
	if _mode.selected == 0:
		service.host_wifi()
	else:
		service.host_bluetooth()

func _search() -> void:
	if _mode.selected == 0:
		service.scan_wifi()
	else:
		_show_rooms()

func _join_address() -> void:
	service.set_player_name(_name.text)
	service.join_wifi(_address.text)

func _join_device(address: String) -> void:
	service.set_player_name(_name.text)
	service.join_bluetooth(address)

func _refresh() -> void:
	if not is_instance_valid(_status):
		return
	_status.text = service.status_text
	var wifi := _mode.selected == 0
	var busy := service.active()
	_mode.disabled = busy
	_name.editable = not busy
	_host_button.disabled = busy or (not wifi and not service.bluetooth_available())
	_scan_button.disabled = busy or (not wifi and not service.bluetooth_available())
	_scan_button.text = "Tìm phòng" if wifi else "Làm mới thiết bị đã ghép đôi"
	_address.visible = wifi and not busy
	_join_button.visible = wifi and not busy
	_access_button.visible = not wifi and not busy and service.bluetooth_available()
	_settings_button.visible = _access_button.visible
	_ready_button.visible = service.connected()
	_ready_button.text = "Bỏ sẵn sàng" if service.ready_local else "Sẵn sàng"
	_disconnect_button.visible = busy
	if service.connected():
		_details.text = "Bạn: %s\n%s: %s" % ["Sẵn sàng" if service.ready_local else "Chưa sẵn sàng", service.remote_name, "Sẵn sàng" if service.ready_remote else "Chưa sẵn sàng"]
	elif wifi:
		_details.text = "Hai máy cùng Wi-Fi hoặc điểm phát Wi-Fi.\n" + ("IP máy này: " + ", ".join(service.wifi_addresses()) if busy else "Tìm phòng hoặc nhập IP trên máy tạo phòng.")
	else:
		_details.text = "Bật Bluetooth, ghép đôi hai điện thoại trong cài đặt Android. Một máy tạo phòng, máy kia chọn tên máy đó bên dưới." if service.bluetooth_available() else "Bluetooth cần bản APK Android có plugin kết nối."
	_rooms.visible = not busy

func _show_rooms() -> void:
	for child in _rooms.get_children():
		_rooms.remove_child(child)
		child.queue_free()
	if _mode.selected == 0:
		for address in service.rooms:
			var button := Button.new()
			button.text = "%s • %s" % [service.rooms[address], address]
			button.custom_minimum_size.y = 44
			button.pressed.connect(func(): _address.text = address; _join_address())
			_rooms.add_child(button)
	else:
		for device in service.bluetooth_devices():
			if not device is Dictionary:
				continue
			var button := Button.new()
			button.text = str(device.get("name", "Điện thoại"))
			button.custom_minimum_size.y = 44
			button.pressed.connect(_join_device.bind(str(device.get("address", ""))))
			_rooms.add_child(button)

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	add_child(button)
	return button
